import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meetup_model.dart';
import '../models/meetup_place.dart';
import '../utils/storage_uploads.dart';

class MeetupRepository {
  // === 수정한 내용: 클라이언트 주입으로 실제 서버 없이 원자적 저장 요청의 회귀 테스트를 지원한다 ===
  MeetupRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // 🌟 홈 화면 피드(최근 만남 순) 가져오기!
  // 용도: HomeFeedScreen 전체를 채워줌
  Future<List<MeetupModel>> fetchHomeFeeds({
    int offset = 0,
    int limit = 5,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // === 수정한 내용: 탈퇴한 모임의 기록이 홈 피드에 다시 포함되지 않게 활성 소속만 조회한다 ===
    final memberData = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .timeout(const Duration(seconds: 20));
    final groupIds = memberData.map((e) => e['group_id']).toList();
    if (groupIds.isEmpty) return [];

    final feedsData = await _client
        .from('meetups')
        .select('*, groups(id, name, theme_emoji, theme_color, logo_image_url)')
        .inFilter('group_id', groupIds)
        .order('meet_date', ascending: false)
        // === 수정한 내용: 같은 날짜의 기록도 안정적으로 정렬하고 조회 무한 대기를 제한한다 ===
        .order('id', ascending: false)
        .range(offset, offset + limit - 1)
        .timeout(const Duration(seconds: 20));

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
    MeetupPlace? place,
    bool updatePlace = false,
    required List<dynamic> photos,
    required Set<String> memberIds,
  }) async {
    List<String> finalPhotos = [];
    final uploads = StorageUploads(_client);

    // 💡 사진이 String(기존 사진)이면 그대로 두고, XFile(새 사진)이면 스토리지에 올려서 URL을 뽑아냅니다. (순서 유지!)
    for (int i = 0; i < photos.length; i++) {
      final item = photos[i];
      if (item is String) {
        finalPhotos.add(item);
      } else if (item is XFile) {
        // === 수정한 내용: 새 사진의 크기와 MIME을 검증하고 실패한 업로드만 별도로 정리한다 ===
        finalPhotos.add(
          await uploads.upload('meetup_photos', item, prefix: '$groupId/'),
        );
      } else {
        await uploads.discard();
        throw ArgumentError('사진 파일을 확인해 주세요.');
      }
    }

    final meetupData = {
      'group_id': groupId,
      'title': title?.isNotEmpty == true ? title : null,
      'meet_date': meetDate,
      'location': location?.isNotEmpty == true ? location : null,
      'menu': menu?.isNotEmpty == true ? menu : null,
      'photos': finalPhotos,
      if (updatePlace || place != null) 'place': place?.toJson(),
    };

    // === 수정한 내용: 만남과 출석을 단일 RPC로 저장하고 실패 시 직접 쓰기로 우회하지 않는다 ===
    await uploads.commit(
      () => _client.rpc(
        updatePlace || place != null
            ? 'save_meetup_with_place_atomic'
            : 'save_meetup_atomic',
        params: {
          'p_meetup_id': meetupId,
          'p_meetup': meetupData,
          'p_member_ids': memberIds.toList(),
        },
      ),
    );
  }

  // 🌟 특정 기록 완전 삭제
  // === 수정한 내용: 편집 완료 뒤 상세 화면이 최신 제목과 출석을 다시 읽을 수 있게 한다 ===
  Future<MeetupModel> fetchMeetup(String meetupId) async {
    final data = await _client
        .from('meetups')
        .select('*, attendances(member_id)')
        .eq('id', meetupId)
        .single()
        .timeout(const Duration(seconds: 20));
    return MeetupModel.fromJson(data);
  }

  Future<void> deleteMeetup(String meetupId) async {
    // === 수정한 내용: RLS가 삭제를 0건으로 차단한 응답을 성공으로 오인하지 않는다 ===
    final deleted = await _client
        .from('meetups')
        .delete()
        .eq('id', meetupId)
        .select('id')
        .timeout(const Duration(seconds: 30));
    if (deleted.isEmpty) throw StateError('삭제 권한 또는 대상 상태를 확인해 주세요.');
  }

  // 🌟 특정 기록에 참석한 멤버 ID 목록만 가져오기
  // 용도: MeetupCreateScreen(수정 모드) 에서 누가 체크되어 있었는지 불러올 때
  Future<List<String>> fetchAttendances(String meetupId) async {
    final data = await _client
        .from('attendances')
        .select('member_id')
        .eq('meetup_id', meetupId)
        .timeout(const Duration(seconds: 20));
    return data.map((row) => row['member_id'].toString()).toList();
  }
}
