-- === 수정한 내용: 기존 본인 탈퇴 RPC를 유지하면서 익명 실행과 인증 없는 호출을 차단한다 ===
-- 검토 초안입니다. 실제 DB에서 실행하지 않았습니다.
-- 전체 테이블 초기화나 저장 파일 삭제는 하지 않습니다.
-- 기존 FK cascade 삭제 범위는 그대로 유지합니다. 마지막 방장 처리/파일 정리는 별도 설계입니다.
begin;

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;
commit;

-- 적용 후 읽기 전용 확인: anon=false, authenticated=true가 기대값입니다.
-- select has_function_privilege('anon','public.delete_user()','EXECUTE') as anon_can_execute,
--   has_function_privilege('authenticated','public.delete_user()','EXECUTE') as authenticated_can_execute;
-- 실제 삭제 테스트는 별도 테스트 계정만 사용하고 다른 계정/모임 데이터 영향도 확인합니다.
