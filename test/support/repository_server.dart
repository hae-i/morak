import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 저장과 업로드 실패를 실제 HTTP 요청으로 검증하는 로컬 서버를 공유한다 ===
class TestRequest {
  final String method;
  final Uri uri;
  final Object? body;
  TestRequest(this.method, this.uri, this.body);
}

class TestResponse {
  final Object? body;
  final int status;
  final Map<String, String> headers;
  const TestResponse(this.body, {this.status = 200, this.headers = const {}});
}

class RepositoryServer {
  final HttpServer _server;
  final requests = <TestRequest>[];
  Future<TestResponse> Function(TestRequest)? handler;
  RepositoryServer._(this._server);
  String get url => 'http://127.0.0.1:${_server.port}';
  static Future<RepositoryServer> start() async {
    final server = RepositoryServer._(await HttpServer.bind('127.0.0.1', 0));
    server._server.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
      [],
      (list, part) => list..addAll(part),
    );
    Object? body;
    if (bytes.isNotEmpty &&
        request.headers.contentType?.mimeType == 'application/json') {
      body = jsonDecode(utf8.decode(bytes));
    }
    final recorded = TestRequest(request.method, request.uri, body);
    requests.add(recorded);
    final response =
        await (handler?.call(recorded) ?? Future.value(const TestResponse([])));
    request.response.statusCode = response.status;
    request.response.headers.contentType = ContentType.json;
    response.headers.forEach(request.response.headers.set);
    if (response.status != 204) {
      request.response.write(jsonEncode(response.body));
    }
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

Future<void> seedSession(
  SupabaseClient client, {
  String id = '00000000-0000-0000-0000-000000000001',
}) async {
  await client.auth.recoverSession(
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
