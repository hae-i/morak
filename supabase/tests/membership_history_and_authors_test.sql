-- === 수정한 내용: 실제 RLS 역할로 부방장 제한·작성자 권한·탈퇴/계정삭제 이력 보존을 검증한다 ===
-- 별도 테스트 Supabase에서 새 migration 적용 후 전체 실행. 마지막 ROLLBACK으로 fixture 제거.
begin;
do $$ begin
 if exists(select 1 from auth.users where id::text like 'e7000000-%') then raise exception 'Fixture IDs already exist'; end if;
end $$;
insert into auth.users(id,email) values
 ('e7000000-0000-4000-8000-000000000001','host@morak-test.invalid'),
 ('e7000000-0000-4000-8000-000000000002','deputy@morak-test.invalid'),
 ('e7000000-0000-4000-8000-000000000003','writer@morak-test.invalid'),
 ('e7000000-0000-4000-8000-000000000004','reader@morak-test.invalid');
insert into public.users(id,display_name) values
 ('e7000000-0000-4000-8000-000000000001','Host'),('e7000000-0000-4000-8000-000000000002','Deputy'),
 ('e7000000-0000-4000-8000-000000000003','Writer'),('e7000000-0000-4000-8000-000000000004','Reader');
insert into public.groups(id,name) values('e7000000-0000-4000-8000-000000000010','History test');
insert into public.group_members(id,group_id,user_id,display_name,role) values
 ('e7000000-0000-4000-8000-000000000011','e7000000-0000-4000-8000-000000000010','e7000000-0000-4000-8000-000000000001','Host','host'),
 ('e7000000-0000-4000-8000-000000000012','e7000000-0000-4000-8000-000000000010','e7000000-0000-4000-8000-000000000002','Deputy','deputy'),
 ('e7000000-0000-4000-8000-000000000013','e7000000-0000-4000-8000-000000000010','e7000000-0000-4000-8000-000000000003','Writer','member'),
 ('e7000000-0000-4000-8000-000000000014','e7000000-0000-4000-8000-000000000010','e7000000-0000-4000-8000-000000000004','Reader','member');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000003',true);
set local role authenticated;
-- 클라이언트가 작성자를 위조해도 서버가 인증된 Writer로 덮어써야 합니다.
insert into public.meetups(id,group_id,title,meet_date,author_member_id,author_name) values
 ('e7000000-0000-4000-8000-000000000020','e7000000-0000-4000-8000-000000000010','Original',now(),
 'e7000000-0000-4000-8000-000000000011','Fake host');
insert into public.attendances(meetup_id,member_id) values
 ('e7000000-0000-4000-8000-000000000020','e7000000-0000-4000-8000-000000000013');
do $$ declare n integer; begin
 if not exists(select 1 from public.meetups where id='e7000000-0000-4000-8000-000000000020'
   and author_member_id='e7000000-0000-4000-8000-000000000013' and author_name='Writer') then raise exception 'Author spoof accepted'; end if;
 update public.meetups set title='By writer' where id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>1 then raise exception 'Writer cannot edit'; end if;
 begin update public.meetups set author_name='Forged' where id='e7000000-0000-4000-8000-000000000020';
   raise exception 'Author metadata mutable'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000002',true);
do $$ declare n integer; begin
 update public.groups set name='Deputy edit' where id='e7000000-0000-4000-8000-000000000010';
 get diagnostics n=row_count; if n<>1 then raise exception 'Deputy cannot edit group'; end if;
 delete from public.groups where id='e7000000-0000-4000-8000-000000000010';
 get diagnostics n=row_count; if n<>0 then raise exception 'Deputy deleted group'; end if;
 update public.meetups set title='Illegal deputy edit' where id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>0 then raise exception 'Deputy edited active author post'; end if;
 if not public.morak_can_delete_meetup('e7000000-0000-4000-8000-000000000020') then raise exception 'Deputy cannot delete'; end if;
 begin update public.group_members set role='host' where id='e7000000-0000-4000-8000-000000000012';
   raise exception 'Deputy self-promoted'; exception when insufficient_privilege then null; end;
 begin perform public.transfer_group_host('e7000000-0000-4000-8000-000000000010','e7000000-0000-4000-8000-000000000012');
   raise exception 'Deputy transferred host'; exception when insufficient_privilege then null; end;
 begin perform public.remove_group_member('e7000000-0000-4000-8000-000000000011');
   raise exception 'Deputy removed host'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000001',true);
