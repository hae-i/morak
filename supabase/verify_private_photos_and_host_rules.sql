-- === 수정한 내용: 실제 서버 적용 상태와 사전 충돌 가능성을 개인정보 값 없이 확인한다 ===
-- 읽기 전용입니다. 초기화/수정/삭제하지 않습니다.
select id, public, file_size_limit, allowed_mime_types from storage.buckets
where id in ('profiles','group_covers','meetup_photos');
select count(*) as groups_without_real_host from public.groups g where not exists
(select 1 from public.group_members m where m.group_id=g.id and m.role='host' and m.user_id is not null);
select count(*) as invalid_ghost_hosts from public.group_members where role='host' and user_id is null;
select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies
where (schemaname='storage' and tablename='objects') or (schemaname='public' and tablename in ('users','groups','group_members','meetups','attendances'));
select p.oid::regprocedure::text as function_signature,p.prosecdef as security_definer,p.proconfig,
 has_function_privilege('anon',p.oid,'execute') as anon_can_execute,
 has_function_privilege('authenticated',p.oid,'execute') as authenticated_can_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
and p.proname in ('leave_group','transfer_group_host','delete_user','get_group_summary','morak_can_read_photo');
select event_object_table,trigger_name,action_timing,event_manipulation from information_schema.triggers
where trigger_schema='public' and trigger_name like 'morak_guard_%';
-- 기존 저장 경로가 새 읽기 함수와 호환되지 않거나 실제 파일이 없는 경우: 개수만 출력합니다.
with refs as (
 select 'profiles' as bucket,profile_image_url as url from public.users
 union all select 'profiles',profile_image_url from public.group_members
 union all select 'group_covers',cover_image_url from public.groups
 union all select 'group_covers',logo_image_url from public.groups
 union all select 'meetup_photos',unnest(photos) from public.meetups
)
select bucket,count(*) as missing_or_unsupported_references from refs r
where r.url is not null and not exists(select 1 from storage.objects o where o.bucket_id=r.bucket
 and o.name=split_part(split_part(r.url,'/storage/v1/object/public/'||r.bucket||'/',2),'?',1))
group by bucket;

-- 계정 탈퇴와 모임 삭제의 CASCADE가 실제로 구성되어 있는지 확인합니다.
select conrelid::regclass::text as table_name, confrelid::regclass::text as referenced_table,
 pg_get_constraintdef(oid) as definition from pg_constraint where contype='f'
 and conrelid in ('public.users'::regclass,'public.group_members'::regclass,'public.meetups'::regclass,'public.attendances'::regclass);
