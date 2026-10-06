// === 수정한 내용: 실제 화면에서 일반 멤버·부방장·방장 권한 메뉴와 늦은 계정 조회를 검증한다 ===
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:morak/locator.dart';
import 'package:morak/models/group_model.dart';
import 'package:morak/models/member_model.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/screens/group/group_info_screen.dart';
import 'package:morak/widgets/group/member_manage_sheet.dart';

Future<void> login(String id) async {
  await Supabase.instance.client.auth.recoverSession(
    jsonEncode({
      'access_token': 'test-token',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
}

void main() {
  setUpAll(() async {
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
  });
  tearDown(() => locator.reset());
  tearDownAll(() => Supabase.instance.dispose());
  for (final role in ['member', 'deputy', 'host']) {
    testWidgets('$role sees only permitted group actions', (tester) async {
      await login('00000000-0000-0000-0000-000000000001');
      locator.registerSingleton<GroupRepository>(_Groups(role));
      await tester.pumpWidget(
        MaterialApp(
          home: GroupInfoScreen(
            groupData: GroupModel.fromJson({'id': 'group', 'name': 'Group'}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('모임 정보 수정'),
        role == 'member' ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('모임 삭제하기'),
        role == 'host' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('old role lookup cannot grant actions after account changes', (
    tester,
  ) async {
    await login('00000000-0000-0000-0000-000000000001');
    final groups = _Groups('host')
      ..pending = Completer<Map<String, dynamic>?>();
    locator.registerSingleton<GroupRepository>(groups);
    await tester.pumpWidget(
      MaterialApp(
        home: GroupInfoScreen(
          groupData: GroupModel.fromJson({'id': 'group', 'name': 'Group'}),
        ),
      ),
    );
    await tester.pump();
    await login('00000000-0000-0000-0000-000000000002');
    groups.pending!.complete({'role': 'host'});
    await tester.pumpAndSettle();
    expect(find.text('모임 정보 수정'), findsNothing);
    expect(find.text('모임 삭제하기'), findsNothing);
  });
  testWidgets(
    'deputy management cannot display any administrator role action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberManageSheet(
              member: MemberModel(
                id: 'member',
                userId: 'account',
                displayName: 'Member',
                role: 'member',
                isBirthdayPublic: false,
              ),
              canChangeRoles: false,
              onKick: () {},
              onChangeRole: () {},
              onTransferHost: () {},
              onDeputyRole: () {},
            ),
          ),
        ),
      );
      expect(find.text('모임에서 내보내기'), findsOneWidget);
      expect(find.text('방장 위임'), findsNothing);
      expect(find.text('부방장 임명'), findsNothing);
    },
  );
}

class _Groups extends GroupRepository {
  _Groups(this.role);
  final String role;
  Completer<Map<String, dynamic>?>? pending;
  @override
  Future<Map<String, dynamic>?> fetchMyMembership(String groupId) async =>
      pending == null
      ? {'role': role, 'is_deleted': false}
      : await pending!.future;
}
