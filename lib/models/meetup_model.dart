import 'group_model.dart';
import 'member_model.dart';

class MeetupModel {
  final String id;
  final String groupId;
  // === 수정한 내용: 서버가 저장한 작성자와 탈퇴 상태로 작성자 표시·수정·삭제 권한을 판단한다 ===
  final String? authorMemberId;
  final String? authorName;
  final bool authorDeleted;
  String get authorLabel => authorDeleted ? '탈퇴한 멤버' : (authorName ?? '작성자 미상');
  bool canEdit(MemberModel? member) =>
      member != null &&
      member.isActive &&
      ((authorMemberId == member.id && !authorDeleted) ||
          ((authorDeleted || authorMemberId == null) && member.isManager));
  bool canDelete(MemberModel? member) =>
      member != null &&
      member.isActive &&
      (member.isManager || authorMemberId == member.id);
  final String? title;
  final String date;
  final String? location;
  final String? menu;
  final List<String> photos;
  final List<String> attendanceMemberIds;

  // 🌟 홈 피드에서 모임 이름을 띄우기 위해 GroupModel을 통째로 품게 만듭니다!
  final GroupModel? group;

  MeetupModel({
    required this.id,
    required this.groupId,
    this.authorMemberId,
    this.authorName,
    this.authorDeleted = false,
    this.title,
    required this.date,
    this.location,
    this.menu,
    required this.photos,
    required this.attendanceMemberIds,
    this.group,
  });

  factory MeetupModel.fromJson(Map<String, dynamic> json) {
    List<String> attendees = [];
    if (json['attendances'] != null) {
      attendees = (json['attendances'] as List)
          .map((att) => att['member_id'].toString())
          .toList();
    }

    return MeetupModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      authorMemberId: json['author_member_id']?.toString(),
      authorName: json['author_name'],
      authorDeleted: json['author_deleted'] == true,
      title: json['title'],
      date: json['meet_date'] ?? '',
      location: json['location'],
      menu: json['menu'],
      photos: List<String>.from(json['photos'] ?? []),
      attendanceMemberIds: attendees,
      group: json['groups'] != null
          ? GroupModel.fromJson(json['groups'])
          : null,
    );
  }
}
