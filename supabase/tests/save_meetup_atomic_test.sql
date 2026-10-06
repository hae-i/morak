\set ON_ERROR_STOP on
-- === 수정한 내용: 실제 DB의 출석 실패 rollback과 RLS 거부를 재현하는 회귀 테스트를 준비한다 ===
-- Run only in a disposable, empty PostgreSQL database. Never in production.
begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon;
  end if;
end;
$$;

create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema public, auth to authenticated;
grant execute on function auth.uid() to authenticated;

create table public.meetups (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null,
  title text,
  meet_date date not null,
  location text,
  menu text,
  photos text[] not null default '{}'
);
create table public.group_members (id uuid primary key);
create table public.attendances (
  meetup_id uuid not null references public.meetups(id),
  member_id uuid not null references public.group_members(id),
  primary key (meetup_id, member_id)
);

alter table public.meetups enable row level security;
alter table public.attendances enable row level security;
create policy meetup_read on public.meetups for select
  to authenticated using (true);
create policy meetup_insert on public.meetups for insert
  to authenticated with check (true);
create policy meetup_update on public.meetups for update to authenticated
  using (current_setting('rpc_test.deny_update', true) is distinct from 'true')
  with check (true);
create policy attendance_access on public.attendances for all
  to authenticated using (true) with check (true);
grant select, insert, update on public.meetups to authenticated;
grant select, insert, delete on public.attendances to authenticated;
grant select on public.group_members to authenticated;

insert into public.group_members values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002');
insert into public.meetups (id, group_id, title, meet_date, photos) values (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000020',
  'Original title', '2026-10-01', array['original.jpg']
);
insert into public.attendances values (
  '00000000-0000-0000-0000-000000000010',
  '00000000-0000-0000-0000-000000000001'
);

\ir ../migrations/20261005000000_save_meetup_atomic.sql

select set_config(
  'request.jwt.claim.sub', '00000000-0000-0000-0000-000000000030', true
);
set local role authenticated;

do $$
declare
  v_payload jsonb := '{
    "group_id":"00000000-0000-0000-0000-000000000020",
    "title":"Updated title", "meet_date":"2026-10-05T12:00:00.000",
    "location":null, "menu":"Lunch", "photos":["new.jpg"]
  }';
  v_meetup_id text := '00000000-0000-0000-0000-000000000010';
  v_bad_members jsonb := '["00000000-0000-0000-0000-000000000099"]';
  v_good_members jsonb := '["00000000-0000-0000-0000-000000000002"]';
  v_count integer;
begin
  -- A real FK failure after the DELETE must undo the meetup UPDATE and DELETE.
  begin
    perform public.save_meetup_atomic(v_payload, v_bad_members, v_meetup_id);
    raise exception 'Expected failed attendance INSERT';
  exception when foreign_key_violation then null;
  end;
  if not exists (
    select 1 from public.meetups where id::text = v_meetup_id
      and title = 'Original title' and photos = array['original.jpg']
  ) or not exists (
    select 1 from public.attendances where meetup_id::text = v_meetup_id
      and member_id = '00000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Failed edit did not restore original data';
  end if;

  select count(*) into v_count from public.meetups;
  begin
    perform public.save_meetup_atomic(v_payload, v_bad_members, null);
    raise exception 'Expected failed creation';
  exception when foreign_key_violation then null;
  end;
  if (select count(*) from public.meetups) <> v_count then
    raise exception 'Failed creation left a partial meetup';
  end if;

  perform public.save_meetup_atomic(v_payload, v_good_members, v_meetup_id);
  if not exists (
    select 1 from public.meetups where id::text = v_meetup_id
      and title = 'Updated title' and photos = array['new.jpg']
  ) or (select count(*) from public.attendances
        where meetup_id::text = v_meetup_id) <> 1
    or not exists (
      select 1 from public.attendances where meetup_id::text = v_meetup_id
        and member_id = '00000000-0000-0000-0000-000000000002'
    ) then
    raise exception 'Successful edit did not replace data';
  end if;

  perform public.save_meetup_atomic(v_payload, '[]', v_meetup_id);
  if exists (select 1 from public.attendances
             where meetup_id::text = v_meetup_id) then
    raise exception 'Empty selection did not clear attendances';
  end if;

  perform public.save_meetup_atomic(v_payload, v_good_members, null);
  if (select count(*) from public.meetups) <> v_count + 1
    or (select count(*) from public.attendances) <> 1 then
    raise exception 'Successful creation did not save meetup and attendances';
  end if;

  perform set_config('rpc_test.deny_update', 'true', true);
  begin
    perform public.save_meetup_atomic(
      v_payload || '{"title":"Denied title"}', v_good_members, v_meetup_id
    );
    raise exception 'Expected RLS-denied edit';
  exception when insufficient_privilege then null;
  end;
  if exists (select 1 from public.meetups where title = 'Denied title') then
    raise exception 'RPC bypassed UPDATE RLS';
  end if;
  perform set_config('rpc_test.deny_update', 'false', true);

  begin
    perform public.save_meetup_atomic(
      v_payload, v_good_members, '00000000-0000-0000-0000-000000000088'
    );
    raise exception 'Expected unavailable meetup error';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.save_meetup_atomic(v_payload, v_good_members, null);
    raise exception 'Expected unauthenticated save error';
  exception when insufficient_privilege then null;
  end;
  if (select count(*) from public.meetups) <> v_count + 1 then
    raise exception 'Rejected saves changed meetup count';
  end if;

  raise notice 'All atomic meetup SQL assertions passed';
end;
$$;

rollback;
