import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meetup_model.dart';

class MeetupRepository {
  final _client = Supabase.instance.client;

  // 🌟 홈 화면 피드(최근 만남 순) 가져오기!
  // 용도: HomeFeedScreen 전체를 채워줌
  Future<List<MeetupModel>> fetchHomeFeeds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 내가 속한 모임 ID들 싹 긁어오기
    final memberData = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);
    final groupIds = memberData.map((e) => e['group_id']).toList();
    if (groupIds.isEmpty) return [];

    // 💡 inFilter 로 내가 속한 모임들의 만남 기록만 쏙쏙 빼옵니다! (그룹 정보도 묶어서)
    final feedsData = await _client
        .from('meetups')
        .select('*, groups(id, name, theme_emoji, theme_color, logo_image_url)')
        .inFilter('group_id', groupIds)
        .order('meet_date', ascending: false);

    return feedsData.map((m) => MeetupModel.fromJson(m)).toList();
  }

  // 🌟 새 만남 기록 저장 (수정 겸용)
  // 용도: MeetupCreateScreen 에서 만남 기록 완료 눌렀을 때
  Future<void> saveMeetup({
    required String groupId,
    String? meetupId,
    String? title,
    required String meetDate,
    String? location,
    String? menu,
    required List<dynamic> photos,
    required Set<String> memberIds,
  }) async {
    List<String> finalPhotos = [];

    // 💡 사진이 String(기존 사진)이면 그대로 두고, XFile(새 사진)이면 스토리지에 올려서 URL을 뽑아냅니다. (순서 유지!)
    for (int i = 0; i < photos.length; i++) {
      final item = photos[i];
      if (item is String) {
        finalPhotos.add(item);
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
        );
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
      // 새 기록이면 insert
      final inserted = await _client
          .from('meetups')
          .insert(meetupData)
          .select('id')
          .single();
      currentMeetupId = inserted['id'];
    } else {
      // 수정이면 update 후 기존 출석 데이터 날리기
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

    // 출석자(멤버) 리스트 새로 쏴주기
    if (memberIds.isNotEmpty) {
      final attendanceData = memberIds
          .map((mId) => {'meetup_id': currentMeetupId, 'member_id': mId})
          .toList();
      await _client.from('attendances').insert(attendanceData);
    }
  }

  // 🌟 특정 기록 완전 삭제
  Future<void> deleteMeetup(String meetupId) async {
    await _client.from('meetups').delete().eq('id', meetupId);
  }

  // 🌟 특정 기록에 참석한 멤버 ID 목록만 가져오기
  // 용도: MeetupCreateScreen(수정 모드) 에서 누가 체크되어 있었는지 불러올 때
  Future<List<String>> fetchAttendances(String meetupId) async {
    final data = await _client
        .from('attendances')
        .select('member_id')
        .eq('meetup_id', meetupId);
    return data.map((row) => row['member_id'].toString()).toList();
  }
}
