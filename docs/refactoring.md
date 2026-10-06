# 소규모 구조 정리

<!-- === 수정한 내용: 분리 판단·변경 범위·기존 동작 보호와 보류 작업을 기록한다 === -->
2026-10-06. SQL/외부 작업을 보류하고 현재 Flutter 구조만 정리했습니다.

## 구조 검토

현재 screens → repositories → Supabase, 공통 widgets, Riverpod 피드/인증 구분은
대체로 타당합니다. 단순히 긴 파일을 줄이려고 모든 UI 상태를 Provider에 넣지는 않습니다.
TextEditingController, 탭/애니메이션, Navigator, Scaffold 메시지는 화면 생명주기에
속합니다. 입력 폼은 등록과 편집의 초기값·삭제·저장 조건이 달라 전체 폼을 합치지 않았습니다.
Google 로그인/라우팅과 계정 전환 캐시는 이번에 변경하지 않았습니다.

확인된 분리 대상은 다음과 같습니다.

- GroupDetailScreen에 서버 조회·페이지 offset·요청 세대·앨범 가공과 표시가 함께 있었음.
- 상세 결과와 앨범은 Map 문자열 키 및 dynamic 형변환으로 화면에 전달되었음.
- 모임 상세의 멤버 프로필 시트는 화면에 긴 표시 코드로 포함되어 있었음.
- 프로필 설정과 편집 화면의 날짜 선택 기본값/범위/테마 및 입력 UI가 동일했음.

## 반영

| 책임 | 파일 | 변경 이유 |
| --- | --- | --- |
| 상세 상태 | lib/providers/group_detail_controller.dart | 초기/추가 조회, 재시도, 중복 잠금, 새로고침 세대, dispose 이후 응답 무시, 앨범 구성을 화면에서 이동 |
| 상세 데이터 타입 | lib/models/group_detail_data.dart | GroupDetailData와 AlbumPhoto로 타입이 있는 경계를 제공 |
| Repository 호환 | lib/repositories/group_repository.dart | fetchGroupDetail typed 진입점 추가. 기존 fetchGroupDetailWithRanking Map API·RPC·쿼리는 유지 |
| 멤버 표시 | lib/widgets/group/member_profile_sheet.dart | 표시만 맡으며 isMe와 편집 콜백을 받음. 인증 조회·이동은 화면에 유지 |
| 생일 입력 UI | lib/widgets/profile/birthday_field.dart | 두 프로필 화면의 동일 입력 표시 분리 |
| 생일 선택 | lib/utils/ui_utils.dart | 두 화면의 동일 기본 날짜·허용 범위·테마를 공통 UI helper로 유지 |
| 화면 연결 | group_detail_screen.dart, profile_edit_screen.dart, profile_setup_screen.dart | 분리한 객체 사용, 화면 이동·mounted 보호 유지 |

상세 Controller는 Flutter ChangeNotifier를 화면에서 생성·구독·dispose하는 작은 상태
객체입니다. Riverpod의 전역 피드/인증 구조를 교체하거나 새로운 상태관리 패키지를 넣지
않았습니다. getter는 읽기 전용 목록 view를 반환해 UI가 상태를 직접 변경하지 못하게 하며,
매 build마다 전체 앨범을 복사하지 않습니다.
GroupDetailScreen은 정리 전 1,023줄에서 801줄로 줄었습니다. 디자인/문구/순서 변경은
의도하지 않았고 신규 패키지도 없습니다. 모델/상태/분리 지점에 변경 이유 주석을 추가했습니다.

## 검증

- 기존 상세 페이지 화면의 늦은 요청·새로고침·실패 재시도·dispose 테스트 유지.
- 새 Controller 테스트 6개: 타입과 사진 연결, 오래된 실패 무시, 요청 잠금/새로고침 경합,
  실패 후 동일 offset 재시도/중복 제거, 실패한 silent refresh 뒤 데이터 보존, dispose.
- 새 Widget 테스트 3개: 비공개 생일/타인 편집 숨김, 본인 편집 콜백과 공개 생일,
  기존 날짜 기본 선택 및 취소/확정.
- flutter analyze --no-pub: 오류 0·경고 0·info 28개, 종료 코드 1. 기존 deprecated API 등으로 clean analyze는 아님.
- flutter test --no-pub: 기존 64개와 새 테스트 9개를 포함해 전체 73개 통과.
- git diff --check 통과. Flutter 변경만으로 별도 DB migration/외부 설정 변경은 필요하지 않습니다.

## 보류

나머지 큰 폼의 전체 Provider 전환, 공통 AppBar/모든 SnackBar를 하나로 강제 통합,
상태관리·GetIt 전면 교체는 이번 요청 범위에서 이득이 적어 진행하지 않았습니다.
서비스에 이미 공통화된 사진 저장/선택 복구/파일 검증도 중복 구현하지 않았습니다.
추가 typed Repository API 확장은 다른 화면 변경과 함께 점진적으로 할 수 있습니다.

SQL·외부 작업은 기존대로 남아 있습니다: 테스트 DB에서 group_summary → access_policies →
delete_user_permissions 검증, 두 계정 권한 테스트, 실제 Android 로그인/사진 저장/복구 확인,
계정 삭제 및 마지막 방장·Storage 잔여 파일 처리 결정. 실제 DB 변경은 하지 않았습니다.
