import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'feed/home_feed_screen.dart';
import 'group/my_group_screen.dart';
import 'profile/my_page_screen.dart';

class MainSkeleton extends StatefulWidget {
  const MainSkeleton({super.key});
  @override
  State<MainSkeleton> createState() => _MainSkeletonState();
}

class _MainSkeletonState extends State<MainSkeleton> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeFeedScreen(),
    const MyGroupScreen(),
    const MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // 가로 모드 감지 (600px 기준)
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    // 기존 폰 비율의 모바일 화면을 통째로 변수에
    Widget mobileView = Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: AppConstants.primaryColor,
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: '내 모임',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: '마이페이지',
          ),
        ],
      ),
    );

    // 🌟 넓은 화면일 때는 가로로 분할하여 렌더링합니다.
    if (isWideScreen) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            // 💡 원래 있던 앱 메인 화면을 우측에 꽉
            Expanded(child: mobileView),
            // 💡 추후 데스크탑/패드용 메뉴가 들어갈 빈 사이드바 공간
            Container(
              width: 280,
              color: Colors.grey[50],
              child: const Center(
                child: Text(
                  '메뉴 사이드바\n(준비 중 ☁️)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: Colors.grey[200]),
          ],
        ),
      );
    }

    // 좁은 화면은 그대로 렌더링
    return mobileView;
  }
}
