import 'dart:convert';
// === 수정한 내용: 단일 RPC 실패가 기존 만남과 출석을 손상시키지 않도록 요청 계약을 검증한다 ===
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _MeetupServer server;
  late SupabaseClient client;
  late MeetupRepository repository;

  setUp(() async {
    server = await _MeetupServer.start();
    client = SupabaseClient(
      server.url,
      'test-only-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = MeetupRepository(client: client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close();
  });

  Future<void> save({String? id = 'meetup-1', Set<String>? members}) {
    return repository.saveMeetup(
      groupId: 'group-1',
      meetupId: id,
      title: 'Updated title',
      meetDate: '2026-10-05T12:00:00.000',
      location: '',
      menu: 'Lunch',
      photos: ['https://example.invalid/existing.jpg'],
      memberIds: members ?? {'member-2', 'member-3'},
    );
  }

  test('failed edit preserves the existing meetup and attendances', () async {
    server.failAttendanceInsert = true;

    await expectLater(save(), throwsA(isA<PostgrestException>()));

    expect(server.attendees, ['member-1']);
    expect(server.meetup['title'], 'Original title');
    expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
  });

  test('failed create leaves no partially saved meetup', () async {
    server.meetup.clear();
    server.attendees.clear();
    server.failAttendanceInsert = true;

    await expectLater(save(id: null), throwsA(isA<PostgrestException>()));

    expect(server.meetup, isEmpty);
    expect(server.attendees, isEmpty);
    expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
  });

  test('edit sends the complete replacement in one RPC', () async {
    await save();

    expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
    expect(server.meetup['title'], 'Updated title');
    expect(server.attendees, ['member-2', 'member-3']);
    expect(server.lastBody, {
      'p_meetup_id': 'meetup-1',
      'p_meetup': {
        'group_id': 'group-1',
        'title': 'Updated title',
        'meet_date': '2026-10-05T12:00:00.000',
        'location': null,
        'menu': 'Lunch',
        'photos': ['https://example.invalid/existing.jpg'],
      },
      'p_member_ids': ['member-2', 'member-3'],
    });
  });

  test(
    'an intentionally empty attendance selection clears attendees',
    () async {
      await save(members: {});

      expect(server.attendees, isEmpty);
      expect(server.lastBody!['p_member_ids'], isEmpty);
      expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
    },
  );

  test('create sends a null meetup ID and saves attendees', () async {
    server.meetup.clear();
    server.attendees.clear();

    await save(id: null);

    expect(server.lastBody!['p_meetup_id'], isNull);
    expect(server.meetup['title'], 'Updated title');
    expect(server.attendees, ['member-2', 'member-3']);
    expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
  });

  test(
    'missing RPC propagates the error without unsafe fallback writes',
    () async {
      server.rpcMissing = true;

      await expectLater(save(), throwsA(isA<PostgrestException>()));

      expect(server.meetup['title'], 'Original title');
      expect(server.attendees, ['member-1']);
      expect(server.requests, ['POST /rest/v1/rpc/save_meetup_atomic']);
    },
  );
}

// This exercises actual Supabase HTTP calls, not database transaction semantics.
// The legacy handlers make the pre-fix DELETE-then-failed-INSERT reproducible.
class _MeetupServer {
  _MeetupServer(this._server);

  final HttpServer _server;
  final requests = <String>[];
  final meetup = <String, dynamic>{
    'id': 'meetup-1',
    'group_id': 'group-1',
    'title': 'Original title',
  };
  final attendees = <String>['member-1'];
  Map<String, dynamic>? lastBody;
  bool failAttendanceInsert = false;
  bool rpcMissing = false;

  String get url => 'http://127.0.0.1:${_server.port}';

  static Future<_MeetupServer> start() async {
    final server = _MeetupServer(await HttpServer.bind('127.0.0.1', 0));
    server._server.listen(server._handle);
    return server;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests.add('${request.method} $path');
    final text = await utf8.decoder.bind(request).join();
    final dynamic body = text.isEmpty ? null : jsonDecode(text);
    request.response.headers.contentType = ContentType.json;

    if (path == '/rest/v1/rpc/save_meetup_atomic') {
      lastBody = Map<String, dynamic>.from(body as Map);
      if (rpcMissing || failAttendanceInsert) {
        _fail(request, rpcMissing ? 'PGRST202' : '23503');
      } else {
        meetup.addAll(Map<String, dynamic>.from(lastBody!['p_meetup'] as Map));
        attendees
          ..clear()
          ..addAll(List<String>.from(lastBody!['p_member_ids'] as List));
        request.response.statusCode = HttpStatus.noContent;
      }
    } else if (path == '/rest/v1/meetups') {
      meetup.addAll(Map<String, dynamic>.from(body as Map));
      if (request.method == 'POST') {
        meetup['id'] = 'meetup-1';
        request.response.write(jsonEncode({'id': 'meetup-1'}));
      } else {
        request.response.statusCode = HttpStatus.noContent;
      }
    } else if (path == '/rest/v1/attendances' && request.method == 'DELETE') {
      attendees.clear();
      request.response.statusCode = HttpStatus.noContent;
    } else if (path == '/rest/v1/attendances' && request.method == 'POST') {
      if (failAttendanceInsert) {
        _fail(request, '23503');
      } else {
        attendees.addAll(
          (body as List).map((row) => row['member_id'] as String),
        );
        request.response.statusCode = HttpStatus.noContent;
      }
    } else {
      _fail(request, 'unexpected_request');
    }
    await request.response.close();
  }

  void _fail(HttpRequest request, String code) {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(
      jsonEncode({
        'code': code,
        'message': 'Test failure',
        'details': null,
        'hint': null,
      }),
    );
  }
}
