# 앱 기능 보완 작업

<!-- === 수정한 내용: 기능 보완 이후 작은 구조 분리와 최신 테스트 결과 문서로 연결한다 === -->
이후 코드 구조 정리 및 최신 전체 테스트 73개 결과는 [refactoring.md](refactoring.md)를 확인합니다.

<!-- === 수정한 내용: 실제 구현 범위, 검증 결과와 필요한 외부 작업을 구분한다 === -->
2026-10-06. 기존 DB 초기화/C1/H7 적용 완료는 사용자 확인에 따른 기록입니다.
실제 Supabase 설정은 직접 검증하지 않았습니다. 좋아요 구현은 제외했고,
iOS 실기기 검증은 기기가 없어 보류했습니다. 기존 C1/C2 및 H1~H7 수정은 유지했습니다.

## 이번 구현

| 기능 | 변경과 이유 | 주요 파일 |
| --- | --- | --- |
| 사진 저장 | 권한 확인, HTTPS·10MB·30초 다운로드 제한, 실제 갤러리 저장 완료 후 성공 안내, 중복 탭과 dispose 대응 | lib/services/photo_saver.dart, lib/screens/group/photo_viewer_screen.dart |
| 넓은 화면 메뉴 | 요청대로 홈·내 모임·마이페이지 연결. 기존 하단 탭과 선택 상태 및 화면 데이터 공유 | lib/screens/main_skeleton.dart |
| Android 사진 선택 복구 | 시작 시 retrieveLostData, 같은 계정·편집 대상에서 1일 이내 사진을 동의 후 복구, 다른 작업을 시작해도 기존 복구 대상 보존 | lib/services/image_selection_recovery.dart, lib/main.dart, 사진 선택 화면/시트 |
| 대규모 기록 | 추가 RPC가 있는 DB는 서버 통계와 첫 40개 기록만 조회, 페이지 실패 재시도·중복 ID 제거·새로고침/폐기 후 늦은 응답 무시 | lib/repositories/group_repository.dart, lib/screens/group/group_detail_screen.dart |
| 사진과 기록 연결 | 앨범에서 다음 사진으로 넘기면 해당 사진의 기록 조회 | lib/screens/group/photo_viewer_screen.dart |
| 제한된 RLS와 초대 호환 | 초대 이름 전용 RPC 지원, 함수가 없는 기존 DB만 기존 조회 사용, 권한·네트워크·응답 오류 우회 금지 | lib/repositories/group_repository.dart |

새 플러그인은 gal 2.3.3입니다. image_picker는 선택 기능이므로 갤러리 쓰기를 위해
추가했습니다. http와 shared_preferences는 기존 간접 의존성을 직접 의존성으로
선언했습니다. Android INTERNET 및 Android 29 이하 쓰기 권한, iOS 사진 추가 권한
설명을 추가했습니다. 기존 로그인 SDK·Provider·디자인은 유지했습니다.

사진 복구는 같은 작업으로 돌아가 사진 선택을 누르면 제공됩니다. 작성 중인 텍스트나
전체 폼 자동 복원은 아닙니다. OS가 임시 파일을 삭제하면 다시 선택해야 합니다.
페이지 사이에 다른 사용자가 기록을 추가·삭제하면 offset 조회 결과가 달라질 수 있으므로
새로고침이 필요합니다. 화면 중복 ID는 제거하며 자동 쓰기 재시도는 없습니다.
추가 SQL이 없는 DB는 기존 전체 기록 조회를 유지합니다.

## 검증

- flutter test --no-pub: 전체 64개 통과. 인증·초대·계정 전환·늦은 요청·토큰 갱신·기존 저장/삭제,
  갤러리 실패/거부/크기 제한/중복 탭/dispose, 복구 격리·재시작·만료,
  메뉴 동기화·폭 변경, 페이지 실패·재시도·새로고침 경합, 사진별 기록 연결.
- flutter analyze --no-pub: 오류 0, 경고 0, info 29개. 종료 코드 1이므로 clean analyze로 보고하지 않습니다.
- Android debug APK 빌드 성공: build/app/outputs/flutter-apk/app-debug.apk.
- 로컬 fake/HTTP 테스트는 실제 Google 로그인·Supabase 정책·실제 갤러리 파일 생성·Android OS 프로세스 종료 검증을 대신하지 않습니다.
- Windows 환경으로 iOS 빌드/실기기 검증 불가. 새 SQL도 PostgreSQL에서 실행하지 않았습니다.

## 외부/SQL 작업 — 아직 실행하지 않음

1. supabase/check_current_configuration.sql: 읽기 전용 정책·함수 권한·Storage owner_id 확인. 실제 설정은 `Cannot verify from repository; check external configuration.`
2. supabase/migrations/20261006010000_group_summary.sql: 소속 확인 후 서버 참석 통계와 공개 생일 응답. staging에서 먼저 적용/검증합니다.
3. supabase/migrations/20261006020000_access_policies.sql: 데이터 보존용 **검토 초안**. summary 적용이 선행되어야 합니다. 본인 users, 소속 읽기/기록 수정, 방장 관리, 참석자 소속, 업로더 파일 조작을 제한합니다. H7 함수는 검증된 본문 전체를 SECURITY DEFINER로 교체하고 auth.uid 검증을 유지합니다. 알 수 없는 정책·Storage 스키마·교차 모임 참석 데이터가 있으면 전체 트랜잭션을 중단합니다. 테이블이나 실제 파일 삭제는 없습니다.
4. 서로 다른 두 계정으로 모임 생성/재시도·가입/초대·기록 CRUD·프로필·방장 승격/강등/내보내기·탈퇴·업로드/실패 정리·delete_user RPC를 검증합니다. 관리자/서비스 회원 변경도 새 trigger와 충돌할 수 있으므로 확인합니다. 마지막 방장 탈퇴 제한은 이번 패치에 추가하지 않았습니다.
5. 공개 bucket은 기존 URL 동작을 유지합니다. 비공개 사진에는 signed URL 및 서버 소속 확인 설계가 별도로 필요합니다. 서버 10MB/MIME 제한도 확인합니다. owner_id가 없는 과거 파일은 관리자가 처리해야 합니다.
6. 미참조 파일 자동 정리는 구현/실행하지 않았습니다. 공유 참조·저장 중 요청·응답 유실 때문에 서버에서 전체 참조, 보존 기간, 삭제 직전 재검증 후 Storage API로 처리해야 합니다. SQL로 storage.objects만 삭제하지 않습니다.
7. delete_user 권한/삭제 범위, OAuth/Google 설정, Cloudflare Worker 환경변수는 외부 확인이 필요합니다. 기존 DB 초기화 SQL은 다시 실행하지 않습니다.

실기기 확인 순서: Google 로그인 → 계정 전환/재시작 → 갤러리 권한 거부/허용 및
실제 저장 파일 확인 → Android 사진 선택 중 OS 종료 후 같은 작업 복구 → 초대/기록 CRUD.
