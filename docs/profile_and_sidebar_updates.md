# 계정 메뉴와 모임 사이드바

후속 화면·사진 권한·방장 정책 변경은 [최신 작업 기록](private_photos_and_host_rules.md)을 참고하세요. 아래는 최초 구현 기록입니다.

<!-- === 수정한 내용: 사용자 요청 UI 구현과 확정된 정책·미검증 외부 작업을 구분한다 === -->
2026-10-06. 사용자 실기기 보고: Galaxy Fold 8 / Android 17, 최신 코드 실행.
갤러리 권한 창 없음, 사진 선택 종료 복구는 확인하지 못함. 다른 항목 통과 여부는 이 보고로 단정하지 않습니다.

## 구현

- 계정 정보: 인증 계정의 로그인 방식, 이메일, 이름(있는 경우), 가입일, 최근 로그인일 표시.
  UserRepository.watchAccountInfo를 구독하고 로그아웃/계정 전환 시 이전 정보를 제거합니다.
  가입일은 프로필 생성일이 아닌 Auth 계정 생성일입니다. 토큰·원문 metadata·UUID는 표시하지 않습니다.
  여러 로그인 방식이 연결되어 현재 방식을 특정할 수 없으면 최초 가입 방식을 현재 방식으로 표시하지 않습니다.
- 모임 상세: 넓은 화면 AppBar 제거, 사이드바 제목은 모임명. 설정·공유 버튼은 하단.
  기존 '멤버 관리' 및 상단 '초대링크 복사하기' 버튼 제거. 좁은 화면은 우측 메뉴 버튼으로 같은 사이드바를 엽니다.
  넓은 화면 사이드바에 뒤로가기 유지, 기존 멤버 영역 탭으로 사이드바를 다시 열 수 있습니다.
  공유는 기존 동작대로 초대 링크를 클립보드에 복사합니다. 네이티브 공유 시트 기능을 추가한 것은 아닙니다.
- 설정 진입 시 발견한 GroupInfoScreen ListTile의 Material assertion도 표시 변경 없이 수정했습니다.
- 개인정보 보호: 사용자가 제공한 https://morak.app/privacy를 외부 브라우저로 엽니다.
  페이지 내용은 확정 전 초안이고 웹 도구로 내용을 읽지 못했으므로 정책 완성/접속 성공을 확인했다고 보고하지 않습니다.
- 고객센터/피드백: morak@morak.app 메일 작성 화면 연결. 자동 발송하지 않습니다.
  메일 앱이 없거나 실행 실패하면 주소를 선택/복사할 수 있는 안내를 표시합니다. 계정 데이터는 메일에 자동 첨부하지 않습니다.

주요 파일: lib/models/account_info.dart, lib/screens/profile/account_info_screen.dart,
lib/screens/profile/my_page_screen.dart, lib/repositories/user_repository.dart,
lib/services/external_links.dart, lib/screens/group/group_detail_screen.dart,
lib/widgets/group/member_drawer.dart, lib/screens/group/group_info_screen.dart.
새 패키지를 추가하지 않았으며 로그인·전역 Provider 구조와 SQL은 변경하지 않았습니다.

## 검증

test/services/external_links_test.dart: 주소/메일 인코딩/실패 전달/계정 metadata 누락과 복수 방식 표시.
test/screens/profile_features_test.dart: 실제 SDK 계정 전환·로그아웃 시 이메일 제거, 메뉴 연결, 메일 실패 안내.
test/screens/group_sidebar_test.dart: 넓은/좁은 화면 상단바와 메뉴, 같은 설정 진입·공유, 기존 버튼 제거.
기존 group_paging_test를 포함한 flutter test --no-pub 전체 80개가 통과했습니다.
flutter analyze --no-pub 결과는 오류 0개, 경고 0개, info 28개이며 info로 종료 코드 1입니다.
flutter build apk --debug --no-pub가 성공했으며 build/app/outputs/flutter-apk/app-debug.apk를 생성했습니다.
git diff --check도 통과했습니다.
실제 기기의 메일 앱 실행·정책 페이지·변경한 사이드바는 추가 사용자 확인이 필요합니다.

## 확정한 정책과 외부/SQL 후속 작업

1. 사진은 모임 멤버만 조회. 아직 구현/적용하지 않았으며 현재 공개 bucket은 그대로입니다.
   기존 public URL을 저장/조회하는 구조를 먼저 바꿔야 합니다. bucket만 비공개로 바꾸면 현재 이미지 표시가 깨집니다.
   공통 프로필 파일도 본인 또는 같은 모임에서 사용하는 파일만 읽게 하고, 이전 파일 경로·signed URL 갱신·탈퇴 후 접근을 검증해야 합니다.
2. 방장은 위임 후 탈퇴. 아직 서버 적용하지 않았습니다. 마지막 방장 탈퇴/강등/삭제 및 동시 요청을 서버에서 막는 설계가 필요합니다.
   기존 delete_user_permissions 초안은 이 신규 정책을 포함하지 않습니다.
3. 위 두 정책으로 기존 추가 SQL 초안을 보완해야 하므로 이전 파일을 바로 최종본으로 적용하지 않습니다.
4. 미참조 파일은 어떤 DB 사진 필드에서도 참조하지 않는 Storage 객체입니다. 파일 생성일만으로 구분하지 않습니다.
   보존 기간은 아직 결정하지 않았으며 공유 참조·진행 중 업로드·응답 유실·삭제 직전 재확인 후 처리해야 합니다.
5. 테스트 Supabase 프로젝트는 실제 프로젝트와 분리된 DB/Auth/Storage 환경입니다.
   테스트 계정과 가짜 데이터만 넣고 별도 URL/키로 실행하며 운영 .env를 임의 교체하지 않습니다.
6. 사용자는 전역 업로드 제한을 직접 설정하지 않았다고 확인했습니다. 실제 기본 전역 제한은 Dashboard 확인 필요.
   bucket별 10MB와 JPEG/PNG/WEBP/GIF 제한은 추가 설정 대상입니다.
7. 개인정보처리방침 내용 확정과 고객센터 메일 실제 수신 가능 여부는 사용자가 확인해야 합니다.
