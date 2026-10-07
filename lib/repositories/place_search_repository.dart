import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meetup_place.dart';
import '../models/place_map_center.dart';

class PlaceSearchException implements Exception {
  final String message;
  const PlaceSearchException(this.message);
}

class PlaceSearchRepository {
  final SupabaseClient _client;
  PlaceSearchRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<MeetupPlace>> search({
    required String groupId,
    required String query,
    String mode = 'place',
    PlaceMapCenter? center,
  }) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 100) {
      throw const FormatException('Invalid search');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required');
    late final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(
            'naver-place-search',
            body: {
              'group_id': groupId,
              'query': text,
              'mode': mode,
              if (center != null) 'center': center.toJson(),
            },
          )
          .timeout(const Duration(seconds: 15));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      final message = switch (code) {
        'address_search_not_configured' =>
          '주소 검색을 아직 사용할 수 없어요. 장소 이름으로 검색해 주세요.',
        'nearby_search_not_configured' =>
          '지도 주변 검색을 아직 사용할 수 없어요. 전체 지역 검색으로 바꿔 주세요.',
        _ => switch (error.status) {
          401 => '로그인이 만료되었어요. 다시 로그인해 주세요.',
          403 => '이 모임의 장소를 검색할 권한이 없어요.',
          404 || 503 => '장소 검색 서비스를 아직 사용할 수 없어요.',
          429 => '검색 요청이 많아요. 잠시 후 다시 시도해 주세요.',
          _ => '장소를 검색하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        },
      };
      throw PlaceSearchException(message);
    }
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('Session changed');
    }
    final data = response.data;
    if (response.status != 200 ||
        data is! Map ||
        data['items'] is! List ||
        (data['items'] as List).length > 5) {
      throw const FormatException('Invalid search response');
    }
    return (data['items'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid search item');
      }
      return MeetupPlace.fromJson(item);
    }).toList();
  }
}
