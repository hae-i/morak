class MemberModel {
  final String id;
  final String userId;
  final String displayName;
  final String role;
  final String? profileImageUrl;
  final bool isBirthdayPublic;
  final String? joinedAt;

  // 🌟 JOIN이나 통계로 계산되어 들어오는 데이터들
  final String? birthday;
  final int attendedCount;
  final double attendanceRate;

  MemberModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    this.profileImageUrl,
    required this.isBirthdayPublic,
    this.joinedAt,
    this.birthday,
    this.attendedCount = 0,
    this.attendanceRate = 0.0,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name'] ?? '알 수 없음',
      role: json['role'] ?? 'member',
      profileImageUrl: json['profile_image_url'],
      isBirthdayPublic: json['is_birthday_public'] ?? true,
      joinedAt: json['joined_at'],
      birthday: json['users'] != null ? json['users']['birthday'] : null,
      attendedCount: json['attended_count'] ?? 0,
      attendanceRate: (json['attendance_rate'] ?? 0.0).toDouble(),
    );
  }
}
