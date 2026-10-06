-- === 수정한 내용: 모임 사진 비공개 조회와 방장 위임·탈퇴 제한을 기존 데이터 삭제 없이 추가한다 ===
-- 아직 실행하지 않았습니다. 앞서 확인된 스키마용입니다. 테스트 프로젝트에서 먼저 검증하세요.
-- 아래 통합 파일에는 summary/access 정책이 포함되어 있으며 reset SQL이 아닙니다.
-- 앱 인증 사진 조회 코드를 먼저 배포/실행한 뒤 적용해야 기존 버전의 사진 표시 오류를 줄일 수 있습니다.
-- Global 50MB는 사용자가 확인한 Dashboard 값이며 여기서는 사진당 기존 앱 제한 10MB만 설정합니다.
begin;
-- === 수정한 내용: 전체 기록을 앱에 전송하지 않고 서버에서 참석 통계를 계산하는 조회 RPC를 추가한다 ===
-- 데이터 보존용 추가 SQL입니다. DB에 실행하지 않았습니다. 초기화 스크립트를 다시 실행하지 마세요.

create index if not exists morak_meetups_group_date_id_idx on public.meetups(group_id, meet_date desc, id desc);
create index if not exists morak_members_user_group_idx on public.group_members(user_id, group_id);
create index if not exists morak_attendances_member_idx on public.attendances(member_id);

create or replace function public.get_group_summary(p_group_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_group public.groups%rowtype;
  v_total bigint;
  v_members jsonb;
begin
  -- SECURITY DEFINER로 RLS 재귀 없이 조회하므로 함수 내부에서 로그인과 그룹 소속을 먼저 확인합니다.
  if auth.uid() is null or not exists (
    select 1 from public.group_members where group_id = p_group_id and user_id = auth.uid()
  ) then raise exception 'Group unavailable' using errcode = '42501'; end if;
  select * into v_group from public.groups where id = p_group_id;
  if not found then raise exception 'Group unavailable' using errcode = '42501'; end if;
  select count(*) into v_total from public.meetups where group_id = p_group_id;
  with counts as (
    select a.member_id, count(*) as attended_count from public.attendances a
    join public.meetups m on m.id = a.meetup_id where m.group_id = p_group_id group by a.member_id
  ), ranked as (
    select gm.*, coalesce(c.attended_count, 0) as attended_count,
      case when v_total > 0 then coalesce(c.attended_count, 0)::numeric * 100 / v_total else 0 end as attendance_rate,
      -- 생일 비공개는 이 RPC 응답에 생일을 포함하지 않습니다. 직접 users 조회 정책은 별도 보완 대상입니다.
      jsonb_build_object('birthday', case when gm.is_birthday_public then u.birthday else null end) as users
    from public.group_members gm left join counts c on c.member_id = gm.id
    left join public.users u on u.id = gm.user_id where gm.group_id = p_group_id
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.attendance_rate desc, r.display_name, r.id), '[]'::jsonb)
    into v_members from ranked r;
  return jsonb_build_object('group', to_jsonb(v_group), 'totalMeetups', v_total, 'rankedMembers', v_members);
end;
$$;
revoke all on function public.get_group_summary(uuid) from public, anon;
grant execute on function public.get_group_summary(uuid) to authenticated;

-- === 수정한 내용: 기존 데이터를 보존하고 모임 소속·방장·본인 프로필 및 파일 소유권을 서버에서 제한한다 ===
-- 추가 SQL이며 아직 실행하지 않았습니다. reset_and_setup.sql을 다시 실행하면 안 됩니다.
-- 위에서 summary RPC를 포함했으므로 해당 migration을 따로 먼저 실행할 필요는 없습니다.
-- 이 통합본은 뒤쪽에서 비공개 정책으로 교체합니다. 파일은 삭제하지 않습니다.

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


