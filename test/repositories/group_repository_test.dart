import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 생일 선택 전달과 그룹 생성의 단일 RPC 및 실패 시 직접 쓰기 금지를 검증한다 ===
void main() {
  late HttpServer server;
  late SupabaseClient client;
  late GroupRepository repo;
  final requests = <String>[];
  Map<String, dynamic>? body;
  bool fail = false;
  bool writeAllowed = true;
  setUp(() async {
    requests.clear();
    body = null;
    fail = false;
    writeAllowed = true;
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      final raw = await utf8.decoder.bind(request).join();
      body = raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      if (fail) {
        request.response.statusCode = 400;
        request.response.write(
          jsonEncode({'code': '23503', 'message': 'test failure'}),
        );
      } else {
        request.response.write(
          request.uri.path.contains('/rpc/')
              ? jsonEncode({
                  'id': '00000000-0000-4000-8000-000000000001',
                  'created': true,
                })
              : jsonEncode(
                  writeAllowed
                      ? [
                          {'id': 'target'},
                        ]
                      : [],
                ),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'user': {
          'id': '00000000-0000-0000-0000-000000000001',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    repo = GroupRepository(client: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  for (final birthdayPublic in [true, false]) {
    test('join stores explicit birthday visibility $birthdayPublic', () async {
      await repo.joinGroup(
        groupId: 'group',
        nickname: 'Name',
        isBirthdayPublic: birthdayPublic,
      );
      // === 수정한 내용: 재가입 시 기존 멤버 ID를 복원하는 RPC와 인증 사용자 지정 금지를 검증한다 ===
      expect(requests, ['POST /rest/v1/rpc/join_group']);
      expect(body!['p_is_birthday_public'], birthdayPublic);
      expect(body!.containsKey('user_id'), isFalse);
      expect(body!.containsKey('role'), isFalse);
    });
  }
  // === 수정한 내용: 탈퇴·위임은 검증 RPC만 호출하며 실패 시 직접 DB 쓰기로 우회하지 않는다 ===
  test('leave and host transfer use narrow authenticated RPCs', () async {
    await repo.leaveGroup('group');
    expect(requests, ['POST /rest/v1/rpc/leave_group']);
    expect(body, {'p_group_id': 'group'});
    requests.clear();
    await repo.transferHost('group', 'member');
    expect(requests, ['POST /rest/v1/rpc/transfer_group_host']);
    expect(body, {'p_group_id': 'group', 'p_member_id': 'member'});
  });
  test('rejected leave has no direct-delete fallback', () async {
    fail = true;
    await expectLater(
      repo.leaveGroup('group'),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, ['POST /rest/v1/rpc/leave_group']);
  });
  // === 수정한 내용: RLS가 0건으로 차단한 쓰기는 화면에서 성공 처리할 수 없도록 검증한다 ===
  test('blocked group delete and role change do not report success', () async {
    writeAllowed = false;
    await expectLater(repo.deleteGroup('group'), throwsStateError);
    await expectLater(
      repo.updateMemberRole('member', 'deputy'),
      throwsStateError,
    );
  });
  test('allowed group deletion and deputy assignment complete', () async {
    await repo.deleteGroup('group');
    await repo.updateMemberRole('member', 'deputy');
    expect(body, {'role': 'deputy'});
  });
  test('blocked meetup delete does not report success', () async {
    writeAllowed = false;
    await expectLater(
      MeetupRepository(client: client).deleteMeetup('meetup'),
      throwsStateError,
    );
  });
  Future<void> create() => repo.createGroup(
    name: 'Group',
    nickname: 'Owner',
    isBirthdayPublic: false,
    requestId: '00000000-0000-4000-8000-000000000001',
  );
  test('group and host are sent together without trusting client supplied role or user', () async {
    await create();
    expect(requests, ['POST /rest/v1/rpc/create_group_atomic']);
    expect(body!['p_group_id'], '00000000-0000-4000-8000-000000000001');
    expect((body!['p_member'] as Map)['is_birthday_public'], false);
    expect((body!['p_member'] as Map).containsKey('role'), isFalse);
    expect((body!['p_member'] as Map).containsKey('user_id'), isFalse);
  });
  test('failed RPC never falls back to partial group/member inserts', () async {
    fail = true;
    await expectLater(create(), throwsA(isA<PostgrestException>()));
    expect(requests, ['POST /rest/v1/rpc/create_group_atomic']);
  });
  test('retry preserves creation request ID', () async {
    await create();
    final firstId = body!['p_group_id'];
    await create();
    expect(body!['p_group_id'], firstId);
    expect(requests.length, 2);
  });
}
