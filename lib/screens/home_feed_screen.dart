import 'package:flutter/material.dart';


// --- 홈(최근 만남) 화면 셋로그 감성 UI ---
class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모락 ☁️'),
      ),
      // 셋로그 감성: 배경과 카드가 구분되도록 리스트에 여백(Padding)을 줌
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: 3, // 일단 임시로 3개의 카드를 보여줌
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20), // 카드 사이의 간격
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24), // 둥기둥기 둥근 모서리
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03), // 아주아주 연한 그림자
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 날짜 & 모임 태그
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2026. 09. 1${index + 2}', // 임시 날짜
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A80).withOpacity(0.1), // 코랄 핑크 배경 (투명도 10%)
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '고딩 친구들', // 임시 모임 이름
                          style: TextStyle(
                            color: Color(0xFFFF8A80),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 중단: 메뉴/타이틀
                  Text(
                    '강남역 삼겹살 파티 🥩',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 하단: 장소 아이콘 & 텍스트
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '하남돼지집 강남점',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}