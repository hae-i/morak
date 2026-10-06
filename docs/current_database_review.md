# 실제 DB 설정 검토

<!-- === 수정한 내용: 사용자 제공 실제 DB 결과와 미확인 부분을 구분한다 === -->
2026-10-06 사용자 제공 SQL 조회 결과 기준. 직접 DB에 접속하거나 변경하지 않았습니다.

- 앱 5개 테이블의 RLS는 활성화되어 있습니다. FORCE가 false라는 사실만으로 취약점이 되지는 않습니다.
- 모임/멤버/기록/출석은 authenticated ALL true이므로 소속별 제한이 없습니다.
- users 전체 SELECT 정책은 다른 사용자 생일 조회도 제한하지 않습니다.
- Storage는 공개 bucket 3개, 조작 정책에 업로더 소유권 확인이 없습니다.
- bucket별 크기/MIME 제한은 null입니다. 전역 크기 제한은 이 결과로 확인 불가합니다.
- owner_id는 text로 권한 패치 사전 조건과 일치합니다. 교차 모임 참석은 0개입니다.
- create_group_atomic과 save_meetup_atomic은 INVOKER/빈 search_path/authenticated 실행 권한입니다.
- 조회 결과에 추가 통계/초대 이름 RPC가 없으므로 추가 SQL 적용 전입니다.
- delete_user는 DEFINER/postgres 소유이며 auth.users에서 auth.uid()와 일치하는 행만 삭제합니다.
  익명 UID가 null인 경우 삭제 대상이 없어 타인 삭제 우회는 이 본문에서 보이지 않습니다.
  anon 실행 권한은 true이므로 별도 SQL에서 PUBLIC/anon 권한을 제거하고 인증 없는 호출을 명시적으로 거부합니다.

## 다음 작업

추가 SQL 검토 순서: group_summary → access_policies → delete_user_permissions.
실제 PostgreSQL 실행 검증은 아직 하지 않았습니다. 각 SQL은 테스트 DB에서 먼저 검증해야 합니다.
delete_user_permissions는 Flutter RPC 이름·인수·반환형과 정상 본인 탈퇴 동작을 유지합니다.
실제 FK/추가 trigger 정의는 아직 제공되지 않아 최종 삭제 범위는 확인이 필요합니다.
저장소 초기화 schema 기준으로는 프로필/회원/회원 출석이 cascade 삭제되지만 모임과 기록은 남을 수 있습니다.
마지막 방장 탈퇴 시 방장 없는 모임, Storage 잔여 파일 문제는 이번 권한 SQL에 포함하지 않았습니다.
OAuth/Cloudflare 설정과 실제 로그인·파일 저장·계정 삭제는 추가 외부 검증이 필요합니다.

이번에는 SQL 초안과 기록만 추가했으며 Flutter 코드를 수정하거나 리팩토링하지 않았습니다.
