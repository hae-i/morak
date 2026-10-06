import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/services/private_photos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// === 수정한 내용: 인증 다운로드·다른 출처·늦은 응답·권한 캐시 세대 변경을 검증한다 ===
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const base = 'https://project.invalid/storage/v1';
  test('only this project public storage identifiers are decoded', () {
    final ref = StoragePhotoRef.parse(
      '$base/object/public/meetup_photos/group/photo.jpg',
      base,
    )!;
    expect(ref.bucket, 'meetup_photos');
    expect(ref.path, 'group/photo.jpg');
    expect(
      StoragePhotoRef.parse(
        'https://other.invalid/storage/v1/object/public/profiles/a.jpg',
        base,
      ),
      isNull,
    );
    expect(StoragePhotoRef.parse('blob:local', base), isNull);
    expect(
      StoragePhotoRef.parse('$base/object/public/unknown/a.jpg', base),
      isNull,
    );
  });
  Future<void> login(SupabaseClient client, String id) =>
      client.auth.recoverSession(
        jsonEncode({
          'access_token': 'test-token-$id',
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'user': {
            'id': id,
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
  late SupabaseClient client;
  late Completer<http.Response> response;
  late Completer<http.Request> requested;
  setUp(() async {
    response = Completer();
    requested = Completer();
    client = SupabaseClient(
      'https://project.invalid',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/storage/')) {
          requested.complete(request);
          return response.future;
        }
        return http.Response('', 204);
      }),
    );
    await login(client, 'a');
  });
  tearDown(() => client.dispose());
  test(
    'SDK download uses session authentication and stable original path',
    () async {
      final result = PrivatePhotos.download(
        client,
        const StoragePhotoRef('meetup_photos', 'group/a.jpg'),
      );
      final request = await requested.future;
      expect(request.url.path, '/storage/v1/object/meetup_photos/group/a.jpg');
      expect(request.headers['Authorization'], 'Bearer test-token-a');
      response.complete(http.Response.bytes([1, 2, 3], 200));
      expect(await result, [1, 2, 3]);
    },
  );
  for (final change in ['switch', 'logout', 'leave']) {
    test('late photo completion is rejected after $change', () async {
      final result = PrivatePhotos.download(
        client,
        const StoragePhotoRef('meetup_photos', 'g/a.jpg'),
      );
      final assertion = expectLater(result, throwsStateError);
      await requested.future;
      if (change == 'switch') {
        await login(client, 'b');
      }
      if (change == 'logout') {
        await client.auth.signOut();
      }
      if (change == 'leave') {
        PrivatePhotos.invalidate();
      }
      response.complete(http.Response.bytes([1, 2, 3], 200));
      await assertion;
    });
  }
  test('same user session refresh preserves a pending photo', () async {
    final result = PrivatePhotos.download(
      client,
      const StoragePhotoRef('meetup_photos', 'g/a.jpg'),
    );
    await requested.future;
    await login(client, 'a');
    response.complete(http.Response.bytes([1, 2, 3], 200));
    expect(await result, [1, 2, 3]);
  });
  test('server denial propagates instead of retrying a public URL', () async {
    final result = PrivatePhotos.download(
      client,
      const StoragePhotoRef('profiles', 'a.jpg'),
    );
    final assertion = expectLater(result, throwsStateError);
    await requested.future;
    response.complete(http.Response('{"message":"denied"}', 403));
    await assertion;
  });
  test('cache key differs across accounts and membership invalidation', () {
    const ref = StoragePhotoRef('profiles', 'a.jpg');
    final a = PrivatePhotoProvider(client, ref, 'a', 1);
    expect(a, isNot(PrivatePhotoProvider(client, ref, 'b', 1)));
    expect(a, isNot(PrivatePhotoProvider(client, ref, 'a', 2)));
    expect(a, PrivatePhotoProvider(client, ref, 'a', 1));
  });
}
