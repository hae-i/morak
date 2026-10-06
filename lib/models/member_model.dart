class MemberModel {
  final String id;
  final String userId;
  final String displayName;
  final String role;
  // === 수정한 내용: 탈퇴 멤버는 출석 식별자를 유지하되 현재 멤버 권한에서 제외한다 ===
  final bool isDeleted;
  bool get isActive => !isDeleted;
  bool get isHost => isActive && role == 'host';
  bool get isManager => isActive && (role == 'host' || role == 'deputy');
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
    this.isDeleted = false,
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
      displayName: json['is_deleted'] == true
          ? '탈퇴한 멤버'
          : (json['display_name'] ?? '알 수 없음'),
      role: json['role'] ?? 'member',
      isDeleted: json['is_deleted'] == true,
      profileImageUrl: json['is_deleted'] == true
          ? null
          : json['profile_image_url'],
      isBirthdayPublic:
          json['is_deleted'] != true && (json['is_birthday_public'] ?? true),
      joinedAt: json['joined_at'],
      birthday: json['is_deleted'] != true && json['users'] != null
          ? json['users']['birthday']
          : null,
      attendedCount: json['attended_count'] ?? 0,
      attendanceRate: (json['attendance_rate'] ?? 0.0).toDouble(),
    );
  }
}
