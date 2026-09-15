import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepository {
  final _client = Supabase.instance.client;

  // 내 모임 목록 가져오기
  Future<List<dynamic>> fetchMyGroups() async {
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

    return data;
  }

// TODO: 여기에 createGroup, deleteGroup 등도 다 모아두면 돼!
}