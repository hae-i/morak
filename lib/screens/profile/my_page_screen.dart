import 'package:flutter/material.dart';

import '../../utils/ui_utils.dart';
import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import 'profile_edit_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});
  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  UserModel? _myProfile;
  final _userRepo = UserRepository();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userRepo.fetchMyGlobalProfile();
    if (mounted) setState(() => _myProfile = profile);
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '로그아웃',
      content: '정말 로그아웃 하시겠습니까?\n언제든 다시 돌아오실 수 있어요.',
      confirmText: '로그아웃',
      confirmColor: Colors.redAccent,
      icon: Icons.logout_rounded,
    );
    if (confirm == true) await _userRepo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _myProfile?.displayName ?? '로딩중...';
    final profileUrl = _myProfile?.profileImageUrl;
    final birthday = _myProfile?.birthday;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '마이페이지 👤',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: profileUrl != null
                      ? NetworkImage(profileUrl)
                      : null,
                  child: profileUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$nickname 님, 반가워요! 👋',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        birthday != null
                            ? '🎂 생일: ${birthday.replaceAll('-', '. ')}'
                            : '생일 정보를 등록해주세요!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              '내 계정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
          ),
          _buildMenuTile(
            Icons.manage_accounts_rounded,
            '프로필 편집',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileEditScreen(),
                ),
              );
              if (result == true) _loadUserProfile();
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              '설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
          ),
          _buildMenuTile(
            Icons.notifications_none_rounded,
            '알림 설정',
            onTap: () {},
          ),
          _buildMenuTile(Icons.lock_outline_rounded, '개인정보 보호', onTap: () {}),
          _buildMenuTile(
            Icons.help_outline_rounded,
            '고객센터 / 피드백',
            onTap: () {},
          ),
          _buildMenuTile(
            Icons.logout_rounded,
            '로그아웃',
            isDestructive: true,
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red[300] : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red[400] : Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}
