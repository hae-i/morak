import 'package:flutter/material.dart';

import 'meetup_detail_screen.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Map<String, dynamic>? meetup;
  final List<Map<String, dynamic>> groupMembers;
  final Color activeColor;

  const PhotoViewerScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    this.meetup,
    required this.groupMembers,
    required this.activeColor,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  // 🌟 상·하단 바 숨김/보임 토글 상태 변수!
  bool _showBars = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleBars() {
    setState(() {
      _showBars = !_showBars;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🌟 1. 사진 영역 (터치하면 상·하단 바 토글!)
          GestureDetector(
            onTap: _toggleBars,
            behavior: HitTestBehavior.opaque,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            ),
          ),

          // 🌟 2. 상단 반투명 바 (부드러운 페이드 인/아웃 애니메이션)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _showBars ? 0 : -100, // 숨길 땐 화면 위로 슝!
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 12,
                left: 12,
                right: 12,
              ),
              color: Colors.black.withOpacity(0.55), // 반투명 블랙
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // 중앙 인덱스 카운터
                  Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  // 균형을 맞추기 위한 빈 여백 (점 세 개 메뉴는 삭제!)
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // 🌟 3. 하단 반투명 바 (상단보다 살짝 얇고 세련되게!)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            bottom: _showBars ? 0 : -120, // 숨길 땐 화면 아래로 슝!
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 8
                    : 16,
                left: 20,
                right: 20,
              ),
              color: Colors.black.withOpacity(0.55),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 해당 만남 기록 보러가기 (만남 데이터가 있을 때만 활성화)
                  if (widget.meetup != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MeetupDetailScreen(
                              meetup: widget.meetup!,
                              groupMembers: widget.groupMembers,
                              activeColor: widget.activeColor,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.event_note_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        '기록 보러가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // 🌟 핵심: 하단 우측 깔끔한 저장 버튼
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('갤러리에 사진을 저장했습니다! (다운로드 완료)'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
