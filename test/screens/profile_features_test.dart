import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/user_model.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/screens/profile/my_page_screen.dart';
import 'package:morak/screens/profile/account_info_screen.dart';
import 'package:morak/services/external_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 마이페이지 계정 메뉴·계정 전환/로그아웃·메일 실패·정책 연결을 검증한다 ===
void main() {
  testWidgets(
    'account details update with auth and profile menus open correct destinations',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'http://localhost:1',
        publishableKey: 'test-public-key',
        debug: false,
        httpClient: MockClient((_) async => http.Response('', 204)),
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUri: false,
        ),
      );
      final auth = Supabase.instance.client.auth;
      Future<void> login(String id, String email) => auth.recoverSession(
        jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'user': {
            'id': id,
            'aud': 'authenticated',
            'created_at': '2026-10-06T00:00:00Z',
            'email': email,
            'app_metadata': {
              'providers': ['google'],
            },
          },
        }),
      );
      await login(
        '00000000-0000-0000-0000-000000000001',
        'first@example.invalid',
      );
      locator.registerSingleton<UserRepository>(_Users());
      addTearDown(() => locator.reset());
      final opened = <Uri>[];
      var mailAvailable = false;
      final links = ExternalLinks(
        launch: (uri) async {
          opened.add(uri);
          return uri.scheme != 'mailto' || mailAvailable;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: MyPageScreen(externalLinks: links)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('계정 정보'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('계정 정보'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountInfoScreen), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('first@example.invalid'), findsOneWidget);
      expect(find.text('2026-10-06'), findsOneWidget);
      // === 수정한 내용: 계정 이름을 제외하고 값만 입력창 형태, 항목명은 볼드로 표시하는지 확인한다 ===
      expect(find.text('계정 이름'), findsNothing);
      expect(find.byType(InputDecorator), findsNWidgets(4));
      expect(
        tester.widget<Text>(find.text('현재 로그인 방식')).style?.fontWeight,
        FontWeight.bold,
      );
      await login(
        '00000000-0000-0000-0000-000000000002',
        'second@example.invalid',
      );
      await tester.pumpAndSettle();
      expect(find.text('first@example.invalid'), findsNothing);
      expect(find.text('second@example.invalid'), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('second@example.invalid'), findsNothing);
      expect(find.text('로그인이 필요합니다.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('고객센터 / 피드백'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('고객센터 / 피드백'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('morak@morak.app'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      mailAvailable = true;
      await tester.tap(find.text('고객센터 / 피드백'));
      await tester.pumpAndSettle();
      expect(opened.last.scheme, 'mailto');
      expect(find.byType(AlertDialog), findsNothing);
      await tester.scrollUntilVisible(
        find.text('개인정보 보호'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('개인정보 보호'));
      await tester.pumpAndSettle();
      expect(opened.last.toString(), 'https://morak.app/privacy');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _Users extends UserRepository {
  @override
  Future<UserModel?> fetchMyGlobalProfile() async =>
      UserModel(id: 'user', displayName: 'Test User');
}
