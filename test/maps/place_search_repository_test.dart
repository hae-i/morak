import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/models/place_map_center.dart';
import 'package:morak/repositories/place_search_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const center = PlaceMapCenter(37.5, 127.1);
  Future<PlaceSearchRepository> repository(Map<String, dynamic> payload) async {
    final client = SupabaseClient(
      'http://localhost:1',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['scope'], 'map');
        expect(body['center'], center.toJson());
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'user': {
          'id': '00000000-0000-0000-0000-000000000001',
          'aud': 'authenticated',
          'created_at': '2026-10-07T00:00:00Z',
        },
      }),
    );
    return PlaceSearchRepository(client: client);
  }

  test(
    'an old function response is rejected with a deployment instruction',
    () async {
      final repo = await repository({'items': []});
      await expectLater(
        repo.search(groupId: 'group', query: '스타벅스', center: center),
        throwsA(
          isA<PlaceSearchException>().having(
            (e) => e.message,
            'message',
            contains('다시 배포'),
          ),
        ),
      );
    },
  );

  test(
    'a response must acknowledge the requested center instead of City Hall',
    () async {
      final wrong = await repository({
        'items': [],
        'search_scope': 'map',
        'search_center': {'latitude': 37.5666, 'longitude': 126.979},
      });
      await expectLater(
        wrong.search(groupId: 'group', query: '스타벅스', center: center),
        throwsA(isA<PlaceSearchException>()),
      );
      final right = await repository({
        'items': [],
        'search_scope': 'map',
        'search_center': center.toJson(),
      });
      expect(
        await right.search(groupId: 'group', query: '스타벅스', center: center),
        isEmpty,
      );
    },
  );
}