-- === 수정한 내용: 계정/멤버/기록 삭제가 예상한 CASCADE 구조인지 확인하고 다르면 중단한다 ===
do $$ declare r record; begin
 for r in select * from (values
   ('public.users','id','auth.users'),
   ('public.group_members','user_id','public.users'),
   ('public.group_members','group_id','public.groups'),
   ('public.meetups','group_id','public.groups'),
   ('public.attendances','meetup_id','public.meetups'),
   ('public.attendances','member_id','public.group_members')
 ) as required(source_table,source_column,target_table) loop
   if not exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid
     and a.attname=r.source_column and c.conkey=array[a.attnum]
     where c.contype='f' and c.conrelid=to_regclass(r.source_table)
       and c.confrelid=to_regclass(r.target_table) and c.confdeltype='c') then
     raise exception 'Expected CASCADE foreign key missing on %.%; inspect current schema',r.source_table,r.source_column;
   end if;
 end loop;
end $$;

-- === 수정한 내용: 기존 사진의 경로와 실제 파일을 먼저 확인하고 충돌 시 전체 적용을 취소한다 ===
do $$ begin
 if exists(
   with refs as (
     select 'profiles' as bucket,profile_image_url as url from public.users
     union all select 'profiles',profile_image_url from public.group_members
     union all select 'group_covers',cover_image_url from public.groups
     union all select 'group_covers',logo_image_url from public.groups
     union all select 'meetup_photos',unnest(photos) from public.meetups
   )
   select 1 from refs r where r.url is not null and not exists(select 1 from storage.objects o
     where o.bucket_id=r.bucket and o.name=split_part(split_part(r.url,'/storage/v1/object/public/'||r.bucket||'/',2),'?',1))
 ) then raise exception 'Unsupported or missing photo references; inspect read-only verification before migration'; end if;
end $$;

-- === 수정한 내용: 동시 강등·탈퇴를 모임 행 잠금으로 직렬화하고 방장이 없는 모임 생성 상태를 먼저 확인한다 ===
do $$ begin
  if exists(select 1 from public.groups g where not exists(select 1 from public.group_members m
    where m.group_id=g.id and m.role='host' and m.user_id is not null)) then
    raise exception 'A group has no real host; assign a host before migration';
  end if;
end $$;

create or replace function public.morak_guard_host_membership()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_group uuid;
begin
  if tg_op='INSERT' then v_group:=new.group_id; else v_group:=old.group_id; end if;
  -- 모임 자체 삭제의 CASCADE에서는 부모가 이미 없어 삭제를 허용합니다.
  perform 1 from public.groups where id=v_group for update;
  if not found then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op<>'DELETE' and new.role='host' and new.user_id is null then
    raise exception 'A real account is required for host' using errcode='23514';
  end if;
  if tg_op='DELETE' then
    if old.role='host' then
      raise exception 'Transfer host and become a member before leaving' using errcode='23514';
    end if;
    return old;
  end if;
  if tg_op='UPDATE' and new.role is distinct from old.role and not public.morak_is_host(v_group) then
    raise exception 'Host required after locking group' using errcode='42501';
  end if;
  if tg_op='UPDATE' and old.role='host' and new.role<>'host'
    and not exists(select 1 from public.group_members where group_id=v_group and id<>old.id and role='host' and user_id is not null) then
    raise exception 'Last host cannot be demoted' using errcode='23514';
  end if;
  return new;
end $$;
drop trigger if exists morak_guard_host_membership on public.group_members;
create trigger morak_guard_host_membership before insert or update or delete on public.group_members
for each row execute function public.morak_guard_host_membership();
revoke all on function public.morak_guard_host_membership() from public,anon,authenticated;

