class GroupModel {
  final String id;
  final String name;
  final String themeEmoji;
  final String themeColor;

  GroupModel({
    required this.id,
    required this.name,
    required this.themeEmoji,
    required this.themeColor,
  });

  // Map(JSON) 데이터를 안전하게 객체로 바꿔주는 마법의 코드!
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '이름 없는 모임',
      themeEmoji: json['theme_emoji'] ?? '☁️',
      themeColor: json['theme_color'] ?? '#EEEEEE',
    );
  }
}