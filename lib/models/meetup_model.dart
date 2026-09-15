class MeetupModel {
  final String id;
  final String groupId;
  final String authorName;
  final String date;
  final String? place;
  final String? menu;
  final List<String> photos; // 사진 URL들
  final String content;

  MeetupModel({
    required this.id, required this.groupId, required this.authorName,
    required this.date, this.place, this.menu,
    required this.photos, required this.content,
  });

  factory MeetupModel.fromJson(Map<String, dynamic> json) {
    return MeetupModel(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      authorName: json['author_name'] ?? '익명',
      date: json['meeting_date'] ?? '',
      place: json['place'],
      menu: json['menu'],
      photos: List<String>.from(json['photos'] ?? []),
      content: json['content'] ?? '',
    );
  }
}