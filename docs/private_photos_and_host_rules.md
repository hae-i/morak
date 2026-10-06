# 화면 수정과 사진·방장 정책

<!-- === 수정한 내용: 앱에서 완료한 변경과 실제 DB에서 아직 실행하지 않은 작업을 구분한다 === -->
2026-10-06.

## 화면과 터치

- 사이드바 하단 왼쪽 빨간 나가기, 오른쪽 공유·설정 아이콘. 기존 공유는 초대 링크 복사입니다.
- 나가기 확인 후 본인 탈퇴 RPC를 호출합니다. 방장은 먼저 위임하도록 안내합니다.
- 넓은 화면 상단바 복원. 메뉴 버튼으로 사이드바 열기/닫기, 좁은 화면은 endDrawer입니다.
- 계정 정보는 볼드 항목명 아래 값만 입력창 모양으로 표시합니다. 실제 편집 입력창은 아닙니다.
- 계정 이름은 표시하지 않으며 AccountInfo에서 이름 metadata를 읽지 않습니다.
- 기존 화면의 글자 크기·굵기·색상을 적용했습니다. pubspec에 별도 폰트 asset은 등록되어 있지 않습니다.
- ThemeData.splashFactory=NoSplash로 물결 효과를 전역 제거했습니다. 기존 공통 버튼의 누르는 색상 반응은 유지합니다.
- Google 로그인 자체는 변경하지 않았습니다. Google ID token/OAuth가 Supabase Auth에 전달하는 이름은 프런트 모델 제거와 별개입니다.
  앱 public.users에는 닉네임(display_name)을 직접 입력받아 저장하고 Google 실명을 복사하지 않습니다.
  Auth metadata의 이름 저장까지 막는 것은 현재 공급자/서버 동작을 추가 검토해야 하며 이번 변경으로 수집 차단을 보장하지 않습니다.

## 인증 사진 조회

- lib/services/private_photos.dart의 StoragePhotoRef는 현재 프로젝트의 공개 URL을 bucket/path 식별자로 파싱합니다.
- 기존 DB 컬럼과 공개 URL 문자열은 유지합니다. 공개 다운로드 대신 Supabase SDK downloadStream으로 현재 세션을 전달합니다.
- UI와 갤러리 저장 모두 인증 조회로 교체했습니다. 로컬 웹 미리보기/다른 출처 이미지에는 인증 정보를 전달하지 않습니다.
- 10MB 및 전체 30초 제한. 실패하면 공개 URL로 우회하지 않습니다.
- 사진은 Flutter 메모리 캐시만 사용하고 새 인증 사진의 디스크 캐시는 만들지 않습니다.
- 계정 변경/로그아웃/탈퇴는 권한 세대를 바꿔 늦은 다운로드와 디코드 응답을 거절합니다. 같은 사용자 토큰 갱신은 현재 화면·사진 캐시를 유지합니다.
- 이미 사용자가 다운로드/캡처한 파일을 탈퇴 시 회수할 수는 없습니다. 서버 정책은 이후 다운로드를 제한합니다.

## 방장 정책

- transfer_group_host RPC는 현재 방장 확인 → 대상 실제 계정 멤버 승급 → 본인 일반 멤버로 변경을 하나의 트랜잭션으로 처리합니다.
- 기존 멤버 관리의 승급 메뉴를 방장 위임으로 변경했습니다. 기존 복수 방장 데이터는 자동 변경하지 않습니다.
- leave_group은 본인만 삭제하며 방장 상태에서는 거절합니다. 위임 완료 후 별도로 나가기를 확인합니다.
- delete_user는 방장인 모임이 하나라도 있으면 거절합니다. 다른 사람의 모임 기록은 계정 탈퇴 때문에 삭제하지 않습니다.
- 서버 trigger가 직접 DELETE/UPDATE 우회도 제한합니다. 마지막 방장 강등 금지, 실제 모임 삭제 CASCADE 허용.
- 모임 행 잠금으로 해당 모임의 위임/강등/탈퇴를 직렬화합니다. 서버 실제 동시성은 두 DB 세션으로 추가 검증해야 합니다.
- SQL 적용 전 새 탈퇴·위임 메뉴는 RPC 부재로 실패 안내를 표시합니다. 직접 쓰기로 우회하지 않습니다.

## SQL 파일과 순서

1. supabase/verify_private_photos_and_host_rules.sql: 읽기 전용. 먼저 현재 결과를 확인합니다.
   groups_without_real_host/invalid_ghost_hosts는 0이어야 합니다. missing_or_unsupported_references는 결과 행이 없어야 합니다.
   사진 참조 누락이 있으면 파일 복구/참조 정리를 별도 검토합니다. 자동 삭제/보정하지 않습니다.
2. supabase/apply_private_photos_and_host_rules.sql: 기존 데이터 보존용 추가 통합 SQL.
   summary RPC와 기존 access 초안, 새로운 사진·방장 정책을 하나의 트랜잭션으로 포함합니다.
   이전 추가 SQL 파일을 따로 반복 적용하지 않습니다. 특히 reset_and_setup.sql은 사용하지 않습니다.
   알 수 없는 정책, Storage owner_id 타입 차이, 다른 모임 출석, 예상한 CASCADE FK 부재, 사진 경로/파일 충돌, 방장 부재가 있으면 전체 취소합니다.
   profiles/group_covers/meetup_photos 비공개, 각 10MB, JPEG/PNG/WEBP/GIF를 설정합니다.
   기존 파일/테이블 행을 삭제하거나 URL을 일괄 변환하지 않습니다.
   Storage SELECT는 참조하는 모임 멤버/본인 계정 사진만 허용합니다. 저장 전 미참조 파일은 업로더의 미리보기·정리를 위해 본인 조회를 허용합니다.
   참조 중인 파일의 직접 삭제/덮어쓰기는 금지합니다. 사진 교체는 기존처럼 새 고유 파일을 업로드합니다.
   임의의 타인 사진 경로를 내 모임에 저장하는 권한 우회도 사진 참조 trigger로 제한합니다.
