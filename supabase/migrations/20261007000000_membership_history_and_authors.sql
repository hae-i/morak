-- === 수정한 내용: 탈퇴 이력·부방장·기록 작성자 권한을 기존 데이터 삭제 없이 서버에 적용한다 ===
-- apply_private_photos_and_host_rules.sql 적용 후 실행할 추가 SQL. 초기화 SQL이 아닙니다.
begin;
do $$ begin
  if to_regprocedure('public.morak_can_read_photo(text,text)') is null then
    raise exception 'Apply private photos and host rules first';
  end if;
  if exists(select 1 from pg_policies where schemaname='public'
    and tablename in ('groups','group_members','meetups','attendances')
    and policyname not in ('morak_groups_select','morak_groups_update','morak_groups_delete',
      'morak_members_select','morak_members_insert','morak_members_update','morak_members_delete',
      'morak_meetups_access','morak_meetups_read','morak_meetups_insert','morak_meetups_update','morak_meetups_delete',
      'morak_attendances_read','morak_attendances_insert','morak_attendances_update','morak_attendances_delete')) then
    raise exception 'Unknown application policy; review before applying';
  end if;
  if exists(select 1 from public.group_members where role not in ('host','member','deputy')) then
    raise exception 'Unexpected membership role';
  end if;
  if exists(select 1 from pg_constraint c join pg_attribute a
    on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
    where c.conrelid='public.group_members'::regclass and c.contype='c'
      and a.attname='role' and c.conname<>'group_members_role_check') then
    raise exception 'Unexpected role check constraint; review before applying';
  end if;
end $$;
alter table public.group_members add column if not exists is_deleted boolean not null default false;
alter table public.group_members add column if not exists left_at timestamptz;
alter table public.group_members drop constraint if exists group_members_role_check;
alter table public.group_members add constraint group_members_role_check check(role in ('host','deputy','member'));
-- 계정 삭제가 멤버 ID와 참석 기록까지 CASCADE 삭제하지 않도록 참조만 끊습니다.
do $$ declare r record; v_count integer:=0; begin
  for r in select c.conname,c.confdeltype from pg_constraint c
    join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)
    where c.contype='f' and c.conrelid='public.group_members'::regclass
      and c.confrelid='public.users'::regclass and a.attname='user_id' loop
    v_count:=v_count+1;
    if r.confdeltype not in ('c','n') then raise exception 'Unexpected user foreign key'; end if;
    execute format('alter table public.group_members drop constraint %I',r.conname);
  end loop;
  if v_count<>1 then raise exception 'Expected exactly one membership user foreign key'; end if;
end $$;
alter table public.group_members add constraint group_members_user_id_fkey
  foreign key(user_id) references public.users(id) on delete set null;
alter table public.meetups add column if not exists author_member_id uuid references public.group_members(id) on delete set null;
alter table public.meetups add column if not exists author_name text;
alter table public.meetups add column if not exists author_deleted boolean not null default false;
create index if not exists morak_meetups_author_idx on public.meetups(author_member_id);

create or replace function public.morak_is_member(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid() and not is_deleted)
$$;
create or replace function public.morak_is_host(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid() and role='host' and not is_deleted)
$$;
create or replace function public.morak_is_manager(p_group_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.group_members
    where group_id=p_group_id and user_id=auth.uid() and role in ('host','deputy') and not is_deleted)
$$;
create or replace function public.morak_can_edit_meetup(p_meetup_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.meetups m
    join public.group_members me on me.group_id=m.group_id and me.user_id=auth.uid() and not me.is_deleted
    where m.id=p_meetup_id and ((m.author_member_id=me.id and not m.author_deleted)
      or ((m.author_deleted or m.author_member_id is null) and me.role in ('host','deputy'))))
$$;
create or replace function public.morak_can_delete_meetup(p_meetup_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.meetups m
    join public.group_members me on me.group_id=m.group_id and me.user_id=auth.uid() and not me.is_deleted
    where m.id=p_meetup_id and (m.author_member_id=me.id or me.role in ('host','deputy')))
