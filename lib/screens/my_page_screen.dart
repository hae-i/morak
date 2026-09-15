import 'package:flutter/material.dart';


// --- 마이페이지 (프로필 및 설정) 화면 ---
class MyPageScreen extends StatelessWidget {
  const MyPageScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지 👤')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. 프로필 섹션
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
                  child: Icon(Icons.person_rounded, size: 36, color: Colors.grey[300]),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지은 님, 반가워요! 👋',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '모락과 함께한 지 1일째',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 2. 메뉴 섹션
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
          _buildMenuTile(Icons.notifications_none_rounded, '알림 설정'),
          _buildMenuTile(Icons.lock_outline_rounded, '개인정보 보호'),
          _buildMenuTile(Icons.help_outline_rounded, '고객센터 / 피드백'),
          _buildMenuTile(Icons.logout_rounded, '로그아웃', isDestructive: true),
        ],
      ),
    );
  }

  // 마이페이지 메뉴 항목을 쉽게 만들기 위한 함수
  Widget _buildMenuTile(IconData icon, String title, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red[300] : Colors.grey[600]),
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
        onTap: () {
          // 나중에 메뉴 클릭 시 이동할 기능 연결
        },
      ),
    );
  }
}