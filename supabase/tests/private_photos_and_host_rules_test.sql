-- === 수정한 내용: 위임·탈퇴·계정삭제·비멤버 사진 조회 차단을 실제 DB 트랜잭션에서 검증한다 ===
-- apply_private_photos_and_host_rules.sql 적용된 별도 테스트 Supabase 전용입니다.
-- 실제 Storage 파일을 업로드하는 테스트가 아니라 SQL ACL 검증용 metadata를 만듭니다.
-- 운영 DB에서 실행하지 마세요. 전체 실행하면 마지막 ROLLBACK으로 fixture가 사라집니다.
-- 동시성 검증은 별도 두 세션이 필요하며 docs/private_photos_and_host_rules.md에 적었습니다.
begin;
do $$ begin
 if exists(select 1 from auth.users where id in ('f0000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000003')) then raise exception 'Test fixture IDs exist'; end if;
end $$;
insert into auth.users(id,email) values
 ('f0000000-0000-4000-8000-000000000001','host@morak-test.invalid'),
 ('f0000000-0000-4000-8000-000000000002','member@morak-test.invalid'),
 ('f0000000-0000-4000-8000-000000000003','outsider@morak-test.invalid');
insert into public.users(id,display_name) values
 ('f0000000-0000-4000-8000-000000000001','Host'),('f0000000-0000-4000-8000-000000000002','Member'),('f0000000-0000-4000-8000-000000000003','Outsider');
insert into public.groups(id,name) values ('f0000000-0000-4000-8000-000000000010','Privacy test');
insert into public.group_members(id,group_id,user_id,display_name,role) values
 ('f0000000-0000-4000-8000-000000000011','f0000000-0000-4000-8000-000000000010','f0000000-0000-4000-8000-000000000001','Host','host'),
 ('f0000000-0000-4000-8000-000000000012','f0000000-0000-4000-8000-000000000010','f0000000-0000-4000-8000-000000000002','Member','member');
insert into storage.objects(bucket_id,name,owner_id,metadata) values
 ('meetup_photos','morak-policy-test/a.jpg','f0000000-0000-4000-8000-000000000001','{"mimetype":"image/jpeg","size":10}');
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000001',true);
insert into public.meetups(id,group_id,meet_date,photos) values
 ('f0000000-0000-4000-8000-000000000020','f0000000-0000-4000-8000-000000000010',now(),array['https://fixture.invalid/storage/v1/object/public/meetup_photos/morak-policy-test/a.jpg']);
set local role authenticated;
do $$ begin
 if not public.morak_can_read_photo('meetup_photos','morak-policy-test/a.jpg') then raise exception 'Host cannot read'; end if;
 begin perform public.leave_group('f0000000-0000-4000-8000-000000000010'); raise exception 'Host left'; exception when check_violation then null; end;
 begin perform public.delete_user(); raise exception 'Host deleted account'; exception when check_violation then null; end;
 begin update public.group_members set role='member' where id='f0000000-0000-4000-8000-000000000011'; raise exception 'Last host demoted'; exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000003',true);
do $$ begin
 if public.morak_can_read_photo('meetup_photos','morak-policy-test/a.jpg') then raise exception 'Outsider can read'; end if;
 if exists(select 1 from storage.objects where bucket_id='meetup_photos' and name='morak-policy-test/a.jpg') then raise exception 'Storage RLS bypass'; end if;
 begin perform public.transfer_group_host('f0000000-0000-4000-8000-000000000010','f0000000-0000-4000-8000-000000000012'); raise exception 'Outsider transferred'; exception when insufficient_privilege then null; end;
 begin perform public.morak_check_photo_reference('https://fixture.invalid/storage/v1/object/public/meetup_photos/morak-policy-test/a.jpg','meetup_photos'); raise exception 'Internal function exposed'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000002',true);
do $$ begin
 if not public.morak_can_read_photo('meetup_photos','morak-policy-test/a.jpg') then raise exception 'Member cannot read'; end if;
end $$;
select set_config('request.jwt.claim.sub','f0000000-0000-4000-8000-000000000001',true);
select public.transfer_group_host('f0000000-0000-4000-8000-000000000010','f0000000-0000-4000-8000-000000000012');
select public.leave_group('f0000000-0000-4000-8000-000000000010');
do $$ begin
 -- 업로드한 본인이라도 참조된 모임 사진은 탈퇴 후 다시 다운로드할 수 없습니다.
 if public.morak_can_read_photo('meetup_photos','morak-policy-test/a.jpg') then raise exception 'Former member can read'; end if;
end $$;
select public.delete_user();
reset role;
do $$ begin
 if exists(select 1 from auth.users where id='f0000000-0000-4000-8000-000000000001') then raise exception 'Transferred user account still exists'; end if;
 if not exists(select 1 from public.group_members where id='f0000000-0000-4000-8000-000000000012' and role='host') then raise exception 'New host missing'; end if;
 if not exists(select 1 from public.meetups where id='f0000000-0000-4000-8000-000000000020') then raise exception 'Other members records lost'; end if;
 if has_function_privilege('anon','public.delete_user()','execute') then raise exception 'Anonymous account deletion exposed'; end if;
end $$;
rollback;