$$;
create or replace function public.morak_valid_attendance(p_meetup_id uuid,p_member_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select public.morak_can_edit_meetup(p_meetup_id) and exists(select 1 from public.meetups m
    join public.group_members gm on gm.id=p_member_id and gm.group_id=m.group_id where m.id=p_meetup_id)
$$;

create or replace function public.morak_guard_member_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.id is distinct from old.id or new.group_id is distinct from old.group_id then
    raise exception 'Membership identity is immutable' using errcode='42501';
  end if;
  -- FK SET NULL은 부모 프로필 삭제가 실제로 진행된 경우에만 허용합니다.
  if new.user_id is distinct from old.user_id then
    if new.user_id is not null or exists(select 1 from public.users where id=old.user_id) then
      raise exception 'Membership identity is immutable' using errcode='42501';
    end if;
    new.is_deleted:=true; new.left_at:=now(); new.role:='member';
    new.display_name:='탈퇴한 멤버'; new.profile_image_url:=null; new.bio:=null; new.is_birthday_public:=false;
    return new;
  end if;
  if new.is_deleted is distinct from old.is_deleted then
    if old.user_id is distinct from auth.uid() and not
      (new.is_deleted and public.morak_is_manager(old.group_id) and
       (old.role='member' or public.morak_is_host(old.group_id))) then
      raise exception 'Membership status denied' using errcode='42501';
    end if;
  elsif new.left_at is distinct from old.left_at then
    raise exception 'Membership history is immutable' using errcode='42501';
  end if;
  if new.role is distinct from old.role and not public.morak_is_host(old.group_id)
      and not (new.is_deleted and new.role='member') then
    raise exception 'Host role required' using errcode='42501';
  end if;
  if old.is_deleted and new.is_deleted and
    (new.display_name is distinct from old.display_name or new.profile_image_url is distinct from old.profile_image_url
      or new.is_birthday_public is distinct from old.is_birthday_public or new.bio is distinct from old.bio) then
    raise exception 'Rejoin before editing member profile' using errcode='42501';
  end if;
  if not (new.is_deleted is distinct from old.is_deleted) and old.user_id is distinct from auth.uid()
      and (new.display_name is distinct from old.display_name or new.profile_image_url is distinct from old.profile_image_url
        or new.is_birthday_public is distinct from old.is_birthday_public or new.bio is distinct from old.bio) then
    raise exception 'Own profile only' using errcode='42501';
  end if;
  return new;
end $$;
create or replace function public.morak_guard_host_membership()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_group uuid;
begin
  if tg_op='INSERT' then v_group:=new.group_id; else v_group:=old.group_id; end if;
  perform 1 from public.groups where id=v_group for update;
  if not found then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then raise exception 'Use membership leave RPC' using errcode='42501'; end if;
  if new.role in ('host','deputy') and (new.user_id is null or new.is_deleted) then
    raise exception 'An active real account is required for administrator' using errcode='23514';
  end if;
  if tg_op='UPDATE' then
    if old.role='host' and (new.role<>'host' or new.is_deleted or new.user_id is null)
      and not exists(select 1 from public.group_members where group_id=v_group and id<>old.id
        and role='host' and user_id is not null and not is_deleted) then
      raise exception 'Last host cannot leave or be demoted' using errcode='23514';
    end if;
    if new.role is distinct from old.role and not public.morak_is_host(v_group)
      and not (new.role='member' and new.is_deleted and old.role<>'host') then
      raise exception 'Host role required after locking group' using errcode='42501';
    end if;
  end if;
  return new;
end $$;

-- 멤버 익명화 트리거 다음에 방장 보존 검사를 실행합니다(FK SET NULL 포함).
drop trigger if exists morak_guard_host_membership on public.group_members;
drop trigger if exists morak_z_guard_host_membership on public.group_members;
create trigger morak_z_guard_host_membership before insert or update or delete on public.group_members
  for each row execute function public.morak_guard_host_membership();

create or replace function public.leave_group(p_group_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_member public.group_members%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.groups where id=p_group_id for update;
  select * into v_member from public.group_members where group_id=p_group_id and user_id=auth.uid() and not is_deleted;
  if not found then return; end if;
  if v_member.role='host' then raise exception 'Transfer host before leaving' using errcode='23514'; end if;
  update public.group_members set is_deleted=true,left_at=now(),role='member',display_name='탈퇴한 멤버',
    profile_image_url=null,bio=null,is_birthday_public=false where id=v_member.id;
end $$;
create or replace function public.remove_group_member(p_member_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_member public.group_members%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into v_member from public.group_members where id=p_member_id;
  if not found then raise exception 'Member unavailable' using errcode='42501'; end if;
  perform 1 from public.groups where id=v_member.group_id for update;
  select * into v_member from public.group_members where id=p_member_id;
  if not public.morak_is_manager(v_member.group_id) or v_member.role='host'
    or (v_member.role='deputy' and not public.morak_is_host(v_member.group_id)) then
    raise exception 'Member management denied' using errcode='42501';
  end if;
  if v_member.is_deleted then return; end if;
  update public.group_members set is_deleted=true,left_at=now(),role='member',display_name='탈퇴한 멤버',
    profile_image_url=null,bio=null,is_birthday_public=false where id=p_member_id;
end $$;
create or replace function public.join_group(p_group_id uuid,p_display_name text,
  p_profile_image_url text default null,p_is_birthday_public boolean default true)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_member public.group_members%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if coalesce(btrim(p_display_name),'')='' or p_is_birthday_public is null then
    raise exception 'Invalid member fields' using errcode='22023';
  end if;
  perform 1 from public.groups where id=p_group_id for update;
  if not found then raise exception 'Group unavailable' using errcode='42501'; end if;
  select * into v_member from public.group_members where group_id=p_group_id and user_id=auth.uid();
  if found then
    if v_member.is_deleted then
      update public.group_members set is_deleted=false,left_at=null,role='member',display_name=p_display_name,
        profile_image_url=p_profile_image_url,is_birthday_public=p_is_birthday_public where id=v_member.id;
    end if;
    return v_member.id;
  end if;
  insert into public.group_members(group_id,user_id,role,display_name,profile_image_url,is_birthday_public)
    values(p_group_id,auth.uid(),'member',p_display_name,p_profile_image_url,p_is_birthday_public) returning id into v_id;
  return v_id;
end $$;
create or replace function public.transfer_group_host(p_group_id uuid,p_member_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_me uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.groups where id=p_group_id for update;
  select id into v_me from public.group_members where group_id=p_group_id and user_id=auth.uid() and role='host' and not is_deleted;
  if v_me is null then raise exception 'Host required' using errcode='42501'; end if;
  if p_member_id=v_me or not exists(select 1 from public.group_members where id=p_member_id
    and group_id=p_group_id and user_id is not null and not is_deleted) then
    raise exception 'A different active member is required' using errcode='22023';
  end if;
  update public.group_members set role='host' where id=p_member_id;
  update public.group_members set role='member' where id=v_me;
end $$;
create or replace function public.delete_user()
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.groups g where exists(select 1 from public.group_members m
    where m.group_id=g.id and m.user_id=auth.uid()) order by g.id for update;
  if exists(select 1 from public.group_members where user_id=auth.uid() and role='host' and not is_deleted) then
    raise exception 'Transfer all host roles before deleting account' using errcode='23514';
  end if;
  delete from auth.users where id=auth.uid();
end $$;

-- 작성자는 INSERT 시 인증 사용자로 결정하고 클라이언트가 바꾸지 못하게 합니다.
create or replace function public.morak_guard_meetup_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.id is distinct from old.id or new.group_id is distinct from old.group_id then
    raise exception 'Meetup identity is immutable' using errcode='42501';
  end if;
  -- 모임 자체 삭제의 CASCADE 중 작성자 FK SET NULL은 곧 글도 삭제되므로 허용합니다.
  -- RLS로 숨겨진 부모를 없다고 오인하지 않도록 이 트리거는 DEFINER로 부모 존재를 확인합니다.
  if old.author_member_id is not null and new.author_member_id is null
    and not exists(select 1 from public.group_members where id=old.author_member_id)
    and not exists(select 1 from public.groups where id=old.group_id) then
    return new;
  end if;
  if (new.author_member_id is distinct from old.author_member_id or new.author_name is distinct from old.author_name
      or new.author_deleted is distinct from old.author_deleted)
    and coalesce(current_setting('morak.author_sync',true),'')<>'true' then
    raise exception 'Meetup author is immutable' using errcode='42501';
  end if;
  return new;
end $$;
create or replace function public.morak_assign_author()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_member public.group_members%rowtype;
begin
  -- 탈퇴/작성 경쟁은 그룹 잠금으로 직렬화합니다.
  perform 1 from public.groups where id=new.group_id for update;
  select * into v_member from public.group_members where group_id=new.group_id and user_id=auth.uid() and not is_deleted;
  if not found then raise exception 'Active membership required' using errcode='42501'; end if;
  new.author_member_id:=v_member.id; new.author_name:=v_member.display_name; new.author_deleted:=false;
  return new;
end $$;
drop trigger if exists morak_assign_author on public.meetups;
create trigger morak_assign_author before insert on public.meetups for each row execute function public.morak_assign_author();
create or replace function public.morak_sync_author()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_previous text:=coalesce(current_setting('morak.author_sync',true),'');
begin
  perform set_config('morak.author_sync','true',true);
  update public.meetups set author_name=case when new.is_deleted then '탈퇴한 멤버' else new.display_name end,
    author_deleted=new.is_deleted where author_member_id=new.id;
  perform set_config('morak.author_sync',v_previous,true);
  return new;
end $$;
drop trigger if exists morak_sync_author on public.group_members;
create trigger morak_sync_author after update of is_deleted,display_name,user_id on public.group_members
  for each row execute function public.morak_sync_author();

-- 기존 ALL 정책을 남기면 아래 제한이 OR 결합으로 우회되므로 반드시 교체합니다.
drop policy if exists morak_members_delete on public.group_members;
drop policy if exists morak_groups_update on public.groups;
create policy morak_groups_update on public.groups for update to authenticated
  using(public.morak_is_manager(id)) with check(public.morak_is_manager(id));
drop policy if exists morak_meetups_access on public.meetups;
drop policy if exists morak_meetups_read on public.meetups;
drop policy if exists morak_meetups_insert on public.meetups;
drop policy if exists morak_meetups_update on public.meetups;
drop policy if exists morak_meetups_delete on public.meetups;
create policy morak_meetups_read on public.meetups for select to authenticated using(public.morak_is_member(group_id));
create policy morak_meetups_insert on public.meetups for insert to authenticated with check(public.morak_is_member(group_id));
create policy morak_meetups_update on public.meetups for update to authenticated
  using(public.morak_can_edit_meetup(id)) with check(public.morak_can_edit_meetup(id));
create policy morak_meetups_delete on public.meetups for delete to authenticated using(public.morak_can_delete_meetup(id));
drop policy if exists morak_attendances_delete on public.attendances;
create policy morak_attendances_delete on public.attendances for delete to authenticated using(public.morak_can_edit_meetup(meetup_id));
-- 탈퇴 상태·작성자 메타데이터는 클라이언트 직접 쓰기 대상에서 제외합니다.
revoke update,delete on public.group_members from authenticated,anon,public;
grant update(display_name,profile_image_url,is_birthday_public,bio,role) on public.group_members to authenticated;
revoke insert on public.group_members from authenticated,anon,public;
grant insert(group_id,user_id,role,display_name,profile_image_url,is_birthday_public,bio) on public.group_members to authenticated;
revoke update on public.meetups from authenticated,anon,public;
grant update(group_id,title,meet_date,location,menu,photos) on public.meetups to authenticated;
revoke all on function public.morak_is_manager(uuid),public.morak_can_edit_meetup(uuid),public.morak_can_delete_meetup(uuid),
  public.remove_group_member(uuid),public.join_group(uuid,text,text,boolean) from public,anon;
grant execute on function public.morak_is_manager(uuid),public.morak_can_edit_meetup(uuid),public.morak_can_delete_meetup(uuid),
  public.remove_group_member(uuid),public.join_group(uuid,text,text,boolean) to authenticated;
revoke all on function public.morak_assign_author(),public.morak_sync_author() from public,anon,authenticated;
-- get_group_summary 갱신은 이 트랜잭션 아래에 포함됩니다.

create or replace function public.get_group_summary(p_group_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_group public.groups%rowtype;
  v_total bigint;
  v_members jsonb;
begin
  -- SECURITY DEFINER로 RLS 재귀 없이 조회하므로 함수 내부에서 로그인과 그룹 소속을 먼저 확인합니다.
  if auth.uid() is null or not exists (
    select 1 from public.group_members where group_id = p_group_id and user_id = auth.uid() and not is_deleted
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
      jsonb_build_object('birthday', case when not gm.is_deleted and gm.is_birthday_public then u.birthday else null end) as users
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

commit;
