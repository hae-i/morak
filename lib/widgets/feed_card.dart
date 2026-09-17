import 'package:flutter/material.dart';

import '../utils/color_utils.dart';

class FeedCard extends StatelessWidget {
  final Map<String, dynamic> feed;
  final VoidCallback onLike;

  const FeedCard({super.key, required this.feed, required this.onLike});

  @override
  Widget build(BuildContext context) {
    // 1. 모임 정보 빼오기
    final group = feed['groups'] ?? {};
    final groupName = group['name'] ?? '알 수 없는 모임';
    final emoji = group['theme_emoji'] ?? '☁️';
    final themeColor = ColorUtils.stringToColor(group['theme_color']);

    // 2. 날짜 & 텍스트 포맷팅
    final rawDate = feed['meet_date'];
    String formattedDate = '';
    if (rawDate != null) {
      final dt = DateTime.parse(rawDate);
      formattedDate =
          '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }

    final location = feed['location'] ?? '';
    final menu = feed['menu'] ?? '';
    final content = [location, menu].where((s) => s.isNotEmpty).join(' · ');

    // 3. 사진 유무 확인
    final photos = feed['photos'] as List<dynamic>? ?? [];
    final imageUrl = photos.isNotEmpty ? photos.first.toString() : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💡 상단 헤더 (모임 이모지, 이름, 날짜)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.grey,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // 💡 메인 사진 (사진을 올렸을 경우에만 꽉 차게 표시!)
          if (imageUrl != null)
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
            ),

          // 💡 텍스트 본문 (장소 & 메뉴)
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                content,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          // 💡 하단 액션 바 (좋아요 등)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded),
                  onPressed: onLike,
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
