-- === 수정한 내용: 개인정보 값을 출력하지 않고 새 이력·권한 설정을 읽기 전용으로 확인한다 ===
select column_name,data_type,is_nullable,column_default from information_schema.columns
where table_schema='public' and ((table_name='group_members' and column_name in ('is_deleted','left_at'))
  or (table_name='meetups' and column_name in ('author_member_id','author_name','author_deleted')))
order by table_name,column_name;
select conname,pg_get_constraintdef(oid) as definition from pg_constraint
where conrelid='public.group_members'::regclass and conname in ('group_members_role_check','group_members_user_id_fkey');
select tablename,policyname,cmd,qual,with_check from pg_policies
where schemaname='public' and tablename in ('groups','group_members','meetups','attendances') order by tablename,policyname;
select p.oid::regprocedure as signature,p.prosecdef as security_definer,p.proconfig,
  has_function_privilege('anon',p.oid,'execute') as anon_execute,
  has_function_privilege('authenticated',p.oid,'execute') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('join_group','leave_group','remove_group_member','transfer_group_host',
  'delete_user','morak_is_manager','morak_can_edit_meetup','morak_can_delete_meetup');
select count(*) as invalid_active_administrators from public.group_members
where role in ('host','deputy') and (is_deleted or user_id is null);
select count(*) as groups_without_active_host from public.groups g
where not exists(select 1 from public.group_members m where m.group_id=g.id and m.role='host' and not m.is_deleted and m.user_id is not null);
select count(*) as inconsistent_authors from public.meetups m join public.group_members a on a.id=m.author_member_id
where m.group_id<>a.group_id or m.author_deleted<>a.is_deleted;
select count(*) as legacy_unknown_authors from public.meetups where author_member_id is null;
select count(*) as cross_group_attendances from public.attendances a join public.meetups m on m.id=a.meetup_id
join public.group_members gm on gm.id=a.member_id where gm.group_id<>m.group_id;
select has_table_privilege('authenticated','public.group_members','delete') as client_member_delete,
  has_column_privilege('authenticated','public.group_members','is_deleted','update') as client_status_update,
  has_column_privilege('authenticated','public.meetups','author_name','update') as client_author_update;
