-- === 수정한 내용: 그룹과 최초 방장을 하나의 트랜잭션으로 생성하고 같은 요청의 재시도를 중복 저장하지 않는다 ===
-- 검토용 파일이며 실제 DB에는 실행하지 않았습니다.
create function public.create_group_atomic(
  p_group_id uuid,
  p_group jsonb,
  p_member jsonb
)
returns jsonb
language plpgsql
security invoker
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
