import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/group_model.dart';
import '../models/meetup_place.dart';
import '../models/member_model.dart';
import '../models/meetup_model.dart';
import '../models/group_detail_data.dart';
import '../utils/operation_id.dart';
import '../utils/paged_query.dart';
import '../utils/storage_uploads.dart';
import '../services/private_photos.dart';

class GroupRepository {
  // === 수정한 내용: 테스트용 클라이언트 주입으로 실제 서버 없이 실패 흐름을 검증한다 ===
  GroupRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<PlaceHistory> fetchPlaceHistory(String groupId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return PlaceHistory([]);
    final rows = await readAllRows(
      (offset, size) => _client
          .from('meetups')
          .select('id,title,meet_date,place')
          .eq('group_id', groupId)
          .not('place', 'is', null)
          .order('meet_date', ascending: false)
          .order('id')
          .range(offset, offset + size - 1)
          .count(CountOption.exact),
    );
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('Session changed');
    }
    return PlaceHistory(
      rows.map(
        (row) => PlaceVisit(
          meetupId: row['id'].toString(),
          title: row['title'] as String? ?? '함께한 만남',
          date: row['meet_date'] as String? ?? '',
          place: MeetupPlace.fromJson(
            Map<String, dynamic>.from(row['place'] as Map),
          ),
        ),
      ),
    );
  }

  // === 수정한 내용: 조회 제한 시간을 유지하며 탈퇴 멤버십을 현재 소속으로 취급하지 않는다 ===
  Future<Map<String, dynamic>?> fetchMyMembership(String groupId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
  }

  Future<String> fetchGroupName(String groupId) async {
    // === 수정한 내용: 소속 제한 RLS에서도 초대 수신자가 모임 이름만 미리 확인할 수 있게 한다 ===
    try {
      final name = await _client
          .rpc('get_group_invite_name', params: {'p_group_id': groupId})
          .timeout(const Duration(seconds: 20));
      if (name is! String || name.trim().isEmpty) {
        throw const FormatException('Invalid group name');
      }
      return name;
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
    }
    final group = await _client
        .from('groups')
        .select('name')
        .eq('id', groupId)
        .single()
        .timeout(const Duration(seconds: 20));
    return group['name'] as String;
  }

  // 🌟 내가 가입한 모든 모임 목록 가져오기
  // 용도: MyGroupScreen (내 모임 탭) 리스트 뿌려줄 때
  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 내가 속한 멤버 정보와, 그 그룹 정보(groups)를 통째로 가져옴!
    final data = await readAllRows(
      (offset, size) => _client
          .from('group_members')
          .select('role, joined_at, groups (*)')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('joined_at', ascending: false)
          .order('id')
          .range(offset, offset + size - 1)
          .count(CountOption.exact),
    );

    return data
        .where((json) => json['groups'] is Map<String, dynamic>)
        .map(
          (json) => {
            'group': GroupModel.fromJson(json['groups']),
            'role': json['role'],
          },
        )
        .toList();
  }

  // === 수정한 내용: 기존 Map API를 유지하고 새 상태 객체에는 타입이 있는 상세 결과를 제공한다 ===
  Future<GroupDetailData> fetchGroupDetail(String groupId) async =>
      GroupDetailData.fromRepositoryMap(
        await fetchGroupDetailWithRanking(groupId),
      );

  // 🌟 모임 상세 정보(그룹정보, 만남기록, 멤버랭킹) 한 번에 싹 다 가져오기
  // 용도: GroupDetailScreen 에 진입할 때 데이터를 쫙 깔아줌
  Future<Map<String, dynamic>> fetchGroupDetailWithRanking(
    String groupId,
  ) async {
    // === 수정한 내용: 추가 조회 RPC가 적용된 DB는 서버 통계와 첫 페이지만 받고 기존 DB는 기존 흐름을 유지한다 ===
    try {
      final summary = await _client
          .rpc('get_group_summary', params: {'p_group_id': groupId})
          .timeout(const Duration(seconds: 20));
      if (summary is! Map<String, dynamic> ||
          summary['group'] is! Map<String, dynamic> ||
          summary['rankedMembers'] is! List ||
          summary['totalMeetups'] is! num) {
        throw const FormatException('Invalid group summary');
      }
      final page = await fetchMeetupPage(groupId);
      if (page.isEmpty && (summary['totalMeetups'] as num) > 0) {
        throw const FormatException('Group records unavailable');
      }
      return {
        'group': GroupModel.fromJson(summary['group']),
        'rankedMembers': (summary['rankedMembers'] as List)
            .map((row) => MemberModel.fromJson(row as Map<String, dynamic>))
            .toList(),
        'meetups': page,
        'totalMeetups': (summary['totalMeetups'] as num).toInt(),
        'paged': true,
      };
    } on PostgrestException catch (error) {
      // 함수가 없는 구 DB만 호환 처리합니다. 인증/권한/네트워크 실패를 우회하지 않습니다.
      if (error.code != 'PGRST202') rethrow;
    }
    final groupRes = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .single()
        .timeout(const Duration(seconds: 20));
    final meetupsRes = await readAllRows(
      (offset, size) => _client
          .from('meetups')
          .select('*, attendances(member_id)')
          .eq('group_id', groupId)
          .order('meet_date', ascending: false)
          .order('id')
          .range(offset, offset + size - 1)
          .count(CountOption.exact),
    );
    final membersRes = await readAllRows(
      (offset, size) => _client
          .from('group_members')
          .select('*, users(birthday)')
          .eq('group_id', groupId)
          .order('joined_at', ascending: true)
          .order('id')
          .range(offset, offset + size - 1)
          .count(CountOption.exact),
    );

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
      'totalMeetups': totalMeetups,
      'paged': false,
    };
  }

  // === 수정한 내용: 기록과 사진은 실제로 필요한 페이지 단위로 읽어 대규모 앨범의 최초 로딩을 줄인다 ===
  Future<List<MeetupModel>> fetchMeetupPage(
    String groupId, {
    int offset = 0,
    int limit = 40,
  }) async {
    final rows = await _client
        .from('meetups')
        .select('*, attendances(member_id)')
        .eq('group_id', groupId)
        .order('meet_date', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1)
        .timeout(const Duration(seconds: 20));
    return rows.map(MeetupModel.fromJson).toList();
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
    String? requestId,
    XFile? memberImage,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) throw '로그인 정보가 없습니다.';
    if (name.trim().isEmpty || nickname.trim().isEmpty) {
      throw ArgumentError('이름을 입력해 주세요.');
    }
    String? coverUrl, logoUrl;
    final uploads = StorageUploads(_client);

    // 커버 사진 업로드
    if (coverImage != null) {
      coverUrl = await uploads.upload(
        'group_covers',
        coverImage,
        prefix: 'cover_',
      );
    }
    // 로고 이미지 업로드
    if (logoImage != null) {
      logoUrl = await uploads.upload(
        'group_covers',
        logoImage,
        prefix: 'logo_',
      );
    }
    final memberUrl = memberImage == null
        ? profileImageUrl
        : await uploads.upload(
            'profiles',
            memberImage,
            prefix: 'avatars/${currentUser.id}_',
          );

    // === 수정한 내용: 그룹과 최초 방장을 한 RPC로 저장하여 방장 없는 그룹 생성을 방지한다 ===
    if (_client.auth.currentUser?.id != currentUser.id) {
      throw StateError('로그인 계정이 변경되었습니다.');
    }
    final result = await uploads.commit(
      () => _client.rpc(
        'create_group_atomic',
        params: {
          'p_group_id': requestId ?? newOperationId(),
          'p_group': {
            'name': name,
            'theme_color': hexColor,
            'theme_emoji': emoji,
            'cover_image_url': coverUrl,
            'logo_image_url': logoUrl,
          },
          'p_member': {
            'display_name': nickname,
            'profile_image_url': memberUrl,
            'is_birthday_public': isBirthdayPublic,
          },
        },
      ),
    );
    // === 수정한 내용: 응답 유실 후 같은 요청을 재시도한 경우 새로 올린 미사용 파일을 정리한다 ===
    if (result is Map && result['created'] == false) await uploads.discard();
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
    if (name.trim().isEmpty) throw ArgumentError('모임 이름을 입력해 주세요.');
    String? finalCoverUrl = existingCoverUrl;
    String? finalLogoUrl = existingLogoUrl;
    final uploads = StorageUploads(_client);

    if (newCoverImage != null) {
      finalCoverUrl = await uploads.upload(
        'group_covers',
        newCoverImage,
        prefix: 'cover_${groupId}_',
      );
    }
    if (newLogoImage != null) {
      finalLogoUrl = await uploads.upload(
        'group_covers',
        newLogoImage,
        prefix: 'logo_${groupId}_',
      );
    }

    await uploads.commit(
      () => _client
          .from('groups')
          .update({
            'name': name,
            'theme_color': hexColor,
            'theme_emoji': emoji,
            'cover_image_url': finalCoverUrl,
            'logo_image_url': finalLogoUrl,
          })
          .eq('id', groupId),
    );
  }

  // 🌟 모임 완전 삭제 (기록들도 싹 다 날아감)
  Future<void> deleteGroup(String groupId) async {
    // === 수정한 내용: RLS가 삭제를 0건으로 차단한 응답을 성공으로 오인하지 않는다 ===
    final deleted = await _client
        .from('groups')
        .delete()
        .eq('id', groupId)
        .select('id')
        .timeout(const Duration(seconds: 30));
    if (deleted.isEmpty) throw StateError('삭제 권한 또는 대상 상태를 확인해 주세요.');
  }

  // 🌟 특정 모임의 모든 멤버 목록 가져오기 (만남 기록 남길 때 참석자 체크용)
  Future<List<MemberModel>> fetchGroupMembers(String groupId) async {
    final data = await readAllRows(
      (offset, size) => _client
          .from('group_members')
          .select()
          .eq('group_id', groupId)
          .order('joined_at', ascending: true)
          .order('id')
          .range(offset, offset + size - 1)
          .count(CountOption.exact),
    );
    return data.map((m) => MemberModel.fromJson(m)).toList();
  }

  // 🌟 모임 서랍장에서 수동으로 새 멤버 추가하기
  Future<void> addMember(String groupId, String displayName) async {
    if (displayName.trim().isEmpty) throw ArgumentError('이름을 입력해 주세요.');
    await _client
        .from('group_members')
        .insert({'group_id': groupId, 'display_name': displayName})
        .timeout(const Duration(seconds: 30));
  }

  // 🌟 모임 서랍장에서 멤버 강퇴/내보내기
  // === 수정한 내용: 모임 탈퇴는 본인과 방장 위임 여부를 서버에서 확인하는 RPC만 사용한다 ===
  Future<void> leaveGroup(String groupId) async {
    await _client
        .rpc('leave_group', params: {'p_group_id': groupId})
        .timeout(const Duration(seconds: 30));
    PrivatePhotos.invalidate();
  }

  // === 수정한 내용: 방장 위임은 상대 승급과 본인 강등을 단일 서버 트랜잭션에서 처리한다 ===
  Future<void> transferHost(String groupId, String memberId) async {
    await _client
        .rpc(
          'transfer_group_host',
          params: {'p_group_id': groupId, 'p_member_id': memberId},
        )
        .timeout(const Duration(seconds: 30));
  }

  Future<void> removeMember(String memberId) async {
    // === 수정한 내용: 내보내기는 서버 권한 확인 후 비활성화하여 기존 출석·작성 글을 보존한다 ===
    await _client
        .rpc('remove_group_member', params: {'p_member_id': memberId})
        .timeout(const Duration(seconds: 30));
  }

  // 🌟 모임 서랍장에서 멤버 등급(방장/일반) 변경
  Future<void> updateMemberRole(String memberId, String newRole) async {
    if (newRole != 'host' && newRole != 'member' && newRole != 'deputy') {
      throw ArgumentError('멤버 권한을 확인해 주세요.');
    }
    // === 수정한 내용: 역할 변경도 실제 변경된 행이 있을 때만 성공으로 처리한다 ===
    final changed = await _client
        .from('group_members')
        .update({'role': newRole})
        .eq('id', memberId)
        .select('id')
        .timeout(const Duration(seconds: 30));
    if (changed.isEmpty) throw StateError('관리 권한 또는 멤버 상태를 확인해 주세요.');
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
    if (displayName.trim().isEmpty) throw ArgumentError('닉네임을 입력해 주세요.');
    final uploads = StorageUploads(_client);
    if (newImageFile != null) {
      finalImageUrl = await uploads.upload(
        'profiles',
        newImageFile,
        prefix: 'avatars/group_${memberId}_',
      );
    }
    await uploads.commit(
      () => _client
          .from('group_members')
          .update({
            'display_name': displayName,
            'is_birthday_public': isBirthdayPublic,
            // === 수정한 내용: 멤버 프로필 사진 삭제도 null 업데이트로 DB에 반영한다 ===
            'profile_image_url': finalImageUrl,
          })
          .eq('id', memberId),
    );
  }

  // 🌟 초대 링크를 타고 모임에 새 멤버로 가입하기
  Future<void> joinGroup({
    required String groupId,
    required String nickname,
    String? profileImageUrl,
    bool isBirthdayPublic = true,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw '로그인 정보가 없습니다.';
    if (groupId.trim().isEmpty || nickname.trim().isEmpty) {
      throw ArgumentError('가입 정보를 확인해 주세요.');
    }

    // === 수정한 내용: 재가입은 기존 출석·작성자 식별자를 유지하며 서버가 일반 멤버로 복구한다 ===
    await _client
        .rpc(
          'join_group',
          params: {
            'p_group_id': groupId,
            'p_display_name': nickname,
            'p_profile_image_url': profileImageUrl,
            'p_is_birthday_public': isBirthdayPublic,
          },
        )
        .timeout(const Duration(seconds: 30));
  }
}
