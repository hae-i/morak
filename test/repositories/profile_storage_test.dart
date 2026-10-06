import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:morak/repositories/user_repository.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:morak/utils/storage_uploads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/repository_server.dart';

// === 수정한 내용: 사진 삭제, DB 실패 정리와 통신 실패 시 데이터 보존을 실제 SDK 요청으로 검증한다 ===
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
    server.handler = (request) async =>
        request.method == 'POST' && request.uri.path.startsWith('/storage/')
        ? TestResponse({
            'Key': request.uri.path.replaceFirst('/storage/v1/object/', ''),
          })
        : const TestResponse([]);
  });
  tearDown(() async {
    await client.dispose();
    await server.close();
  });
  XFile image() => XFile.fromData(
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    name: 'test.png',
  );
  test(
    'global profile removal sends null and retains nickname and birthday',
    () async {
      await UserRepository(client: client).updateMyGlobalProfile(
        nickname: 'Name',
        birthday: '2000-01-01',
        existingImageUrl: null,
      );
      final body = server.requests.single.body as Map;
      expect(body.containsKey('profile_image_url'), isTrue);
      expect(body['profile_image_url'], isNull);
      expect(body['birthday'], '2000-01-01');
    },
  );
  test(
    'group member removal sends null and preserves privacy choice',
    () async {
      await GroupRepository(client: client).updateGroupMemberProfile(
        memberId: 'member',
        displayName: 'Name',
        isBirthdayPublic: false,
      );
      final body = server.requests.single.body as Map;
      expect(body.containsKey('profile_image_url'), isTrue);
      expect(body['profile_image_url'], isNull);
      expect(body['is_birthday_public'], false);
    },
  );
  test('known database rejection removes only this attempt uploads', () async {
    final batch = StorageUploads(client);
    await batch.upload('profiles', image(), prefix: 'avatars/');
    await expectLater(
      batch.commit(
        () => Future<void>.error(
          const PostgrestException(message: 'rejected', code: '23503'),
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(server.requests.map((r) => r.method), ['POST', 'DELETE']);
    final deleted = (server.requests.last.body as Map)['prefixes'] as List;
    expect(deleted.single, endsWith('.png'));
    expect(deleted.single, isNot('existing.png'));
  });
  test(
    'unknown network outcome must not delete a potentially referenced upload',
    () async {
      final batch = StorageUploads(client);
      await batch.upload('profiles', image());
      await expectLater(
        batch.commit(
          () => Future<void>.error(const SocketException('disconnected')),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(server.requests.length, 1);
      expect(server.requests.single.method, 'POST');
    },
  );
  test(
    'gateway timeout response must retain a possibly committed photo',
    () async {
      final batch = StorageUploads(client);
      await batch.upload('profiles', image());
      await expectLater(
        batch.commit(
          () => Future<void>.error(
            const PostgrestException(message: 'Gateway timeout', code: '504'),
          ),
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(server.requests.length, 1);
    },
  );
  test(
    'unrecognized bytes and oversized photos are rejected before upload',
    () async {
      await expectLater(
        readImagePayload(
          XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'fake.jpg'),
        ),
        throwsArgumentError,
      );
      await expectLater(
        readImagePayload(
          XFile.fromData(Uint8List(10 * 1024 * 1024 + 1), name: 'large.png'),
        ),
        throwsArgumentError,
      );
      expect(server.requests, isEmpty);
    },
  );
  test('JPEG MIME is image/jpeg even when extension is absent', () async {
    final payload = await readImagePayload(
      XFile.fromData(Uint8List.fromList([255, 216, 255]), name: 'photo'),
    );
    expect(payload.contentType, 'image/jpeg');
    expect(payload.extension, 'jpg');
  });
  test(
    'idempotent group retry cleans only newly uploaded unused files',
    () async {
      server.handler = (request) async => request.uri.path.contains('/rpc/')
          ? const TestResponse({'id': 'group', 'created': false})
          : request.method == 'POST'
          ? TestResponse({
              'Key': request.uri.path.replaceFirst('/storage/v1/object/', ''),
            })
          : const TestResponse([]);
      await GroupRepository(client: client).createGroup(
        name: 'Group',
        nickname: 'Owner',
        isBirthdayPublic: false,
        coverImage: image(),
        memberImage: image(),
        requestId: 'same-operation',
      );
      expect(server.requests.map((r) => r.method), [
        'POST',
        'POST',
        'POST',
        'DELETE',
        'DELETE',
      ]);
      final deleted = server.requests
          .where((r) => r.method == 'DELETE')
          .expand((r) => (r.body as Map)['prefixes'] as List)
          .toList();
      expect(deleted.length, 2);
      expect(deleted.every((path) => path.toString().endsWith('.png')), isTrue);
    },
  );
  test('a later invalid image cleans earlier new uploads without writing the group', () async {
    await expectLater(
      GroupRepository(client: client).createGroup(
        name: 'Group',
        nickname: 'Owner',
        isBirthdayPublic: false,
        coverImage: image(),
        logoImage: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'bad.png',
        ),
      ),
      throwsArgumentError,
    );
    expect(server.requests.map((r) => r.method), ['POST', 'DELETE']);
  });
}
