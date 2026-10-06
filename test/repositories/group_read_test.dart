import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/repository_server.dart';

// === 수정한 내용: 서버 행 제한이 요청 크기보다 작아도 멤버와 통계에 필요한 기록이 누락되지 않게 검증한다 ===
void main() {
  late RepositoryServer server;
  late SupabaseClient client;
  setUp(() async {
    server = await RepositoryServer.start();
    client = SupabaseClient(
      server.url,
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await seedSession(client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close();
  });
  test(
    'members read all pages even when server only returns two at a time',
    () async {
      final members = List.generate(
        5,
        (i) => {
          'id': 'm$i',
          'user_id': null,
          'display_name': 'Member $i',
          'role': 'member',
          'is_birthday_public': false,
        },
      );
      server.handler = (request) async {
        final offset = int.parse(request.uri.queryParameters['offset'] ?? '0');
        final end = min(offset + 2, members.length);
        return TestResponse(
          members.sublist(offset, end),
          status: 206,
          headers: {'content-range': '$offset-${end - 1}/${members.length}'},
        );
      };
      final result = await GroupRepository(client: client)
          .fetchGroupMembers('group');
      expect(result.map((m) => m.id), ['m0', 'm1', 'm2', 'm3', 'm4']);
      expect(server.requests.map((r) => r.uri.queryParameters['offset']), [
        '0',
        '2',
        '4',
      ]);
    },
  );
  test('empty page before total count is reached fails instead of looping or showing incomplete stats', () async {
    server.handler = (_) async =>
        const TestResponse([], headers: {'content-range': '*/5'});
    await expectLater(
      GroupRepository(client: client).fetchGroupMembers('group'),
      throwsStateError,
    );
    expect(server.requests.length, 1);
  });
  test('an unavailable joined group does not crash the group list', () async {
    server.handler = (_) async => const TestResponse(
      [
        {'role': 'member', 'groups': null},
      ],
      headers: {'content-range': '0-0/1'},
    );
    expect(await GroupRepository(client: client).fetchMyGroups(), isEmpty);
  });
}
