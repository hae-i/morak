import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meetup_place.dart';

class PlaceSearchRepository {
  final SupabaseClient _client;
  PlaceSearchRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<MeetupPlace>> search({
    required String groupId,
    required String query,
  }) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 100) {
      throw const FormatException('Invalid search');
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required');
    final response = await _client.functions
        .invoke(
          'naver-place-search',
          body: {'group_id': groupId, 'query': text},
        )
        .timeout(const Duration(seconds: 15));
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