do $$ declare n integer; begin
 update public.meetups set title='Illegal host edit' where id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>0 then raise exception 'Host edited active author post'; end if;
 update public.group_members set role='member' where id='e7000000-0000-4000-8000-000000000012';
 update public.group_members set role='deputy' where id='e7000000-0000-4000-8000-000000000012';
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000004',true);
do $$ declare n integer; begin
 delete from public.meetups where id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>0 then raise exception 'Reader deleted post'; end if;
 delete from public.attendances where meetup_id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>0 then raise exception 'Reader changed attendance'; end if;
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000003',true);
select public.leave_group('e7000000-0000-4000-8000-000000000010');
do $$ begin
 if public.morak_is_member('e7000000-0000-4000-8000-000000000010') then raise exception 'Former member still authorized'; end if;
 begin perform public.get_group_summary('e7000000-0000-4000-8000-000000000010');
   raise exception 'Former member read summary'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000002',true);
select public.remove_group_member('e7000000-0000-4000-8000-000000000014');
do $$ declare n integer; begin
 if not exists(select 1 from public.group_members where id='e7000000-0000-4000-8000-000000000014'
   and is_deleted) then raise exception 'Deputy cannot remove ordinary member'; end if;
 if not exists(select 1 from public.attendances where member_id='e7000000-0000-4000-8000-000000000013') then raise exception 'Attendance lost'; end if;
 if not exists(select 1 from public.meetups where id='e7000000-0000-4000-8000-000000000020'
   and author_deleted and author_name='탈퇴한 멤버') then raise exception 'Author not anonymized'; end if;
 update public.meetups set title='Deputy manages departed post' where id='e7000000-0000-4000-8000-000000000020';
 get diagnostics n=row_count; if n<>1 then raise exception 'Deputy cannot edit departed post'; end if;
end $$;
-- C1 원자적 저장도 탈퇴 멤버의 기존 참석 ID를 그대로 보존할 수 있어야 합니다.
select public.save_meetup_atomic(
 jsonb_build_object('group_id','e7000000-0000-4000-8000-000000000010',
   'title','Atomic departed post edit','meet_date',now(),'photos',jsonb_build_array()),
 jsonb_build_array('e7000000-0000-4000-8000-000000000013'),
 'e7000000-0000-4000-8000-000000000020');
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000003',true);
do $$ declare v_id uuid; begin
 v_id:=public.join_group('e7000000-0000-4000-8000-000000000010','Rejoined',null,false);
 if v_id<>'e7000000-0000-4000-8000-000000000013' then raise exception 'Rejoin lost membership identity'; end if;
 if not exists(select 1 from public.meetups where id='e7000000-0000-4000-8000-000000000020'
   and not author_deleted and author_name='Rejoined') then raise exception 'Author not restored'; end if;
end $$;
-- 계정 삭제는 직접 나가지 않은 멤버도 익명화하고 기존 참석/글을 보존해야 합니다.
select public.delete_user();
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000002',true);
select public.delete_user();
reset role;
do $$ begin
 if not exists(select 1 from public.group_members where id='e7000000-0000-4000-8000-000000000013'
   and user_id is null and is_deleted and display_name='탈퇴한 멤버') then raise exception 'Account tombstone missing'; end if;
 if not exists(select 1 from public.group_members where id='e7000000-0000-4000-8000-000000000012'
   and user_id is null and is_deleted and role='member') then raise exception 'Deleted deputy not anonymized'; end if;
 if not exists(select 1 from public.attendances where member_id='e7000000-0000-4000-8000-000000000013') then raise exception 'Account delete lost attendance'; end if;
 if not exists(select 1 from public.meetups where id='e7000000-0000-4000-8000-000000000020' and author_deleted) then raise exception 'Account delete lost post'; end if;
end $$;
select set_config('request.jwt.claim.sub','e7000000-0000-4000-8000-000000000001',true);
set local role authenticated;
-- 클라이언트가 사용하는 DELETE RETURNING도 실제 삭제 행을 반환해야 합니다.
do $$ declare v_id uuid; begin
 delete from public.meetups where id='e7000000-0000-4000-8000-000000000020' returning id into v_id;
 if v_id is null then raise exception 'Host post delete returned no row'; end if;
 -- 기록이 남아 있는 모임 삭제는 작성자 FK와 멤버/참석 CASCADE에도 막히지 않아야 합니다.
 insert into public.meetups(id,group_id,meet_date) values
   ('e7000000-0000-4000-8000-000000000021','e7000000-0000-4000-8000-000000000010',now());
 delete from public.groups where id='e7000000-0000-4000-8000-000000000010' returning id into v_id;
 if v_id is null then raise exception 'Host group delete returned no row'; end if;
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.meetups where id='e7000000-0000-4000-8000-000000000021')
   or exists(select 1 from public.group_members where group_id='e7000000-0000-4000-8000-000000000010') then
   raise exception 'Group cascade incomplete';
 end if;
end $$;
rollback;
