import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/group_model.dart';

class GroupRepository {
  final _client = Supabase.instance.client;

  // 1. 내 모임 목록 조회
  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
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

  // 🌟 2. 모임 생성 (커버 사진 추가)
  Future<void> createGroup(
    String name,
    String nickname,
    String? emoji,
    String? hexColor,
    String? profileImageUrl,
    XFile? coverImage,
    XFile? logoImage,
    bool isBirthdayPublic,
  ) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';

    String? coverUrl, logoUrl;

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

    final groupData = await _client
        .from('groups')
        .insert({
          'name': name, 'theme_color': hexColor, 'theme_emoji': emoji,
          'cover_image_url': coverUrl, 'logo_image_url': logoUrl, // 🌟 로고 저장
        })
        .select('id')
        .single();

    await _client.from('group_members').insert({
      'group_id': groupData['id'], 'user_id': currentUser.id, 'role': 'host',
      'display_name': nickname, 'profile_image_url': profileImageUrl,
      'is_birthday_public': isBirthdayPublic, // 🌟 생일 공개 여부 저장
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  // 🌟 3. 모임 정보 수정 (이름, 커버 사진 추가)
  Future<void> updateGroup(
    String groupId,
    String name,
    String? hexColor,
    String? emoji,
    XFile? newCoverImage,
    String? existingCoverUrl,
    XFile? newLogoImage,
    String? existingLogoUrl,
  ) async {
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
        .select('*, users(birthday)')
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

  // 👇 9. 🌟 여기에 멤버 권한 변경 (방장 <-> 일반 멤버) 로직을 추가합니다!
  Future<void> updateMemberRole(String memberId, String newRole) async {
    await _client
        .from('group_members')
        .update({'role': newRole})
        .eq('id', memberId);
  }

  // 👇 10. 🌟 홈 피드 데이터 가져오기 (내가 속한 모든 모임의 기록)
  Future<List<Map<String, dynamic>>> fetchHomeFeeds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // ① 내가 속한 모임들의 ID 싹 긁어오기
    final memberData = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    final groupIds = memberData.map((e) => e['group_id']).toList();

    if (groupIds.isEmpty) return [];

    // ② 해당 모임들의 만남 기록을 최신순으로 가져오기 (모임 이름, 이모지도 같이 조인해서 가져옴!)
    final feedsData = await _client
        .from('meetups')
        .select('*, groups(name, theme_emoji, theme_color)')
        .inFilter('group_id', groupIds)
        .order('meet_date', ascending: false);

    return List<Map<String, dynamic>>.from(feedsData);
  }

  // 👇 11. 만남 기록 작성용 멤버 목록 불러오기
  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    final data = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .order('joined_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // 👇 12. 수정 모드일 때 기존 출석자 불러오기
  Future<List<String>> fetchAttendances(String meetupId) async {
    final data = await _client
        .from('attendances')
        .select('member_id')
        .eq('meetup_id', meetupId);
    return data.map((row) => row['member_id'].toString()).toList();
  }

  // 👇 13. 🌟 대망의 만남 기록 & 사진 업로드 통합 저장 로직!
  Future<void> saveMeetup({
    required String groupId,
    String? meetupId,
    String? title,
    required String meetDate,
    String? location,
    String? menu,
    required List<dynamic> photos, // 💡 String(기존 사진)과 XFile(새 사진)이 섞인 리스트
    required Set<String> memberIds,
  }) async {
    List<String> finalPhotos = [];

    // 💡 UI에 보이는 순서 그대로! 스토리지에 올리거나 URL을 뽑아냅니다.
    for (int i = 0; i < photos.length; i++) {
      final item = photos[i];
      if (item is String) {
        finalPhotos.add(item); // 기존 사진이면 그대로 URL 추가
      } else if (item is XFile) {
        final ext = item.name.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await _client.storage
            .from('meetup_photos')
            .uploadBinary(
              '$groupId/$fileName',
              await item.readAsBytes(),
              fileOptions: FileOptions(contentType: 'image/$ext'),
            );
        finalPhotos.add(
          _client.storage
              .from('meetup_photos')
              .getPublicUrl('$groupId/$fileName'),
        ); // 새 사진이면 업로드 후 URL 추가
      }
    }

    final meetupData = {
      'group_id': groupId,
      'title': title?.isNotEmpty == true ? title : null,
      'meet_date': meetDate,
      'location': location?.isNotEmpty == true ? location : null,
      'menu': menu?.isNotEmpty == true ? menu : null,
      'photos': finalPhotos,
    };

    String currentMeetupId;
    if (meetupId == null) {
      final inserted = await _client
          .from('meetups')
          .insert(meetupData)
          .select('id')
          .single();
      currentMeetupId = inserted['id'];
    } else {
      currentMeetupId = meetupId;
      await _client
          .from('meetups')
          .update(meetupData)
          .eq('id', currentMeetupId);
      await _client
          .from('attendances')
          .delete()
          .eq('meetup_id', currentMeetupId);
    }

    if (memberIds.isNotEmpty) {
      final attendanceData = memberIds
          .map((mId) => {'meetup_id': currentMeetupId, 'member_id': mId})
          .toList();
      await _client.from('attendances').insert(attendanceData);
    }
  }

  // 👇 14. 🌟 모임 내 내 프로필 수정 로직!
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
          'is_birthday_public': isBirthdayPublic, // 🌟 DB 업데이트
          if (finalImageUrl != null) 'profile_image_url': finalImageUrl,
        })
        .eq('id', memberId);
  }
}
