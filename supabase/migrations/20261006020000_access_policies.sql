-- === 수정한 내용: 기존 데이터를 보존하고 모임 소속·방장·본인 프로필 및 파일 소유권을 서버에서 제한한다 ===
-- 추가 SQL이며 아직 실행하지 않았습니다. reset_and_setup.sql을 다시 실행하면 안 됩니다.
-- 20261006010000_group_summary.sql을 먼저 적용해야 현재 클라이언트가 공개 생일을 계속 조회할 수 있습니다.
-- 공개 사진 URL은 유지합니다. 비공개 bucket 전환과 Storage 파일 삭제는 포함하지 않습니다.
begin;
do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema='storage'
      and table_name='objects' and column_name='owner_id' and data_type='text') then
    raise exception 'Storage owner_id schema differs; review actual Storage schema first';
  end if;
  if to_regprocedure('public.get_group_summary(uuid)') is null then
    raise exception 'Apply group_summary.sql first';
  end if;
  if exists (select 1 from public.attendances a join public.meetups m on m.id=a.meetup_id
      join public.group_members gm on gm.id=a.member_id where gm.group_id<>m.group_id) then
    raise exception 'Cross-group attendance exists; review existing data first';
  end if;
  -- 알 수 없는 정책을 임의 삭제하거나 함께 남겨 보안 제한을 우회하게 하지 않습니다.
  if exists (select 1 from pg_policies where schemaname='public'
      and tablename in ('users','groups','group_members','meetups','attendances')
      and policyname not in (
        '로그인한 유저는 프로필 조회 가능','본인 프로필만 생성 가능','본인 프로필만 수정 가능',
        'Enable all for authenticated users on groups','Enable all for authenticated users on group_members',
        'Enable all for authenticated users on meetups','Enable all for authenticated users on attendances',
        'morak_users_select','morak_users_insert','morak_users_update','morak_groups_select','morak_groups_update','morak_groups_delete',
        'morak_members_select','morak_members_insert','morak_members_update','morak_members_delete',
        'morak_meetups_access','morak_attendances_read','morak_attendances_insert','morak_attendances_update','morak_attendances_delete')) then
    raise exception 'Unknown application RLS policy; review it before applying this script';
  end if;
  if exists (select 1 from pg_policies where schemaname='storage' and tablename='objects'
      and policyname not in ('프로필 사진 누구나 보기 가능','프로필 사진 조작은 로그인한 유저만',
        '커버 누구나 보기 가능','커버 조작은 로그인한 유저만','기록 사진 누구나 보기 가능','기록 사진 조작은 로그인한 유저만',
        'morak_objects_read','morak_objects_insert','morak_objects_update','morak_objects_delete')) then
    raise exception 'Unknown Storage policy; review its bucket scope before applying this script';
  end if;
end $$;

