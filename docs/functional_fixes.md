# 기능 안정화 변경 기록

<!-- === 수정한 내용: 이후 기능 구현과 사용자 DB 적용 상태는 최신 작업 문서로 연결한다 === -->
이 문서는 이전 High 수정 시점의 기록입니다. DB 적용 완료, 좋아요 제외 및 이후 사진 저장·메뉴·복구·페이지 조회 작업은 [app_completion.md](app_completion.md)를 확인합니다.

<!-- === 수정한 내용: 수정 파일, 검증 범위와 외부 작업을 한곳에 기록한다 === -->
## High 수정

| 항목 | 변경과 이유 | 주요 파일 |
| --- | --- | --- |
| H1 | 계정 전환 시 피드 초기화, 이전 요청 결과·실패 무시 | lib/providers/home_provider.dart, lib/main.dart |
| H2 | 같은 사용자 tokenRefreshed는 화면 유지, 프로필 조회 경합 방지, 구독 dispose | lib/main.dart, lib/screens/splash_screen.dart |
| H3 | 기존 기록 즉시 보관, 멤버 조회 실패 시 저장 차단·재시도 | lib/screens/group/meetup_create_screen.dart |
| H4 | iOS OAuth client ID와 callback scheme을 빌드 변수로 연결 | ios/Runner/Info.plist, ios/Flutter/*.xcconfig |
| H5 | 테마 선택 반환을 ProfileSetupResult로 받아 강제 형변환 크래시 방지 | lib/widgets/group/group_edit_sheets.dart |
| H6 | 생일 공개 선택을 가입 DB 요청까지 전달 | lib/widgets/group/group_join_sheet.dart, lib/repositories/group_repository.dart |
| H7 | 그룹/최초 방장 단일 RPC, 같은 화면의 재시도는 같은 UUID 사용 | lib/repositories/group_repository.dart, lib/screens/group/group_create_screen.dart, supabase/migrations/20261006000000_create_group_atomic.sql |

H8 Android release 서명은 배포 전용으로 제외했습니다. 기존 C1/C2를 유지했습니다.
H4 실제 발급값·기기 로그인과 H7 SQL 적용은 외부에서 완료해야 합니다.

## 권장사항 반영

- 피드 중복 요청 잠금, 성공 시에만 offset 확정, 실패한 페이지의 재시도.
- 프로필/그룹/초대 조회 오류·누락은 무한 spinner 대신 재시도, 불완전한 저장 차단.
- 전역·모임 프로필 사진 삭제는 null 저장, 이름만 바꾸면 HEX 색상 보존.
- 기록 제목 표시·실제 삭제, 편집 후 상세 재조회와 상위 목록·피드 갱신.
- 로그인 전 내부 초대 목적지 유지, 가입 성공 결과로 상세 이동.
- 파일 고유 경로, 헤더 기반 MIME·10MB 검증, 확정 DB 실패와 후속 업로드 실패 시
  이번 요청의 새 파일만 정리. 저장 여부 불명확한 통신 실패는 사진 보존.
- 조회 20초, 주요 저장·업로드 30초 제한. timeout은 서버 작업을 취소하지 않아
  변경 요청을 자동 반복하지 않습니다.
- 정확한 count와 실제 반환 행 수를 사용한 페이지 조회로 서버 row cap 누락 방지.
- 비동기 picker·날짜·부모 콜백 mounted 확인, 탭별 계정 전환 데이터 초기화.
- 내부 예외 원문 비노출, 빈 이름과 잘못된 권한 입력 검증.
- 기본 카운터 테스트를 실제 앱·SDK HTTP 계약 테스트로 교체, 새 패키지 없음.

공통 처리는 lib/utils/storage_uploads.dart, paged_query.dart, data_refresh.dart,
operation_id.dart와 lib/widgets/common/request_error_view.dart에 좁게 분리했습니다.
UI 디자인을 재작성하거나 기존 사용자 이미지/아이콘을 변경하지 않았습니다.
사용 여부가 불명확한 패키지도 임의 삭제하지 않았습니다.
좋아요, 메뉴 사이드바, 실제 기기 사진 저장은 기존 미구현 기능으로 남아 있습니다.
사진 저장 버튼의 허위 성공 안내는 준비 중 안내로 바로잡았습니다. 해당 기능 구현은
High 수정과 별개의 기능 작업이며 완료했다고 보고하지 않습니다.

주요 추가 수정 파일은 lib/screens/profile/{my_page_screen,profile_edit_screen,profile_setup_screen}.dart,
lib/screens/group/{my_group_screen,group_detail_screen,group_info_screen,meetup_detail_screen,photo_viewer_screen}.dart,
lib/screens/home/home_screen.dart, lib/router.dart와 lib/widgets/group/member_drawer.dart입니다.

## 검증 범위

test/auth: 계정 전환·늦은 요청·토큰 갱신·Splash·dispose·초대.
test/screens: 기록 편집·삭제·테마·프로필 조회 실패.
test/repositories: 실제 SDK 로컬 HTTP 계약·파일 정리·페이지 cap.
로컬 RPC 계약 테스트는 PostgreSQL transaction 검증을 의미하지 않습니다.
두 SQL 통합 테스트는 빈 임시 PostgreSQL DB 전용이고 아직 실행하지 않았습니다.
Windows 환경이므로 Xcode 빌드와 실제 iOS Google 로그인도 미검증입니다.
2026-10-06 검증: 전체 Flutter 테스트 37개 통과, 마지막 안내 수정 뒤 관련 화면 테스트
4개 재통과. flutter analyze --no-pub는 오류 0·경고 0·info 27개로 종료 코드 1입니다.
deprecated API와 기존 스타일 지적이 남아 있어 완전한 clean analyze로 보고하지 않습니다.
Info.plist XML 파싱과 git diff --check도 통과했습니다.

## 외부/SQL 작업

1. 제공 SQL의 DROP TABLE CASCADE는 데이터 삭제를 초래합니다. 다시 실행하지 말고
   실제 schema/default/FK/trigger/RLS부터 조회합니다.
2. save_meetup_atomic과 create_group_atomic을 staging DB에서 검증한 뒤 적용합니다.
   새 클라이언트는 RPC가 없으면 실패를 표시하고 직접 쓰기로 우회하지 않습니다.
   SQL 통합 테스트는 운영 DB에서 실행하지 않습니다.
3. 기존 groups/group_members/meetups/attendances의 FOR ALL USING(true)는
   타 계정의 변경도 허용합니다. 멤버·방장·본인·참석자 소속을 서버 정책으로 제한하고,
   그룹 최초 host 등록과 retry SELECT 권한을 확인합니다. SECURITY INVOKER는 RLS를 우회하지 않습니다.
4. users(birthday)는 checkbox만으로 접근이 제한되지 않습니다. 생일 비공개를
   보장하려면 view/RPC/column 권한 등 서버 설계가 필요합니다.
5. 공개 Storage bucket과 authenticated 전체 조작 정책을 검토하고 신규 고유 경로의
   소유권·모임 권한·삭제 권한·10MB/MIME 서버 검증·공개 URL 사용 여부를 결정합니다.
6. 공유 프로필·삭제된 기록·응답 유실 후 남은 파일은 참조와 보존 기간을 확인하는
   서버 GC로 정리합니다. 기존 URL을 무조건 삭제하면 다른 참조를 손상시킵니다.
7. delete_user RPC의 auth.uid 권한, auth 계정 삭제와 cascade 범위를 확인합니다.
8. 실제 iOS OAuth client/reversed ID·Bundle ID, Android Google 로그인,
   Supabase redirect allowlist와 도메인·딥링크를 실기기로 확인합니다.
   Cloudflare Dashboard/Worker secret은 저장소에서 확인 불가입니다.
9. 큰 기록·앨범의 서버 통계 RPC·앨범 지연 조회는 추가 설계가 필요합니다.
   현재는 row cap 누락을 해결했지만 전체 통계/앨범 메모리 구조를 유지했습니다.
   Android 사진 선택 중 프로세스 종료의 선택 복원도 기기에서 추가 검증합니다.
