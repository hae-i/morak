import 'package:flutter/material.dart';

import 'feed/home_feed_screen.dart';
import 'group/my_group_screen.dart';
import 'profile/my_page_screen.dart';

// 상태(선택된 탭) 변화가 있는 메인 뼈대 화면
class MainSkeleton extends StatefulWidget {
  const MainSkeleton({super.key});

  @override
  State<MainSkeleton> createState() => _MainSkeletonState();
}

class _MainSkeletonState extends State<MainSkeleton> {
  // 현재 선택된 탭의 인덱스 (기본값 0: 홈)
  int _currentIndex = 0;

  // 탭별로 보여줄 화면들을 리스트로 관리
  final List<Widget> _pages = [
    const HomeFeedScreen(),   // 탭 1: 홈
    const MyGroupScreen(),    // 탭 2: 내 모임
    const MyPageScreen(),     // 탭 3: 마이페이지
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: 탭을 전환해도 이전 화면의 상태(스크롤 위치 등)를 그대로 유지해 줌!
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // 하단 탭 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // 탭을 누르면 화면을 다시 그리도록 상태(Index) 업데이트
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white, // 탭바 배경은 깔끔한 흰색으로 분리감 주기
        selectedItemColor: const Color(0xFFFF8A80), // 감성 포인트 4: 소프트 코랄 핑크 🌸
        unselectedItemColor: Colors.grey[400], // 선택 안 된 탭은 연한 회색
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // 탭이 움직이지 않고 고정되도록 설정
        elevation: 10, // 탭바 위쪽에만 살짝 그림자를 줘서 본문과 구분

        // 3개의 탭 아이템 정의
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: '홈',
          ),
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