create or replace function public.morak_is_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid())
$$;
create or replace function public.morak_is_host(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid() and role='host')
$$;
create or replace function public.morak_group_exists(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (select 1 from public.groups where id=p_group_id)
$$;
create or replace function public.morak_valid_attendance(p_meetup_id uuid,p_member_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (select 1 from public.meetups m
    join public.group_members gm on gm.id=p_member_id and gm.group_id=m.group_id
    where m.id=p_meetup_id and public.morak_is_member(m.group_id))
$$;
revoke all on function public.morak_is_member(uuid), public.morak_is_host(uuid),
  public.morak_group_exists(uuid), public.morak_valid_attendance(uuid,uuid) from public,anon;
grant execute on function public.morak_is_member(uuid), public.morak_is_host(uuid),
  public.morak_group_exists(uuid), public.morak_valid_attendance(uuid,uuid) to authenticated;

-- 초대는 기존처럼 UUID 링크로 가입하는 방식입니다. 비가입자는 모임 이름만 미리 조회합니다.
create or replace function public.get_group_invite_name(p_group_id uuid)
returns text language plpgsql security definer set search_path='' as $$
declare v_name text;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select name into v_name from public.groups where id=p_group_id;
  if not found then raise exception 'Group unavailable' using errcode='42501'; end if;
  return v_name;
end $$;
revoke all on function public.get_group_invite_name(uuid) from public,anon;
grant execute on function public.get_group_invite_name(uuid) to authenticated;

-- H7 관련 쿼리: 첫 host는 RLS의 임의 host INSERT가 아닌 검증된 기존 원자적 RPC에서만 생성합니다.
-- === 수정한 내용: 알 수 없는 기존 함수의 권한만 승격하지 않고 검증된 H7 본문 전체를 명시한다 ===
create or replace function public.create_group_atomic(
  p_group_id uuid,
  p_group jsonb,
  p_member jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group public.groups%rowtype;
  v_member public.group_members%rowtype;
  v_id public.groups.id%type;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_group_id is null or p_group is null or jsonb_typeof(p_group) <> 'object'
      or p_member is null or jsonb_typeof(p_member) <> 'object' then
    raise exception 'Invalid group payload' using errcode = '22023';
  end if;
  select * into v_group from jsonb_populate_record(null::public.groups, p_group);
  select * into v_member from jsonb_populate_record(null::public.group_members, p_member);
  if coalesce(btrim(v_group.name), '') = ''
      or coalesce(btrim(v_member.display_name), '') = ''
      or v_member.is_birthday_public is null then
    raise exception 'Invalid group fields' using errcode = '22023';
  end if;

  -- SERIALIZE 동일 UUID 요청; 선행 트랜잭션 실패 시 다음 요청이 정상 생성합니다.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_group_id::text, 0));
  select g.id into v_id from public.groups g where g.id = p_group_id;
  if found then
    if not exists (
      select 1 from public.group_members m
      where m.group_id = v_id and m.user_id = auth.uid() and m.role = 'host'
    ) then
      raise exception 'Group unavailable' using errcode = '42501';
    end if;
    return jsonb_build_object('id', v_id, 'created', false);
  end if;

  insert into public.groups(id, name, theme_color, theme_emoji, cover_image_url, logo_image_url)
  values (p_group_id, v_group.name, v_group.theme_color, v_group.theme_emoji,
    v_group.cover_image_url, v_group.logo_image_url)
  returning id into v_id;
  insert into public.group_members(group_id, user_id, role, display_name, profile_image_url, is_birthday_public)
  values (v_id, auth.uid(), 'host', v_member.display_name,
    v_member.profile_image_url, v_member.is_birthday_public);
  return jsonb_build_object('id', v_id, 'created', true);
end;
$$;
revoke all on function public.create_group_atomic(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.create_group_atomic(uuid, jsonb, jsonb) to authenticated;

-- PK/소속 변경으로 기존 데이터의 권한을 옮기거나 타인의 프로필을 바꾸는 것을 막습니다.
create or replace function public.morak_guard_member_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.id is distinct from old.id or new.group_id is distinct from old.group_id
      or new.user_id is distinct from old.user_id then
    raise exception 'Membership identity is immutable' using errcode='42501';
  end if;
  if new.role is distinct from old.role and not public.morak_is_host(old.group_id) then
    raise exception 'Host role required' using errcode='42501';
  end if;
  if old.user_id is distinct from auth.uid() and old.user_id is not null
      and (new.display_name is distinct from old.display_name or new.profile_image_url is distinct from old.profile_image_url
        or new.is_birthday_public is distinct from old.is_birthday_public or new.bio is distinct from old.bio) then
    raise exception 'Own profile only' using errcode='42501';
  end if;
  return new;
end $$;
drop trigger if exists morak_guard_member_update on public.group_members;
create trigger morak_guard_member_update before update on public.group_members
  for each row execute function public.morak_guard_member_update();
create or replace function public.morak_guard_meetup_update()
returns trigger language plpgsql set search_path='' as $$
begin
  if new.id is distinct from old.id or new.group_id is distinct from old.group_id then
    raise exception 'Meetup identity is immutable' using errcode='42501';
  end if;
  return new;
end $$;
drop trigger if exists morak_guard_meetup_update on public.meetups;
create trigger morak_guard_meetup_update before update on public.meetups
  for each row execute function public.morak_guard_meetup_update();
revoke all on function public.morak_guard_member_update(),public.morak_guard_meetup_update() from public,anon,authenticated;

-- 사전에 확인한 이 앱의 알려진 정책만 교체합니다.
do $$ declare r record; begin
  for r in select schemaname,tablename,policyname from pg_policies
    where (schemaname='public' and tablename in ('users','groups','group_members','meetups','attendances'))
       or (schemaname='storage' and tablename='objects') loop
    execute format('drop policy %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end $$;
alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.meetups enable row level security;
alter table public.attendances enable row level security;
create policy morak_users_select on public.users for select to authenticated using(id=auth.uid());
create policy morak_users_insert on public.users for insert to authenticated with check(id=auth.uid());
create policy morak_users_update on public.users for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy morak_groups_select on public.groups for select to authenticated using(public.morak_is_member(id));
create policy morak_groups_update on public.groups for update to authenticated using(public.morak_is_host(id)) with check(public.morak_is_host(id));
create policy morak_groups_delete on public.groups for delete to authenticated using(public.morak_is_host(id));
create policy morak_members_select on public.group_members for select to authenticated
  using(user_id=auth.uid() or public.morak_is_member(group_id));
create policy morak_members_insert on public.group_members for insert to authenticated
  with check(public.morak_group_exists(group_id) and role='member' and
    ((user_id=auth.uid()) or (user_id is null and public.morak_is_host(group_id))));
create policy morak_members_update on public.group_members for update to authenticated
  using(user_id=auth.uid() or public.morak_is_host(group_id))
  with check(user_id=auth.uid() or public.morak_is_host(group_id));
create policy morak_members_delete on public.group_members for delete to authenticated
  using(user_id=auth.uid() or public.morak_is_host(group_id));
create policy morak_meetups_access on public.meetups for all to authenticated
  using(public.morak_is_member(group_id)) with check(public.morak_is_member(group_id));
create policy morak_attendances_read on public.attendances for select to authenticated
  using(exists(select 1 from public.meetups m where m.id=meetup_id and public.morak_is_member(m.group_id)));
create policy morak_attendances_delete on public.attendances for delete to authenticated
  using(exists(select 1 from public.meetups m where m.id=meetup_id and public.morak_is_member(m.group_id)));
create policy morak_attendances_insert on public.attendances for insert to authenticated
  with check(public.morak_valid_attendance(meetup_id,member_id));
create policy morak_attendances_update on public.attendances for update to authenticated
  using(public.morak_valid_attendance(meetup_id,member_id)) with check(public.morak_valid_attendance(meetup_id,member_id));

-- 공개 bucket의 기존 읽기 동작은 유지하고 파일 조작은 업로드한 본인으로 제한합니다.
-- 표준 Supabase Storage의 owner_id(text) 컬럼이 실제 DB에 있어야 합니다.
create policy morak_objects_read on storage.objects for select
  using(bucket_id in ('profiles','group_covers','meetup_photos'));
create policy morak_objects_insert on storage.objects for insert to authenticated
  with check(bucket_id in ('profiles','group_covers','meetup_photos') and owner_id=auth.uid()::text);
create policy morak_objects_update on storage.objects for update to authenticated
  using(bucket_id in ('profiles','group_covers','meetup_photos') and owner_id=auth.uid()::text)
  with check(bucket_id in ('profiles','group_covers','meetup_photos') and owner_id=auth.uid()::text);
create policy morak_objects_delete on storage.objects for delete to authenticated
  using(bucket_id in ('profiles','group_covers','meetup_photos') and owner_id=auth.uid()::text);
commit;
