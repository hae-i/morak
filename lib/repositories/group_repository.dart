import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_model.dart';

class GroupRepository {
  final _client = Supabase.instance.client;

  // 1. 내 모임 목록 조회
  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw '로그인 정보가 없습니다.';

    final data = await _client
        .from('group_members')
        .select('role, joined_at, groups (*)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return data
        .map(
          (json) => {
            'group': GroupModel.fromJson(json['groups']),
            'role': json['role'],
          },
        )
        .toList();
  }

  // 🌟 2. 모임 생성 (방장 자동 추가 로직 포함!)
  Future<void> createGroup(
    String name,
    String nickname,
    String? emoji,
    String? hexColor,
  ) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';

    // ① groups 테이블에 모임 생성 후 id 획득
    final groupData = await _client
        .from('groups')
        .insert({'name': name, 'theme_color': hexColor, 'theme_emoji': emoji})
        .select('id')
        .single();

    // ② group_members 테이블에 나를 '방장(host)'으로 쏙! 넣어줍니다.
    await _client.from('group_members').insert({
      'group_id': groupData['id'],
      'user_id': currentUser.id,
      'role': 'host',
      'display_name': nickname,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 3. 모임 정보 수정
  Future<void> updateGroup(
    String groupId,
    String name,
    String? hexColor,
    String? emoji,
  ) async {
    await _client
        .from('groups')
        .update({'name': name, 'theme_color': hexColor, 'theme_emoji': emoji})
        .eq('id', groupId);
  }

  // 🌟 4. 모임 삭제 (DB에서 CASCADE를 걸어뒀으므로 그룹만 지우면 끝!)
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }

  // 5. 특정 모임의 상세 정보와 멤버 목록
  Future<Map<String, dynamic>> fetchGroupDetail(String groupId) async {
    final groupData = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .single();
    final membersData = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    return {'group': GroupModel.fromJson(groupData), 'members': membersData};
  }
}
