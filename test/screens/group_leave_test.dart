import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/models/meetup_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/screens/group/group_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 나가기 확인·취소·완료와 방장 위임 안내를 실제 사이드바에서 검증한다 ===
void main() {
  testWidgets('member confirms leaving; host must transfer first', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://project.invalid',
      publishableKey: 'test-public-key',
      debug: false,
      httpClient: MockClient((_) async => http.Response('', 204)),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
      ),
    );
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'user': {
          'id': 'user',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    final repo = _Groups();
    locator.registerSingleton<GroupRepository>(repo);
    addTearDown(() => locator.reset());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GroupDetailScreen(groupId: 'g'),
                ),
              ),
              child: const Text('모임 열기'),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('모임 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('모임 메뉴'));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('모임 나가기'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.left, 0);
    await tester.tap(find.byTooltip('모임 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기').last);
    await tester.pumpAndSettle();
    expect(repo.left, 1);
    expect(find.text('모임 열기'), findsOneWidget);
    repo.role = 'host';
    await open();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('방장 위임이 필요합니다'), findsOneWidget);
    expect(repo.left, 1);
    expect(tester.takeException(), isNull);
  });
}

class _Groups extends GroupRepository {
  int left = 0;
  String role = 'member';
  @override
  Future<void> leaveGroup(String groupId) async {
    left++;
  }

  @override
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(
    String groupId,
  ) async => {
    'group': GroupModel(id: 'g', name: 'Group'),
    'meetups': <MeetupModel>[],
    'rankedMembers': [
      MemberModel(
        id: 'm',
        userId: 'user',
        displayName: 'Me',
        role: role,
        isBirthdayPublic: false,
      ),
    ],
  };
}
