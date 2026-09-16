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

  // 5. 🌟 상세 화면 로드 (복잡한 랭킹 계산까지 레포지토리가 다 해서 넘겨줍니다!)
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(
    String groupId,
  ) async {
    final groupRes = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .single();
    final meetupsRes = await _client
        .from('meetups')
        .select('*, attendances(member_id)')
        .eq('group_id', groupId)
        .order('meet_date', ascending: false);
    final membersRes = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    int totalMeetups = meetupsRes.length;
    Map<String, int> attendanceCounts = {};
    for (var meetup in meetupsRes) {
      for (var att in meetup['attendances'] as List? ?? []) {
        String mId = att['member_id'].toString();
        attendanceCounts[mId] = (attendanceCounts[mId] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> ranked = [];
    for (var m in membersRes) {
      String mId = m['id'].toString();
      int attended = attendanceCounts[mId] ?? 0;
      ranked.add({
        ...m,
        'attended_count': attended,
        'attendance_rate': totalMeetups > 0
            ? (attended / totalMeetups) * 100
            : 0.0,
      });
    }

    // 랭킹 정렬
    ranked.sort((a, b) {
      int r = b['attendance_rate'].compareTo(a['attendance_rate']);
      return r != 0 ? r : a['display_name'].compareTo(b['display_name']);
    });

    return {
      'group': groupRes,
      'meetups': meetupsRes,
      'members': membersRes,
      'rankedMembers': ranked,
    };
  }

  // 6. 🌟 만남 기록 삭제
  Future<void> deleteMeetup(String meetupId) async {
    await _client.from('meetups').delete().eq('id', meetupId);
  }

  // 7. 🌟 멤버 영입 (수동 추가)
  Future<void> addMember(String groupId, String displayName) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'display_name': displayName,
    });
  }

  // 8. 🌟 멤버 내보내기
  Future<void> removeMember(String memberId) async {
    await _client.from('group_members').delete().eq('id', memberId);
  }
}
