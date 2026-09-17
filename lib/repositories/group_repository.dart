import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/group_model.dart';
import '../models/member_model.dart';
import '../models/meetup_model.dart';

class GroupRepository {
  final _client = Supabase.instance.client;

  // 🌟 내가 가입한 모든 모임 목록 가져오기
  // 용도: MyGroupScreen (내 모임 탭) 리스트 뿌려줄 때
  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 내가 속한 멤버 정보와, 그 그룹 정보(groups)를 통째로 가져옴!
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

  // 🌟 모임 상세 정보(그룹정보, 만남기록, 멤버랭킹) 한 번에 싹 다 가져오기
  // 용도: GroupDetailScreen 에 진입할 때 데이터를 쫙 깔아줌
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
        .select('*, users(birthday)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);

    // 💡 각 멤버가 몇 번 참석했는지 노가다로 계산
    int totalMeetups = meetupsRes.length;
    Map<String, int> attendanceCounts = {};
    for (var meetup in meetupsRes) {
      for (var att in meetup['attendances'] as List? ?? []) {
        String mId = att['member_id'].toString();
        attendanceCounts[mId] = (attendanceCounts[mId] ?? 0) + 1;
      }
    }

    // 💡 계산된 참석 횟수를 기반으로 참석률 계산 후 MemberModel 조립
    List<MemberModel> ranked = membersRes.map((m) {
      String mId = m['id'].toString();
      int attended = attendanceCounts[mId] ?? 0;
      double rate = totalMeetups > 0 ? (attended / totalMeetups) * 100 : 0.0;
      m['attended_count'] = attended;
      m['attendance_rate'] = rate;
      return MemberModel.fromJson(m);
    }).toList();

    // 참석률 높은 순, 같으면 이름 가나다 순으로 정렬
    ranked.sort((a, b) {
      int r = b.attendanceRate.compareTo(a.attendanceRate);
      return r != 0 ? r : a.displayName.compareTo(b.displayName);
    });

    return {
      'group': GroupModel.fromJson(groupRes),
      'meetups': meetupsRes.map((m) => MeetupModel.fromJson(m)).toList(),
      'rankedMembers': ranked,
    };
  }

  // 🌟 새 모임 만들기! (커버 사진, 로고, 내 멤버 프로필까지 한 큐에 저장)
  // 용도: GroupCreateScreen 에서 최종 완료 누를 때
  Future<void> createGroup({
    required String name,
    required String nickname,
    String? emoji,
    String? hexColor,
    String? profileImageUrl,
    XFile? coverImage,
    XFile? logoImage,
    required bool isBirthdayPublic,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';
    String? coverUrl, logoUrl;

    // 커버 사진 업로드
    if (coverImage != null) {
      final ext = coverImage.name.split('.').last.toLowerCase();
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('group_covers')
          .uploadBinary(
            fileName,
            await coverImage.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      coverUrl = _client.storage.from('group_covers').getPublicUrl(fileName);
    }
    // 로고 이미지 업로드
    if (logoImage != null) {
      final ext = logoImage.name.split('.').last.toLowerCase();
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('group_covers')
          .uploadBinary(
            fileName,
            await logoImage.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      logoUrl = _client.storage.from('group_covers').getPublicUrl(fileName);
    }

    // 그룹 생성 후 멤버(host)로 나를 즉시 가입시킴
    final groupData = await _client
        .from('groups')
        .insert({
          'name': name,
          'theme_color': hexColor,
          'theme_emoji': emoji,
          'cover_image_url': coverUrl,
          'logo_image_url': logoUrl,
        })
        .select('id')
        .single();
    await _client.from('group_members').insert({
      'group_id': groupData['id'],
      'user_id': currentUser.id,
      'role': 'host',
      'display_name': nickname,
      'profile_image_url': profileImageUrl,
      'is_birthday_public': isBirthdayPublic,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 🌟 모임 정보 수정 (이름, 색깔, 커버 등등)
  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? hexColor,
    String? emoji,
    XFile? newCoverImage,
    String? existingCoverUrl,
    XFile? newLogoImage,
    String? existingLogoUrl,
  }) async {
    String? finalCoverUrl = existingCoverUrl;
    String? finalLogoUrl = existingLogoUrl;

    if (newCoverImage != null) {
      final ext = newCoverImage.name.split('.').last.toLowerCase();
      final fileName =
          'cover_${groupId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('group_covers')
          .uploadBinary(
            fileName,
            await newCoverImage.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      finalCoverUrl = _client.storage
          .from('group_covers')
          .getPublicUrl(fileName);
    }
    if (newLogoImage != null) {
      final ext = newLogoImage.name.split('.').last.toLowerCase();
      final fileName =
          'logo_${groupId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('group_covers')
          .uploadBinary(
            fileName,
            await newLogoImage.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      finalLogoUrl = _client.storage
          .from('group_covers')
          .getPublicUrl(fileName);
    }

    await _client
        .from('groups')
        .update({
          'name': name,
          'theme_color': hexColor,
          'theme_emoji': emoji,
          'cover_image_url': finalCoverUrl,
          'logo_image_url': finalLogoUrl,
        })
        .eq('id', groupId);
  }

  // 🌟 모임 완전 삭제 (기록들도 싹 다 날아감)
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }

  // 🌟 특정 모임의 모든 멤버 목록 가져오기 (만남 기록 남길 때 참석자 체크용)
  Future<List<MemberModel>> fetchGroupMembers(String groupId) async {
    final data = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    return data.map((m) => MemberModel.fromJson(m)).toList();
  }

  // 🌟 모임 서랍장에서 수동으로 새 멤버 추가하기
  Future<void> addMember(String groupId, String displayName) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'display_name': displayName,
    });
  }

  // 🌟 모임 서랍장에서 멤버 강퇴/내보내기
  Future<void> removeMember(String memberId) async {
    await _client.from('group_members').delete().eq('id', memberId);
  }

  // 🌟 모임 서랍장에서 멤버 등급(방장/일반) 변경
  Future<void> updateMemberRole(String memberId, String newRole) async {
    await _client
        .from('group_members')
        .update({'role': newRole})
        .eq('id', memberId);
  }

  // 🌟 이 모임에서 활동하는 내 멤버 프로필(닉네임, 사진, 생일 공개여부) 업데이트
  Future<void> updateGroupMemberProfile({
    required String memberId,
    required String displayName,
    String? existingImageUrl,
    XFile? newImageFile,
    required bool isBirthdayPublic,
  }) async {
    String? finalImageUrl = existingImageUrl;
    if (newImageFile != null) {
      final ext = newImageFile.name.split('.').last.toLowerCase();
      final fileName =
          'group_${memberId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from('profiles')
          .uploadBinary(
            'avatars/$fileName',
            await newImageFile.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      finalImageUrl = _client.storage
          .from('profiles')
          .getPublicUrl('avatars/$fileName');
    }
    await _client
        .from('group_members')
        .update({
          'display_name': displayName,
          'is_birthday_public': isBirthdayPublic,
          if (finalImageUrl != null) 'profile_image_url': finalImageUrl,
        })
        .eq('id', memberId);
  }
}
