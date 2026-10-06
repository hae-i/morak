-- === 수정한 내용: 만남 수정과 출석 교체를 하나의 트랜잭션으로 처리하여 중간 실패의 데이터 손실을 방지한다 ===
-- Apply before releasing the client that calls save_meetup_atomic.
-- Existing table grants and RLS policies remain authoritative.
create function public.save_meetup_atomic(
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

  -- Use the deployed column types, including the photos column type.
  select * into v_data
  from jsonb_populate_record(null::public.meetups, p_meetup);

  if p_meetup_id is null then
    insert into public.meetups (
      group_id, title, meet_date, location, menu, photos
    ) values (
      v_data.group_id, v_data.title, v_data.meet_date,
      v_data.location, v_data.menu, v_data.photos
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
      photos = v_data.photos
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

revoke all on function public.save_meetup_atomic(jsonb, jsonb, text)
  from public, anon;
grant execute on function public.save_meetup_atomic(jsonb, jsonb, text)
  to authenticated;
