-- Additive migration. Apply after membership_history_and_authors.
-- Existing text-only saves keep using save_meetup_atomic and preserve place.
begin;

alter table public.meetups add column if not exists place jsonb;

create or replace function public.morak_valid_meetup_place(p_place jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if p_place is null or p_place = 'null'::jsonb then return true; end if;
  if jsonb_typeof(p_place) <> 'object' then return false; end if;
  if exists (select 1 from jsonb_object_keys(p_place) as k(key)
    where key not in ('name','address','latitude','longitude','source')) then return false; end if;
  if jsonb_typeof(p_place->'name') is distinct from 'string'
    or length(btrim(p_place->>'name')) not between 1 and 200
    or length(p_place->>'name') > 200
    or jsonb_typeof(p_place->'address') is distinct from 'string'
    or length(p_place->>'address') > 500
    or jsonb_typeof(p_place->'latitude') is distinct from 'number'
    or jsonb_typeof(p_place->'longitude') is distinct from 'number'
    or jsonb_typeof(p_place->'source') is distinct from 'string'
    or (p_place->>'source') not in ('naver_search','manual_pin') then return false; end if;
  return (p_place->>'latitude')::numeric between -90 and 90
    and (p_place->>'longitude')::numeric between -180 and 180;
end;
$$;

revoke all on function public.morak_valid_meetup_place(jsonb) from public, anon;
grant execute on function public.morak_valid_meetup_place(jsonb) to authenticated;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.meetups'::regclass
    and conname='meetups_place_valid') then
    alter table public.meetups add constraint meetups_place_valid
      check (public.morak_valid_meetup_place(place));
  end if;
end;
$$;

grant select(place), insert(place), update(place) on public.meetups to authenticated;

create or replace function public.save_meetup_with_place_atomic(
  p_meetup jsonb,
  p_member_ids jsonb,
  p_meetup_id text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_data public.meetups%rowtype;
  v_target public.meetups%rowtype;
  v_saved_id public.meetups.id%type;
  v_attendances jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_meetup is null or jsonb_typeof(p_meetup) <> 'object'
      or p_member_ids is null or jsonb_typeof(p_member_ids) <> 'array' then
    raise exception 'Invalid meetup payload' using errcode = '22023';
  end if;

  if not (p_meetup ? 'place') then
    raise exception 'Explicit place value required' using errcode = '22023';
  end if;

  -- Keep the deployed column types, existing RLS, and attendance transaction.
  select * into v_data
  from jsonb_populate_record(null::public.meetups, p_meetup);

  if p_meetup_id is null then
    insert into public.meetups (
      group_id, title, meet_date, location, menu, photos, place
    ) values (
      v_data.group_id, v_data.title, v_data.meet_date,
      v_data.location, v_data.menu, v_data.photos, v_data.place
    ) returning id into v_saved_id;
  else
    select * into v_target
    from jsonb_populate_record(
      null::public.meetups, jsonb_build_object('id', p_meetup_id)
    );

    -- Serialize edits to the same meetup before replacing its attendances.
    select m.id into v_saved_id
    from public.meetups as m
    where m.id = v_target.id
    for update;

    if not found then
      raise exception 'Meetup unavailable' using errcode = '42501';
    end if;

    update public.meetups set
      group_id = v_data.group_id,
      title = v_data.title,
      meet_date = v_data.meet_date,
      location = v_data.location,
      menu = v_data.menu,
      photos = v_data.photos,
      place = v_data.place
    where id = v_saved_id
    returning id into v_saved_id;

    -- RLS may filter an UPDATE without producing a database error.
    if not found then
      raise exception 'Meetup update denied' using errcode = '42501';
    end if;

    delete from public.attendances where meetup_id = v_saved_id;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object(
      'meetup_id', v_saved_id, 'member_id', member_id
    )), '[]'::jsonb
  ) into v_attendances
  from jsonb_array_elements(p_member_ids) as selected(member_id);

  insert into public.attendances (meetup_id, member_id)
  select a.meetup_id, a.member_id
  from jsonb_populate_recordset(
    null::public.attendances, v_attendances
  ) as a;

  -- Do not catch errors here: every DB write must roll back on failure.
end;
$$;

revoke all on function public.save_meetup_with_place_atomic(jsonb, jsonb, text)
  from public, anon;
grant execute on function public.save_meetup_with_place_atomic(jsonb, jsonb, text)
  to authenticated;

-- Private, short-lived per-user counters. Never expose them through table APIs.
create table if not exists public.morak_place_search_limits (
  user_id uuid primary key,
  minute_start timestamptz not null,
  minute_count integer not null,
  day_start date not null,
  day_count integer not null
);
create index if not exists morak_place_search_limits_day on public.morak_place_search_limits(day_start);
alter table public.morak_place_search_limits enable row level security;
revoke all on public.morak_place_search_limits from public, anon, authenticated;

create or replace function public.morak_consume_place_search()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_minute timestamptz := date_trunc('minute', now());
  v_day date := (now() at time zone 'UTC')::date;
  v_allowed boolean := false;
begin
  if v_user is null then return false; end if;
  delete from public.morak_place_search_limits where day_start < v_day - 7;
  insert into public.morak_place_search_limits as limits
    (user_id, minute_start, minute_count, day_start, day_count)
    values (v_user, v_minute, 1, v_day, 1)
  on conflict (user_id) do update set
    minute_start = v_minute,
    minute_count = case when limits.minute_start=v_minute then limits.minute_count+1 else 1 end,
    day_start = v_day,
    day_count = case when limits.day_start=v_day then limits.day_count+1 else 1 end
  where (limits.minute_start<>v_minute or limits.minute_count<30)
    and (limits.day_start<>v_day or limits.day_count<300)
  returning true into v_allowed;
  return coalesce(v_allowed, false);
end;
$$;
revoke all on function public.morak_consume_place_search() from public, anon;
grant execute on function public.morak_consume_place_search() to authenticated;

commit;
