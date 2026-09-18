class UserModel {
  final String id;
  final String displayName;
  final String? profileImageUrl;
  final String? birthday;

  UserModel({
    required this.id,
    required this.displayName,
    this.profileImageUrl,
    this.birthday,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name'] ?? '알 수 없음',
      profileImageUrl: json['profile_image_url'],
      birthday: json['birthday'],
    );
  }
}
