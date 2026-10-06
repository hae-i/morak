<!-- === 수정한 내용: 부방장·탈퇴 이력·작성자 관리의 변경 파일과 SQL/실기기 검증 순서를 정리한다 === -->
# 2026-10-07 작업 기록

사용자 확정: 관리자 권한 변경은 방장만 가능. 현재 테스트 기록이 없으므로 기존 글에 작성자를 임의 배정하지 않는다.
이전 사진 비공개/위임/탈퇴/계정 전환은 사용자가 실기기 성공을 보고했다. 새 기능의 실제 DB/로그인 검증은 별도로 필요하다.

## 앱 변경

- `lib/main.dart`, `lib/router.dart`, `lib/screens/auth/login_screen.dart`: 로그인·로그아웃 후 안내와 180ms 페이드. 같은 사용자 토큰 갱신은 현재 화면 유지. 이전 계정 응답과 폐기한 인증 구독 차단 유지.
- `lib/screens/main_skeleton.dart`: 기본 하단 탭 선택/비선택 크기 차이를 없애고 12px, w600으로 고정. 별도 폰트 패키지/폰트 파일은 추가하지 않았다.
- `lib/models/member_model.dart`: 비활성 멤버를 현재 권한에서 제외하고 과거 참석 ID 유지. 탈퇴 이름·사진·생일 표시 익명화.
- `lib/models/meetup_model.dart`: 작성자 표시, 활성 작성자만 수정, 작성자/관리자 삭제, 탈퇴/미상 작성자 글은 관리자 수정.
- `lib/repositories/group_repository.dart`, `lib/repositories/meetup_repository.dart`: 활성 멤버십 조회, 가입/내보내기 RPC, 삭제/역할 변경이 RLS로 0건 차단되면 실패 처리. C1 원자적 기록 저장 API 유지.
- `lib/screens/group/group_info_screen.dart`: 일반 멤버는 수정/삭제 숨김, 부방장은 수정만, 방장은 둘 다. 늦은 이전 계정 권한 조회 적용 차단.
- `lib/widgets/group/member_drawer.dart`, `member_manage_sheet.dart`: 방장만 위임·부방장 임명/해제·관리자 강등. 부방장은 일반 멤버 내보내기. 탈퇴 멤버는 현재 목록에서 제외.
- `lib/widgets/group/group_card.dart`, `member_profile_sheet.dart`: 부방장 역할 표시.
- `lib/screens/group/group_detail_screen.dart`, `meetup_detail_screen.dart`, `lib/widgets/feed/feed_card.dart`: 작성자 표시, 상세 작업 권한별 메뉴.
- `lib/screens/group/meetup_create_screen.dart`: 신규 참석자는 활성 멤버, 기존에 체크된 탈퇴 참석자의 ID는 편집 시 유지.
- `lib/screens/profile/my_page_screen.dart`: 계정 삭제 후 모임의 익명화된 기록이 남는다는 안내.

## 서버 변경

추가 SQL: `supabase/migrations/20261007000000_membership_history_and_authors.sql`.
**실행하지 않았다. 이전 `apply_private_photos_and_host_rules.sql`이 적용된 DB를 전제로 한다.**

