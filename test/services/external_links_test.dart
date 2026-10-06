import 'package:flutter_test/flutter_test.dart';
import 'package:morak/services/external_links.dart';
import 'package:morak/models/account_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 개인정보 주소·메일 제목 인코딩·실패 전달과 계정 메타데이터 누락을 검증한다 ===
void main() {
  test(
    'support opens mail composer with fixed recipient and no account data',
    () async {
      Uri? opened;
      await ExternalLinks(
        launch: (uri) async {
          opened = uri;
          return true;
        },
      ).openSupportEmail();
      expect(opened!.scheme, 'mailto');
      expect(opened!.path, 'morak@morak.app');
      expect(opened!.queryParameters, {'subject': '모락 문의 / 피드백'});
      expect(opened!.query.contains('+'), false);
    },
  );
  test('privacy uses supplied policy path', () async {
    Uri? opened;
    await ExternalLinks(
      launch: (uri) async {
        opened = uri;
        return true;
      },
    ).openPrivacyPolicy();
    expect(opened.toString(), 'https://morak.app/privacy');
  });
  test('missing application and plugin failures reach the UI', () async {
    await expectLater(
      ExternalLinks(launch: (_) async => false).openSupportEmail(),
      throwsStateError,
    );
    await expectLater(
      ExternalLinks(launch: (_) async => throw StateError('native failure'))
          .openPrivacyPolicy(),
      throwsStateError,
    );
  });
  User user(Map<String, dynamic> metadata, {Map<String, dynamic>? profile}) =>
      User(
        id: 'u',
        appMetadata: metadata,
        userMetadata: profile,
        aud: 'authenticated',
        email: 'test@example.invalid',
        createdAt: '2026-10-06T00:00:00Z',
      );
  test(
    'account uses auth creation date and handles malformed optional names',
    () {
      final info = AccountInfo.fromUser(
        user(
          {
            'providers': ['google'],
          },
          profile: {'name': 123, 'full_name': 'Test User'},
        ),
      );
      expect(info.loginMethod, 'Google');
      // === 수정한 내용: 실명 메타데이터가 있어도 계정 모델은 읽지 않는다 ===
      expect(info.createdAt, DateTime.utc(2026, 10, 6));
      expect(info.lastSignInAt, isNull);
    },
  );
  test('multiple identities never claim initial signup provider is current login method', () {
    final info = AccountInfo.fromUser(
      user({
        'providers': ['google', 'email'],
        'provider': 'email',
      }),
    );
    expect(info.loginMethod, '확인할 수 없음');
  });
}
