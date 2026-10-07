import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morak/models/meetup_place.dart';
import 'package:morak/repositories/meetup_repository.dart';
import 'package:morak/repositories/group_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sample = MeetupPlace(
  name: '카페',
  address: '서울 송파구',
  latitude: 37.5,
  longitude: 127.1,
  source: 'naver_search',
);
void main() {
  test('text-only, new-place, and explicit clear use the appropriate single atomic RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'http://localhost:1',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final repo = MeetupRepository(client: client);
    Future<void> save({MeetupPlace? place, bool updatePlace = false}) =>
        repo.saveMeetup(
          groupId: 'group',
          meetupId: 'record',
          title: '만남',
          meetDate: '2026-10-07',
          photos: [],
          memberIds: {},
          place: place,
          updatePlace: updatePlace,
        );
    await save();
    expect(requests.last.url.path, '/rest/v1/rpc/save_meetup_atomic');
    expect(
      (jsonDecode(requests.last.body)['p_meetup'] as Map).containsKey('place'),
      isFalse,
    );
    await save(place: sample);
    expect(
      requests.last.url.path,
      '/rest/v1/rpc/save_meetup_with_place_atomic',
    );
    expect(
      jsonDecode(requests.last.body)['p_meetup']['place'],
      sample.toJson(),
    );
    await save(updatePlace: true);
    expect(
      requests.last.url.path,
      '/rest/v1/rpc/save_meetup_with_place_atomic',
    );
    expect(
      (jsonDecode(requests.last.body)['p_meetup'] as Map).containsKey('place'),
      isTrue,
    );
    expect(jsonDecode(requests.last.body)['p_meetup']['place'], isNull);
    expect(requests.length, 3);
  });

  test('a missing place RPC fails without silently falling back and discarding coordinates', () async {
    final paths = <String>[];
    final client = SupabaseClient(
      'http://localhost:1',
      'test-key',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '{"code":"PGRST202","message":"missing function"}',
          404,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await expectLater(
      MeetupRepository(client: client).saveMeetup(
        groupId: 'group',
        title: '만남',
        meetDate: '2026-10-07',
        photos: [],
        memberIds: {},
        place: sample,
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(paths, ['/rest/v1/rpc/save_meetup_with_place_atomic']);
  });

  test(
    'group map reads all pages rather than just the visible meetup page',
    () async {
      final offsets = <int>[];
      final client = SupabaseClient(
        'http://localhost:1',
        'test-key',
        httpClient: MockClient((request) async {
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          offsets.add(offset);
          final length = offset == 0 ? 200 : 1;
          return http.Response(
            jsonEncode(
              List.generate(
                length,
                (i) => {
                  'id': 'record-${offset + i}',
                  'title': '만남',
                  'meet_date': '2026-10-07',
                  'place': sample.toJson(),
                },
              ),
            ),
            200,
            headers: {
              'content-type': 'application/json',
              'content-range': '$offset-${offset + length - 1}/201',
            },
            request: request,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
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
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      final history = await GroupRepository(client: client)
          .fetchPlaceHistory('group');
      expect(offsets, [0, 200]);
      expect(history.visits.length, 201);
      expect(history.districts.single.count, 201);
      expect(history.pins.single.visits.length, 201);
    },
  );
}
