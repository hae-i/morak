-- === 수정한 내용: 데이터 변경 없이 실제 RLS·함수 권한·Storage 구성을 확인한다 ===
-- Supabase SQL Editor에서 읽기 전용으로 실행할 확인 쿼리입니다. 운영 데이터 삭제/변경 없음.
select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies where schemaname in ('public','storage') order by schemaname,tablename,policyname;
select p.oid::regprocedure as function_signature,p.prosecdef as security_definer,
  pg_get_userbyid(p.proowner) as owner,p.proconfig,p.proacl
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('save_meetup_atomic','create_group_atomic',
  'get_group_summary','get_group_invite_name','delete_user');
select id,name,public,file_size_limit,allowed_mime_types from storage.buckets
where id in ('profiles','group_covers','meetup_photos');
select column_name,data_type from information_schema.columns
where table_schema='storage' and table_name='objects' and column_name in ('owner','owner_id');
select count(*) as cross_group_attendances from public.attendances a
join public.meetups m on m.id=a.meetup_id join public.group_members gm on gm.id=a.member_id
where gm.group_id<>m.group_id;
-- 객체 URL/사용자 ID/파일 이름을 출력하지 않고 오래된 파일의 개수만 확인합니다.
-- 이 수치는 고아 파일 수가 아닙니다. 참조 검증 없이 삭제 대상으로 사용하지 마세요.
select bucket_id,count(*) as objects_older_than_7_days from storage.objects
where bucket_id in ('profiles','group_covers','meetup_photos') and created_at<now()-interval '7 days'
group by bucket_id;
