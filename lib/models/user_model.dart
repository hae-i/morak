class UserModel {
  final String id;
  final String displayName;
  final String role; // 'host' or 'member'
  final String? profileImageUrl;

  UserModel({
    required this.id,
    required this.displayName,
    required this.role,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id']?.toString() ?? '',
      displayName: json['display_name'] ?? '알 수 없음',
      role: json['role'] ?? 'member',
      profileImageUrl: json['profile_image_url'],
    );
  }
}