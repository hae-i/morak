\set ON_ERROR_STOP on
-- === 수정한 내용: 실제 DB에서 최초 방장 실패의 rollback, 재시도 중복 방지와 인증 검증을 확인한다 ===
-- 새로 만든 비어 있는 테스트 DB 전용입니다. 운영 DB에서 실행하지 마세요.
begin;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
end $$;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema public, auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.users(id uuid primary key);
create table public.groups(
  id uuid primary key default gen_random_uuid(), name text not null,
  theme_color text, theme_emoji text, cover_image_url text, logo_image_url text
);
create table public.group_members(
  id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups(id),
  user_id uuid references public.users(id), role text not null default 'member',
  display_name text not null, profile_image_url text, is_birthday_public boolean default true,
  joined_at timestamptz not null default now(), unique(group_id, user_id)
);
insert into public.users values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
create policy group_access on public.groups for all to authenticated using (true) with check (true);
create policy member_read on public.group_members for select to authenticated using (true);
create policy member_insert on public.group_members for insert to authenticated
  with check (current_setting('rpc_test.deny_member', true) is distinct from 'true');
grant select, insert on public.groups, public.group_members to authenticated;
\ir ../migrations/20261006000000_create_group_atomic.sql
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
set local role authenticated;
do $$
declare
  v_id uuid := '00000000-0000-4000-8000-000000000010';
  v_group jsonb := '{"name":"Group","theme_color":"#123456"}';
  v_member jsonb := '{"display_name":"Owner","is_birthday_public":false,"user_id":"00000000-0000-0000-0000-000000000002","role":"member"}';
  v_result jsonb;
begin
  perform set_config('rpc_test.deny_member', 'true', true);
  begin
    perform public.create_group_atomic(v_id, v_group, v_member);
    raise exception 'Expected host insertion rejection';
  exception when insufficient_privilege then null;
  end;
  if exists (select 1 from public.groups where id = v_id) then raise exception 'Partial group persisted'; end if;
  perform set_config('rpc_test.deny_member', 'false', true);
  v_result := public.create_group_atomic(v_id, v_group, v_member);
  if (v_result->>'created')::boolean is distinct from true then raise exception 'Creation result invalid'; end if;
  if not exists (select 1 from public.group_members where group_id = v_id and user_id = auth.uid()
    and role = 'host' and is_birthday_public = false) then raise exception 'Host or privacy fields invalid'; end if;
  v_result := public.create_group_atomic(v_id, v_group, v_member);
  if (v_result->>'created')::boolean is distinct from false
    or (select count(*) from public.groups) <> 1 or (select count(*) from public.group_members) <> 1
    then raise exception 'Retry created duplicate data'; end if;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
  begin
    perform public.create_group_atomic(v_id, v_group, v_member);
    raise exception 'Expected different user denial';
  exception when insufficient_privilege then null;
  end;
  perform set_config('request.jwt.claim.sub', '', true);
  begin
    perform public.create_group_atomic(v_id, v_group, v_member);
    raise exception 'Expected unauthenticated denial';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  if has_function_privilege('anon', 'public.create_group_atomic(uuid,jsonb,jsonb)', 'execute') then
    raise exception 'Anonymous execution allowed';
  end if;
end $$;
rollback;
