import 'group_model.dart';

class MeetupModel {
  final String id;
  final String groupId;
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
