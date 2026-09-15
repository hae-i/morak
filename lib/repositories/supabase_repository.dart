import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepository {
  final _client = Supabase.instance.client;

  // 모임 생성하기
  Future<void> createGroup(String name, String nickname, String? emoji, int colorValue) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';

    final groupData = await _client.from('groups').insert({
      'name': name, 'description': '', 'theme_color': colorValue.toString(), 'theme_emoji': emoji,
    }).select().single();

    await _client.from('group_members').insert({
      'group_id': groupData['id'], 'user_id': currentUser.id, 'role': 'host',
      'display_name': nickname, 'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 모임 정보 수정하기
  Future<void> updateGroup(String groupId, String name, String? hexColor, String? emoji) async {
    await _client.from('groups').update({
      'name': name, 'cover_color': hexColor, 'profile_emoji': emoji,
    }).eq('id', groupId);
  }

  // 모임 삭제하기
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}