-- 상대 승급과 본인 강등을 한 트랜잭션에서 수행합니다. 사용자를 클라이언트에서 지정하지 않습니다.
create or replace function public.transfer_group_host(p_group_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.groups where id=p_group_id for update;
  select id into v_me from public.group_members where group_id=p_group_id and user_id=auth.uid() and role='host';
  if v_me is null then raise exception 'Host required' using errcode='42501'; end if;
  if p_member_id=v_me or not exists(select 1 from public.group_members where id=p_member_id and group_id=p_group_id and user_id is not null) then
    raise exception 'A different real member is required' using errcode='22023';
  end if;
  update public.group_members set role='host' where id=p_member_id and group_id=p_group_id;
  update public.group_members set role='member' where id=v_me;
end $$;
create or replace function public.leave_group(p_group_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_member public.group_members%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.groups where id=p_group_id for update;
  select * into v_member from public.group_members where group_id=p_group_id and user_id=auth.uid();
  if not found then return; end if; -- 응답 유실 후 본인 탈퇴 재시도도 안전합니다.
  if v_member.role='host' then raise exception 'Transfer host before leaving' using errcode='23514'; end if;
  delete from public.group_members where id=v_member.id and user_id=auth.uid();
end $$;
create or replace function public.delete_user()
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  -- 여러 모임에 속한 계정의 삭제는 일정한 순서로 모임을 잠급니다.
  perform 1 from public.groups g where exists(select 1 from public.group_members m where m.group_id=g.id and m.user_id=auth.uid()) order by g.id for update;
  if exists(select 1 from public.group_members where user_id=auth.uid() and role='host') then
    raise exception 'Transfer all host roles before deleting account' using errcode='23514';
  end if;
  delete from auth.users where id=auth.uid();
end $$;
revoke all on function public.transfer_group_host(uuid,uuid),public.leave_group(uuid),public.delete_user() from public,anon;
grant execute on function public.transfer_group_host(uuid,uuid),public.leave_group(uuid),public.delete_user() to authenticated;

-- === 수정한 내용: 기존 공개 URL 컬럼은 파일 식별자로 보존하며 실제 파일 소속은 DB 참조로 확인한다 ===
create or replace function public.morak_photo_path(p_url text,p_bucket text)
returns text language sql immutable set search_path='' as $$
 select nullif(split_part(split_part(p_url,'/storage/v1/object/public/'||p_bucket||'/',2),'?',1),'')
$$;
create or replace function public.morak_can_read_photo(p_bucket text,p_path text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_referenced boolean;
begin
  if auth.uid() is null or p_bucket not in ('profiles','group_covers','meetup_photos') then return false; end if;
  if p_bucket='profiles' then
    if exists(select 1 from public.users u where u.id=auth.uid() and public.morak_photo_path(u.profile_image_url,p_bucket)=p_path)
      or exists(select 1 from public.group_members m where public.morak_photo_path(m.profile_image_url,p_bucket)=p_path and public.morak_is_member(m.group_id)) then return true; end if;
    select exists(select 1 from public.users where public.morak_photo_path(profile_image_url,p_bucket)=p_path)
      or exists(select 1 from public.group_members where public.morak_photo_path(profile_image_url,p_bucket)=p_path) into v_referenced;
  elsif p_bucket='group_covers' then
    if exists(select 1 from public.groups g where (public.morak_photo_path(g.cover_image_url,p_bucket)=p_path or public.morak_photo_path(g.logo_image_url,p_bucket)=p_path) and public.morak_is_member(g.id)) then return true; end if;
    select exists(select 1 from public.groups where public.morak_photo_path(cover_image_url,p_bucket)=p_path or public.morak_photo_path(logo_image_url,p_bucket)=p_path) into v_referenced;
  else
    if exists(select 1 from public.meetups m cross join lateral unnest(m.photos) as p(url) where public.morak_photo_path(p.url,p_bucket)=p_path and public.morak_is_member(m.group_id)) then return true; end if;
    select exists(select 1 from public.meetups m cross join lateral unnest(m.photos) as p(url) where public.morak_photo_path(p.url,p_bucket)=p_path) into v_referenced;
  end if;
  -- DB 저장 전 업로드 미리보기·실패 정리에만 미참조 파일 소유자의 읽기를 허용합니다.
  return not v_referenced and exists(select 1 from storage.objects where bucket_id=p_bucket and name=p_path and owner_id=auth.uid()::text);
end $$;
revoke all on function public.morak_can_read_photo(text,text) from public,anon;
grant execute on function public.morak_can_read_photo(text,text) to authenticated;

-- 타인의 비공개 경로를 내 모임에 저장하여 읽기 정책을 우회하는 것을 막습니다.
create or replace function public.morak_check_photo_reference(p_url text,p_bucket text)
returns void language plpgsql security definer set search_path='' as $$
declare v_path text;
begin
  if p_url is null then return; end if;
  v_path:=public.morak_photo_path(p_url,p_bucket);
  if v_path is null then raise exception 'Unsupported photo reference' using errcode='22023'; end if;
  if not exists(select 1 from storage.objects where bucket_id=p_bucket and name=v_path and owner_id=auth.uid()::text)
    and not public.morak_can_read_photo(p_bucket,v_path) then
    raise exception 'Photo reference not allowed' using errcode='42501';
  end if;
end $$;
create or replace function public.morak_guard_photo_references()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_url text;
begin
  if tg_table_name='groups' then
    if tg_op='INSERT' or new.cover_image_url is distinct from old.cover_image_url then perform public.morak_check_photo_reference(new.cover_image_url,'group_covers'); end if;
    if tg_op='INSERT' or new.logo_image_url is distinct from old.logo_image_url then perform public.morak_check_photo_reference(new.logo_image_url,'group_covers'); end if;
  elsif tg_table_name='meetups' then
    foreach v_url in array coalesce(new.photos,'{}'::text[]) loop
      if tg_op='INSERT' or not (v_url=any(coalesce(old.photos,'{}'::text[]))) then perform public.morak_check_photo_reference(v_url,'meetup_photos'); end if;
    end loop;
  else
    if tg_op='INSERT' or new.profile_image_url is distinct from old.profile_image_url then perform public.morak_check_photo_reference(new.profile_image_url,'profiles'); end if;
  end if;
  return new;
end $$;
drop trigger if exists morak_guard_photo_references on public.users;
drop trigger if exists morak_guard_photo_references on public.group_members;
drop trigger if exists morak_guard_photo_references on public.groups;
drop trigger if exists morak_guard_photo_references on public.meetups;
create trigger morak_guard_photo_references before insert or update on public.users for each row execute function public.morak_guard_photo_references();
create trigger morak_guard_photo_references before insert or update on public.group_members for each row execute function public.morak_guard_photo_references();
create trigger morak_guard_photo_references before insert or update on public.groups for each row execute function public.morak_guard_photo_references();
create trigger morak_guard_photo_references before insert or update on public.meetups for each row execute function public.morak_guard_photo_references();
revoke all on function public.morak_check_photo_reference(text,text),public.morak_guard_photo_references() from public,anon,authenticated;

-- 기존 공개 SELECT는 지우고 모임 소속/본인 프로필만 허용합니다.
drop policy morak_objects_read on storage.objects;
create policy morak_objects_read on storage.objects for select to authenticated
using(public.morak_can_read_photo(bucket_id,name));
-- 참조 중인 파일의 직접 삭제/덮어쓰기를 금지합니다. 프로필/기록은 새 고유 파일로 교체합니다.
drop policy morak_objects_update on storage.objects;
drop policy morak_objects_delete on storage.objects;
create or replace function public.morak_photo_is_referenced(p_bucket text,p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.users where p_bucket='profiles' and public.morak_photo_path(profile_image_url,p_bucket)=p_path)
 or exists(select 1 from public.group_members where p_bucket='profiles' and public.morak_photo_path(profile_image_url,p_bucket)=p_path)
 or exists(select 1 from public.groups where p_bucket='group_covers' and (public.morak_photo_path(cover_image_url,p_bucket)=p_path or public.morak_photo_path(logo_image_url,p_bucket)=p_path))
 or exists(select 1 from public.meetups m cross join lateral unnest(m.photos) as p(url) where p_bucket='meetup_photos' and public.morak_photo_path(p.url,p_bucket)=p_path)
$$;
revoke all on function public.morak_photo_is_referenced(text,text) from public,anon;
grant execute on function public.morak_photo_is_referenced(text,text) to authenticated;
create policy morak_objects_delete on storage.objects for delete to authenticated
using(bucket_id in ('profiles','group_covers','meetup_photos') and owner_id=auth.uid()::text and not public.morak_photo_is_referenced(bucket_id,name));
update storage.buckets set public=false,file_size_limit=10485760,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif']
where id in ('profiles','group_covers','meetup_photos');
commit;
