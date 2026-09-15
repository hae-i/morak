import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group_model.dart'; // 모델 추가!

class GroupRepository {
  final _client = Supabase.instance.client;

  // 1. 내 모임 목록 조회
  Future<List<GroupModel>> fetchMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw '로그인 정보가 없습니다.';

    final data = await _client
        .from('group_members')
        .select('''
          role,
          joined_at,
          groups ( id, name, theme_color, theme_emoji )
        ''')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    // Map -> GroupModel 변환해서 리턴!
    return data.map((json) => GroupModel.fromJson(json['groups'])).toList();
  }

  // 2. 모임 생성
  Future<void> createGroup(String name, String nickname, String? emoji, int colorValue) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';

    final groupData = await _client.from('groups').insert({
      'name': name,
      'description': '',
      'theme_color': colorValue.toString(),
      'theme_emoji': emoji,
    }).select().single();

    await _client.from('group_members').insert({
      'group_id': groupData['id'],
      'user_id': currentUser.id,
      'role': 'host',
      'display_name': nickname,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 3. 모임 정보 수정
  Future<void> updateGroup(String groupId, String name, String? hexColor, String? emoji) async {
    await _client.from('groups').update({
      'name': name,
      'cover_color': hexColor,
      'profile_emoji': emoji,
    }).eq('id', groupId);
  }

  // 4. 모임 삭제
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}