import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'home/home_screen.dart';
import 'group/my_group_screen.dart';
import 'profile/my_page_screen.dart';

class MainSkeleton extends StatefulWidget {
  const MainSkeleton({super.key});
  @override
  State<MainSkeleton> createState() => _MainSkeletonState();
}

// 🌟 1. 애니메이션을 사용하기 위해 SingleTickerProviderStateMixin을 추가
class _MainSkeletonState extends State<MainSkeleton>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // === 수정한 내용: 사이드바와 하단 메뉴가 같은 탭 상태를 사용하여 기존 화면과 데이터를 유지한다 ===
  void _selectTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _fadeController.forward(from: 0.0);
  }

  // 🌟 2. 화면 전환(페이드) 애니메이션 컨트롤러 선언
  late AnimationController _fadeController;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [const HomeScreen(), const MyGroupScreen(), const MyPageScreen()];
    // 🌟 3. 컨트롤러 초기화 (0.25초 동안 스르륵 나타나게 설정)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeController.forward(); // 첫 화면 로드 시 실행
  }

  @override
  void dispose() {
    _fadeController.dispose(); // 🌟 4. 메모리 누수 방지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    Widget mobileView = Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,

      // 🌟 5. 기존 IndexedStack을 FadeTransition으로 감싸줍니다.
      body: FadeTransition(
        opacity: _fadeController,
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppConstants.cardBackground,
          border: Border(
            top: BorderSide(color: AppConstants.borderColor, width: 1),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            // === 수정한 내용: 기본 테마의 선택/비선택 글자 크기 차이를 없애고 라벨 스타일을 고정한다 ===
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            currentIndex: _currentIndex,
            onTap: _selectTab,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppConstants.primaryColor,
            unselectedItemColor: AppConstants.textCaption,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
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
        ),
      ),
    );

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: AppConstants.scaffoldBackground,
        body: Row(
          children: [
            Expanded(child: mobileView),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppConstants.borderColor,
            ),
            Container(
              width: 280,
              color: AppConstants.cardBackground,
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      for (final (index, icon, label) in [
                        (0, Icons.home_filled, '홈'),
                        (1, Icons.folder_rounded, '내 모임'),
                        (2, Icons.person_rounded, '마이페이지'),
                      ])
                        ListTile(
                          leading: Icon(icon),
                          title: Text(label),
                          selected: _currentIndex == index,
                          selectedColor: AppConstants.primaryColor,
                          onTap: () => _selectTab(index),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return mobileView;
  }
}

/*
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'home/home_screen.dart';
import 'group/my_group_screen.dart';
import 'profile/my_page_screen.dart';

class MainSkeleton extends StatefulWidget {
  const MainSkeleton({super.key});
  @override
  State<MainSkeleton> createState() => _MainSkeletonState();
}

class _MainSkeletonState extends State<MainSkeleton> {
  int _currentIndex = 0;

  // 🌟 1. 애니메이션 컨트롤러 대신 페이지(화면) 전용 컨트롤러를 사용합니다.
  late PageController _pageController;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MyGroupScreen(),
    const MyPageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 🌟 2. 컨트롤러 초기화
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose(); // 메모리 누수 방지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    Widget mobileView = Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,

      // 🌟 3. IndexedStack 대신 PageView를 배치합니다.
      body: PageView(
        controller: _pageController,
        // 손가락으로 화면을 밀었을 때 하단바 탭 번호도 같이 바뀌도록 동기화
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        physics: const BouncingScrollPhysics(), // 튕기는 듯한 쫀득한 스크롤 효과
        children: _pages,
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppConstants.cardBackground,
          border: Border(
            top: BorderSide(color: AppConstants.borderColor, width: 1),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (_currentIndex != index) {
                // 🌟 4. 하단바를 눌렀을 때 해당 페이지로 스르륵(Slide) 이동시킵니다.
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              }
            },
            backgroundColor: Colors.transparent,
            selectedItemColor: AppConstants.primaryColor,
            unselectedItemColor: AppConstants.textCaption,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
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
        ),
      ),
    );

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: AppConstants.scaffoldBackground,
        body: Row(
          children: [
            Expanded(child: mobileView),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppConstants.borderColor,
            ),
            Container(
              width: 280,
              color: AppConstants.cardBackground,
              child: const Center(
                child: Text(
                  '메뉴 사이드바\n(준비 중 ☁️)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppConstants.textCaption,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return mobileView;
  }
}

* */
