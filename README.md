# Morak

모임, 멤버, 만남 기록과 사진을 관리하는 Flutter 앱입니다. Flutter/Dart,
Riverpod, GetIt, GoRouter, Supabase Auth/DB/Storage, Google Sign-In을 사용합니다.
Cloudflare Worker 구현은 저장소에 없고 morak.app 링크와 웹 로그인 복귀 주소를 사용합니다.

<!-- === 수정한 내용: 기본 안내를 실제 설정, 검증 방법과 미실행 SQL 안내로 교체한다 === -->
## 로컬 설정

- 프로젝트의 Dart SDK 요구 조건에 맞는 Flutter를 설치하고 `flutter pub get`을 실행합니다.
- `.env.example`을 `.env`로 복사한 뒤 본인 프로젝트의 공개 설정을 입력합니다.
  `.env`는 앱 asset이므로 service_role 또는 서버 secret을 넣지 않습니다.
- iOS는 `ios/Flutter/GoogleSignIn.xcconfig.example`을 `GoogleSignIn.xcconfig`로
  복사하고 동일 Bundle ID의 실제 iOS OAuth client/reversed ID를 입력합니다.
- [Supabase 안내](supabase/README.md)의 순서로 DB를 준비합니다. SQL은 실제 DB에 실행하지 않았습니다.

## 검증

```text
flutter analyze --no-pub
flutter test --no-pub
```

로컬 HTTP 서버와 fake Repository 테스트는 실제 Google 로그인, iOS 권한,
Storage 정책 또는 PostgreSQL rollback을 대체하지 않습니다.
수정 내역과 외부 작업은 [기능 안정화 기록](docs/functional_fixes.md)에 정리했습니다.
UI 디자인, Provider 체계, 패키지를 유지했고 Android release 서명 변경은 제외했습니다.

실기기에서는 Google 로그인·취소, Splash 세션 복원, 계정 전환, 토큰 갱신 중
화면 유지, 로그인 전 초대, 사진 선택 중 화면 종료와 네트워크 실패 재시도를 확인합니다.
