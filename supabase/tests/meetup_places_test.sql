\set ON_ERROR_STOP on
-- === 수정한 내용: 실제 DB의 출석 실패 rollback과 RLS 거부를 재현하는 회귀 테스트를 준비한다 ===
-- Run only in a disposable, empty PostgreSQL database. Never in production.
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
\ir ../migrations/20261008000000_meetup_places.sql


begin;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000030',true);
set local role authenticated;
do $$
declare
  payload jsonb := '{"group_id":"00000000-0000-0000-0000-000000000020","title":"With place",
    "meet_date":"2026-10-07","photos":[],"place":{"name":"Cafe","address":"Seoul Songpa",
    "latitude":37.5,"longitude":127.1,"source":"naver_search"}}';
  members jsonb := '["00000000-0000-0000-0000-000000000002"]';
  target text := '00000000-0000-0000-0000-000000000010';
  previous jsonb;
  created_id uuid;
  i integer;
begin
  -- Creation keeps place and attendance in the same transaction too.
  perform public.save_meetup_with_place_atomic(payload,members);
  select id into created_id from public.meetups where id<>target::uuid;
  if created_id is null or not exists (select 1 from public.attendances where meetup_id=created_id) then
    raise exception 'Create lost place/attendance';
  end if;
  begin
    perform public.save_meetup_with_place_atomic(payload,
      '["00000000-0000-0000-0000-000000000099"]');
    raise exception 'Invalid creation attendance accepted';
  exception when foreign_key_violation then null; end;
  if (select count(*) from public.meetups)<>2 then raise exception 'Failed creation left a record'; end if;
  perform public.save_meetup_with_place_atomic(payload,members,target);
  select place into previous from public.meetups where id=target::uuid;
  if previous->>'name' <> 'Cafe' then raise exception 'Place did not save'; end if;
  -- Invalid coordinates must also roll back the accompanying title update.
  begin
    perform public.save_meetup_with_place_atomic(jsonb_set(payload,'{place,latitude}','999'),members,target);
    raise exception 'Invalid latitude accepted';
  exception when check_violation then null; end;
  if (select place from public.meetups where id=target::uuid) <> previous then raise exception 'Invalid place changed record'; end if;
  -- A late attendance failure rolls back both metadata and coordinates.
  begin
    perform public.save_meetup_with_place_atomic(jsonb_set(payload,'{place,name}','"Changed"'),
      '["00000000-0000-0000-0000-000000000099"]',target);
    raise exception 'Invalid attendance accepted';
  exception when foreign_key_violation then null; end;
  if (select place from public.meetups where id=target::uuid) <> previous then raise exception 'Attendance failure lost place'; end if;
  if not exists (select 1 from public.attendances where meetup_id=target::uuid and member_id=(members->>0)::uuid) then raise exception 'Attendance rollback failed'; end if;
  -- Keep old text-only clients compatible without erasing a selected place.
  perform public.save_meetup_atomic(payload-'place',members,target);
  if (select place from public.meetups where id=target::uuid) <> previous then raise exception 'Legacy edit lost place'; end if;
  -- Existing RLS refusal remains authoritative for the new RPC.
  perform set_config('rpc_test.deny_update','true',true);
  begin
    perform public.save_meetup_with_place_atomic(jsonb_set(payload,'{place}','null'),members,target);
    raise exception 'RLS denial bypassed';
  exception when insufficient_privilege then null; end;
  perform set_config('rpc_test.deny_update','false',true);
  if (select place from public.meetups where id=target::uuid) <> previous then raise exception 'RLS refusal lost place'; end if;
  -- Clearing the pin deliberately still preserves the meetup/attendees.
  perform public.save_meetup_with_place_atomic(jsonb_set(payload,'{place}','null'),members,target);
  if (select place from public.meetups where id=target::uuid) is not null then raise exception 'Pin did not clear'; end if;
  -- Missing place must fail rather than interpreting a malformed request as deletion.
  begin
    perform public.save_meetup_with_place_atomic(payload-'place',members,target);
    raise exception 'Missing place accepted';
  exception when invalid_parameter_value then null; end;
  for i in 1..30 loop
    if not public.morak_consume_place_search() then raise exception 'Early rate rejection'; end if;
  end loop;
  if public.morak_consume_place_search() then raise exception 'Minute limit bypassed'; end if;
  begin
    perform * from public.morak_place_search_limits;
    raise exception 'Private quota table exposed';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;
-- Simulate window changes with owner-only fixture updates.
update public.morak_place_search_limits set minute_start=now()-interval '2 minutes';
set local role authenticated;
do $$ begin
  if not public.morak_consume_place_search() then raise exception 'Minute window did not reset'; end if;
end $$;
reset role;
update public.morak_place_search_limits set minute_start=now()-interval '2 minutes', day_count=300;
set local role authenticated;
do $$ begin
  if public.morak_consume_place_search() then raise exception 'Daily limit bypassed'; end if;
end $$;
reset role;
update public.morak_place_search_limits set day_start=(now() at time zone 'UTC')::date-1;
set local role authenticated;
do $$ begin
  if not public.morak_consume_place_search() then raise exception 'Day window did not reset'; end if;
end $$;
reset role;
do $$
begin
  if has_function_privilege('anon','public.save_meetup_with_place_atomic(jsonb,jsonb,text)','execute') then raise exception 'Anonymous place write permitted'; end if;
  if has_function_privilege('anon','public.morak_consume_place_search()','execute') then raise exception 'Anonymous quota use permitted'; end if;
end;
$$;
rollback;