- 기존 데이터/테이블 초기화 없음. `is_deleted`, `left_at` 추가. 역할에 `deputy` 추가.
- 모임 탈퇴/내보내기는 행을 지우지 않고 이름을 익명화하고 개인 사진·소개·생일 공개를 제거한다.
- 계정 삭제 시 `group_members.user_id` FK를 CASCADE에서 SET NULL로 변경하여 참석 기록을 보존한다.
- 단순 모임 탈퇴는 재가입 식별을 위해 내부 `user_id`를 유지한다. 계정 삭제는 참조를 NULL로 끊는다.
- 같은 계정 재가입은 같은 멤버 ID로 일반 멤버로 복구한다. 예전 관리자 권한은 자동 복구하지 않는다. 작성자 표시/본인 수정 권한은 재가입 시 복구된다.
- 작성자 ID/표시 이름/탈퇴 상태를 서버가 저장한다. 클라이언트가 보낸 작성자 ID는 생성 트리거에서 인증 사용자로 덮어쓴다.
- 그룹 수정은 방장/부방장, 그룹 삭제와 관리자 역할 변경은 방장만. 부방장은 다른 관리자 내보내기 불가.
- 작성자/관리자 정책을 기록·참석 변경에 함께 적용하여 참석 API로 글 변경 권한을 우회할 수 없게 한다.
- 사진/조회 함수에서 비활성 멤버 제외. `get_group_summary`도 동일하게 수정한다.
- 알 수 없는 정책/역할 제약/FK가 있으면 중단하고 전체 트랜잭션을 취소한다.
- 이미 과거 CASCADE로 삭제된 참석 기록은 이 SQL로 복구할 수 없다. 예상 밖의 기존 작성자 없는 글은 ‘작성자 미상’, 방장/부방장 관리로 남는다.

## 검증

- Flutter 전체 테스트 103개 통과: 인증/늦은 요청/토큰 갱신/구독 폐기, 기존 사진 처리, 역할별 화면, 작성자 모델, 0건 변경 거부, 기존 C1 등.
- `flutter analyze --no-pub`: 오류 0, 경고 0, 기존 info 29개. info 때문에 종료코드 1이며 분석 전체가 무지적 통과한 것은 아니다.
- Android `flutter build apk --debug --no-pub` 성공. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` 통과.
- SQL 통합 테스트 `supabase/tests/membership_history_and_authors_test.sql`: 테스트 계정/모임을 만들고 마지막 ROLLBACK. 실제 DB에서는 미실행.
- 읽기 전용 설정 확인: `supabase/verify_membership_history_and_authors.sql`. 개인정보 값 출력 없음.
- 실제 Google 로그인/Android 기기 동작, 두 DB 세션의 동시 요청, iOS 기기 테스트는 미실행.

## 사용자 확인 및 외부 작업

1. 기존 데이터 보존 상태에서 새 migration 전체를 테스트 Supabase에 적용한다. 초기화 SQL이나 이전 정책 통합본을 다시 실행하지 않는다.
2. 테스트 전용 SQL 통합 테스트 전체 실행 → 읽기 전용 확인 SQL 실행. 테스트 스크립트 중간에서 멈추면 세션에 ROLLBACK을 실행한다.
3. 설정 확인에서 invalid administrator/host 없음/작성자 불일치/타모임 참석은 0. client_member_delete/client_status_update/client_author_update는 false. 새 RPC anon_execute는 false, authenticated_execute는 true.
4. 다른 역할의 실제 계정으로 부방장 임명/해제, 수정/삭제 차이, 타인의 활성 글 수정 차단, 탈퇴 글 관리, 탈퇴 후 참석/작성 기록 유지, 재가입, 부방장 계정 탈퇴를 확인한다.
5. 실제 로그인/로그아웃 안내와 하단 탭 폰트를 Fold 기기에서 확인한다. 토큰 갱신 중 현재 편집 화면 유지도 확인한다.
6. 동시 요청: 두 SQL 세션에서 위임/탈퇴·역할 변경, 글 생성/탈퇴를 각각 BEGIN 상태로 진행하고 잠금 대기·커밋 후 결과를 확인한다.
7. 사진 공개 접근 테스트: DB의 photos/프로필/커버 컬럼에 있는 기존 `/storage/v1/object/public/...` 주소를 로그아웃 브라우저에서 연다. 사진이 표시되지 않아야 한다. Dashboard의 인증된 미리보기나 서명 URL은 공개 접근 테스트가 아니다. 앱에 공개 링크 버튼을 추가할 필요는 없다.
8. 검증 후 실제 사용 DB에 같은 migration 적용하고 새 앱을 실행한다. 새 앱은 새 컬럼/RPC가 필요하므로 SQL 적용 전에는 실행하지 않는다.

이번 작업을 위한 새 패키지·Cloudflare 설정·OAuth 설정 변경은 없다. 기존 50MB 전역 제한과 사진 비공개 bucket 설정을 유지한다.