3. supabase/tests/private_photos_and_host_rules_test.sql: 별도 테스트 Supabase에서만 실행.
   적용 SQL 실행 후 전체 파일을 실행하면 fixture 삽입과 ACL/위임/탈퇴/삭제 검증 후 ROLLBACK합니다.
   Storage의 실제 바이트 다운로드 검증이 아닌 SQL ACL 검증입니다.
4. 테스트 프로젝트 앱에서 멤버 A/B와 비멤버 C로 업로드·조회·위임·탈퇴·계정 삭제를 확인한 뒤 실제 DB 적용합니다.
   실제 DB의 기존 정책 변경/FK/트리거는 파일만으로 확인할 수 없습니다.

## 두 세션 동시성 검증

실제 사용자 데이터가 없는 테스트 모임에서 두 개의 SQL 연결을 사용합니다.
둘 다 방장인 A/B를 만든 뒤 세션 A: BEGIN → auth claim A 설정 → 본인 role=member 변경(아직 COMMIT하지 않음).
세션 B: BEGIN → auth claim B 설정 → 본인 role=member 변경을 요청합니다.
B는 모임 잠금에서 기다려야 합니다. A COMMIT 후 B는 마지막 방장 강등 검사에서 실패해야 합니다. B ROLLBACK.
다음에는 두 세션의 위임/탈퇴와 위임/계정 삭제가 겹칠 때 방장이 사라지지 않는지 확인합니다.
SQL Editor 하나의 단일 실행만으로 이 경합 검증이 완료되는 것은 아닙니다.

## 외부 확인과 제한

- 사용자가 Global file size limit 50MB와 개인정보처리방침 링크 열림을 확인했습니다. 전역 값은 변경하지 않았습니다.
- 실제 Supabase DB 연결 도구/관리자 연결과 psql/docker 실행 환경이 없어 적용 SQL 및 DB 테스트는 실행하지 않았습니다.
- 확인 SQL의 실제 결과를 받은 뒤 테스트 프로젝트에서 검증해야 합니다. 새 앱이 정상적으로 인증 사진을 읽는 것을 확인한 후 실제 비공개 전환을 진행합니다.
- 비공개 전환 후 예전 공개 URL을 로그아웃 브라우저에서 열어 차단되는지도 확인하세요. 기존에 저장/공유한 이미지 사본은 회수할 수 없습니다.
- 개인정보처리방침 내용은 아직 초안입니다. Google Auth 메타데이터 처리와 사진 보관 정책을 문서 확정 시 반영해야 합니다.
- 미참조 사진 일괄 정리/보존 기간, iOS 실기기, Android 사진 선택 종료 복구는 이번 작업의 실행 완료 대상이 아닙니다.

## 검증 기록

- flutter test --no-pub: 최종 전체 92개 통과.
- flutter analyze --no-pub: 오류 0개, 경고 0개, info 30개. info로 종료 코드 1.
- flutter build apk --debug --no-pub: 성공. build/app/outputs/flutter-apk/app-debug.apk.
- git diff --check: 통과.
- SDK HTTP mock으로 인증 전달, 계정 변경·로그아웃·탈퇴 후 늦은 사진 응답 거부, 같은 계정 세션 갱신 유지 확인.
- 실제 위젯에서 나가기 취소/확인/목록 복귀, 방장 안내, 기존 복수 방장 위임·강등 메뉴 확인.
- 기존 Splash/Auth/토큰 갱신/피드 캐시/원자적 저장 테스트도 전체에 포함해 통과.
- 실제 Google 로그인, 실제 Storage HTTP 권한 및 SQL/DB 두 세션 동시성 테스트는 미실행입니다.

## 주요 변경 파일

- lib/main.dart: 전역 물결 제거 및 계정 변경 시 사진 캐시 제거.
- lib/models/account_info.dart, lib/screens/profile/account_info_screen.dart: 이름 제외, 기존 글자 스타일과 값 입력창 형태.
- lib/screens/profile/my_page_screen.dart: 인증 프로필 사진 및 정확한 계정 탈퇴 안내.
- lib/screens/group/group_detail_screen.dart: 넓은 상단바 복원, 확인 후 탈퇴, 정상 목록 복귀.
- lib/widgets/group/member_drawer.dart, member_manage_sheet.dart: 하단 작은 메뉴와 원자적 방장 위임 연결.
- lib/repositories/group_repository.dart: leave_group/transfer_group_host RPC.
- lib/services/private_photos.dart, photo_saver.dart: 인증 사진 읽기, 메모리 캐시/늦은 응답/다운로드 제한.
- 사진 조회 교체: screens/group의 group_info_screen, meetup_create_screen, meetup_detail_screen, photo_viewer_screen,
  widgets/group의 group_edit_sheets, group_join_sheet, member_profile_sheet,
  widgets/feed/feed_card 및 widgets/common/common_widgets.
- 추가/확장 테스트: services/private_photos_test, external_links_test,
  repositories/group_repository_test, screens/group_leave_test, host_transfer_menu_test, group_sidebar_test, profile_features_test.
- supabase/apply_private_photos_and_host_rules.sql, verify_private_photos_and_host_rules.sql,
  tests/private_photos_and_host_rules_test.sql: 아직 실제 서버에 실행하지 않은 적용안·확인·DB 테스트.

