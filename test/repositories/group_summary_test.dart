import 'package:flutter_test/flutter_test.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/repository_server.dart';

// === 수정한 내용: 통계 RPC·페이지 범위와 권한 오류 시 우회 금지를 실제 SDK 요청으로 검증한다 ===
void main() {
  late RepositoryServer server;
  late SupabaseClient client;
  late GroupRepository repo;
  setUp(() async {
    server = await RepositoryServer.start();
    client = SupabaseClient(
      server.url,
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await seedSession(client);
    repo = GroupRepository(client: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close();
  });
  final group = {'id': 'g', 'name': 'Group'};
  test('summary keeps full count while fetching only first page', () async {
    server.handler = (r) async => r.uri.path.contains('/rpc/')
        ? TestResponse({
            'group': group,
            'rankedMembers': [],
            'totalMeetups': 500,
          })
        : const TestResponse([
            {
              'id': 'm',
              'group_id': 'g',
              'meet_date': '2026-10-06',
              'photos': [],
              'attendances': [],
            },
          ]);
    final result = await repo.fetchGroupDetailWithRanking('g');
    expect(result['totalMeetups'], 500);
    expect(result['paged'], true);
    expect((result['meetups'] as List).length, 1);
    expect(server.requests.length, 2);
    expect(server.requests.last.uri.queryParameters['limit'], '40');
    expect(
      server.requests.last.uri.queryParameters['order'],
      'meet_date.desc.nullslast,id.desc.nullslast',
    );
    await repo.fetchMeetupPage('g', offset: 40);
    expect(server.requests.last.uri.queryParameters['offset'], '40');
  });
  test('only missing summary function falls back to legacy reads', () async {
    server.handler = (r) async {
      if (r.uri.path.contains('/rpc/')) {
        return const TestResponse({
          'code': 'PGRST202',
          'message': 'missing',
        }, status: 404);
      }
      if (r.uri.path.endsWith('/groups')) return TestResponse(group);
      return const TestResponse([], headers: {'content-range': '*/0'});
    };
    final result = await repo.fetchGroupDetailWithRanking('g');
    expect(result['paged'], false);
    expect(server.requests.length, 4);
  });
  test('permission rejection never falls back to direct table reads', () async {
    server.handler = (_) async =>
        const TestResponse({'code': '42501', 'message': 'denied'}, status: 403);
    await expectLater(
      repo.fetchGroupDetailWithRanking('g'),
      throwsA(isA<PostgrestException>()),
    );
    expect(server.requests.length, 1);
  });
  test('malformed summary never displays partial statistics', () async {
    server.handler = (_) async => const TestResponse({'totalMeetups': 500});
    await expectLater(
      repo.fetchGroupDetailWithRanking('g'),
      throwsFormatException,
    );
    expect(server.requests.length, 1);
  });
  test('empty records with positive count fail for retry', () async {
    server.handler = (r) async => r.uri.path.contains('/rpc/')
        ? TestResponse({'group': group, 'rankedMembers': [], 'totalMeetups': 1})
        : const TestResponse([]);
    await expectLater(
      repo.fetchGroupDetailWithRanking('g'),
      throwsFormatException,
    );
  });
  test('invite preview uses name-only RPC', () async {
    server.handler = (_) async => const TestResponse('Group');
    expect(await repo.fetchGroupName('g'), 'Group');
    expect(
      server.requests.single.uri.path,
      '/rest/v1/rpc/get_group_invite_name',
    );
  });
  test('old DB invite name remains compatible', () async {
    server.handler = (r) async => r.uri.path.contains('/rpc/')
        ? const TestResponse({
            'code': 'PGRST202',
            'message': 'missing',
          }, status: 404)
        : const TestResponse({'name': 'Group'});
    expect(await repo.fetchGroupName('g'), 'Group');
    expect(server.requests.length, 2);
  });
  test('invite permission errors never fall back', () async {
    server.handler = (_) async =>
        const TestResponse({'code': '42501', 'message': 'denied'}, status: 403);
    await expectLater(
      repo.fetchGroupName('g'),
      throwsA(isA<PostgrestException>()),
    );
    expect(server.requests.length, 1);
  });
}
