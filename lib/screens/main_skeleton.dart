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
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        // 🌟 하드코딩된 색상을 AppConstants.primaryColor 로 교체!
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
  }
}
