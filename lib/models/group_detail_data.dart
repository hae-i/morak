import 'group_model.dart';
import 'meetup_model.dart';
import 'member_model.dart';

// === 수정한 내용: 상세 조회 결과를 타입으로 묶어 화면의 문자열 키와 dynamic 의존을 줄인다 ===
class GroupDetailData {
  final GroupModel group;
  final List<MeetupModel> meetups;
  final List<MemberModel> rankedMembers;
  final int totalMeetups;
  final bool paged;

  GroupDetailData({
    required this.group,
    required List<MeetupModel> meetups,
    required List<MemberModel> rankedMembers,
    required this.totalMeetups,
    required this.paged,
  }) : meetups = List.unmodifiable(meetups),
       rankedMembers = List.unmodifiable(rankedMembers);

  // 기존 Repository API와 이를 재정의한 테스트/호출자는 그대로 유지합니다.
  factory GroupDetailData.fromRepositoryMap(Map<String, dynamic> data) {
    final meetups = List<MeetupModel>.from(data['meetups'] as List);
    return GroupDetailData(
      group: data['group'] as GroupModel,
      meetups: meetups,
      rankedMembers: List<MemberModel>.from(data['rankedMembers'] as List),
      totalMeetups: data['totalMeetups'] as int? ?? meetups.length,
      paged: data['paged'] == true,
    );
  }
}

// === 수정한 내용: 앨범 사진과 원본 기록을 명시적으로 연결하여 문자열 키 형변환을 제거한다 ===
class AlbumPhoto {
  final String url;
  final MeetupModel meetup;
  const AlbumPhoto({required this.url, required this.meetup});
}
