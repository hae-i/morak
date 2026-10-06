-- === 수정한 내용: 전체 기록을 앱에 전송하지 않고 서버에서 참석 통계를 계산하는 조회 RPC를 추가한다 ===
-- 데이터 보존용 추가 SQL입니다. DB에 실행하지 않았습니다. 초기화 스크립트를 다시 실행하지 마세요.
begin;
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
commit;
