class GroupModel {
  final String id;
  final String name;
  final String? themeEmoji;
  final String? themeColor;
  final String? coverImageUrl;
  final String? logoImageUrl;

  GroupModel({
    required this.id,
    required this.name,
    this.themeEmoji,
    this.themeColor,
    this.coverImageUrl,
    this.logoImageUrl,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '이름 없는 모임',
      themeEmoji: json['theme_emoji'],
      themeColor: json['theme_color'],
      coverImageUrl: json['cover_image_url'],
      logoImageUrl: json['logo_image_url'],
    );
  }
}
