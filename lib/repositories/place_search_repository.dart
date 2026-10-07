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
    String mode = 'auto',
    PlaceMapCenter? center,
  }) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 100) {
      throw const FormatException('Invalid search');
    }
    return _lookup(groupId: groupId, query: text, mode: mode, center: center);
  }

  Future<MeetupPlace> reverseGeocode({
    required String groupId,
    required PlaceMapCenter center,
  }) async {
    final places = await _lookup(
      groupId: groupId,
      query: '',
      mode: 'reverse',
      center: center,
    );
    if (places.length != 1 || places.single.source != 'manual_pin') {
      throw const FormatException('Invalid reverse response');
    }
    final place = places.single;
    if ((place.latitude - center.latitude).abs() > 0.000001 ||
        (place.longitude - center.longitude).abs() > 0.000001) {
      throw const FormatException('Pin coordinates changed');
    }
    return place;
  }

  Future<List<MeetupPlace>> _lookup({
    required String groupId,
    required String query,
    required String mode,
    PlaceMapCenter? center,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required');
    late final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(
            'naver-place-search',
            body: {
              'group_id': groupId,
              'query': query,
              'mode': mode,
              'name_only': true,
              if (center != null) 'center': center.toJson(),
            },
          )
          .timeout(const Duration(seconds: 15));
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      final message = switch (code) {
        'address_not_found' => '이 핀의 주소를 찾지 못했어요. 이름을 정해 위치만 저장할 수 있어요.',
        'reverse_search_not_configured' || 'reverse_search_auth_failed' =>
          '핀 주소 조회를 아직 사용할 수 없어요. 이름을 정해 위치만 저장할 수 있어요.',
        'nearby_search_auth_failed' || 'nearby_search_unavailable' =>
          '현재 지도 주변을 확인하지 못했어요. 지도 검색 설정을 확인해 주세요.',
        'place_search_auth_failed' => '네이버 장소 검색 인증을 확인해 주세요.',
        'address_search_auth_failed' =>
          '네이버 주소 검색 키와 Geocoding 사용 설정을 확인해 주세요.',
        'search_quota_unavailable' =>
          '검색 제한 설정을 확인해 주세요. 장소 저장용 SQL 적용이 필요합니다.',
        'address_search_not_configured' =>
          '주소 검색을 아직 사용할 수 없어요. 장소 이름으로 검색해 주세요.',
        'nearby_search_not_configured' =>
          '현재 지도 주변 검색을 아직 사용할 수 없어요. 지도 검색 설정을 확인해 주세요.',
        _ => switch (error.status) {
          400 => '검색 요청을 처리하지 못했습니다. 최신 검색 함수로 다시 배포해 주세요.',
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
    if ((data['items'] as List).isEmpty &&
        data['warning'] == 'address_search_auth_failed') {
      throw const PlaceSearchException(
        '일치하는 상호명이 없고, 주소 검색 인증도 실패했습니다. 주소 검색 키와 Geocoding 사용 설정을 확인해 주세요.',
      );
    }
    return (data['items'] as List).map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid search item');
      }
      return MeetupPlace.fromJson(item);
    }).toList();
  }
}
