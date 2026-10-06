// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';

import '../../constants/app_constants.dart'; // 🌟 추가
import '../../utils/color_utils.dart';
import '../../models/meetup_model.dart';

class FeedCard extends StatelessWidget {
  final MeetupModel feed;
  final VoidCallback onLike;

  const FeedCard({super.key, required this.feed, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final group = feed.group;
    final groupName = group?.name ?? '알 수 없는 모임';
    final emoji = group?.themeEmoji ?? '☁️';
    final themeColor = ColorUtils.stringToColor(group?.themeColor);

    final rawDate = feed.date;
    String formattedDate = '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        formattedDate =
            '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        formattedDate = rawDate;
      }
    }

    final location = feed.location ?? '';
    final menu = feed.menu ?? '';
    final content = [location, menu].where((s) => s.isNotEmpty).join(' · ');
    final photos = feed.photos;
    final imageUrl = photos.isNotEmpty ? photos.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground, // 🌟 교체
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderColor), // 🌟 교체
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    image: group?.logoImageUrl != null
                        ? DecorationImage(
                            image: privatePhoto(group!.logoImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: group?.logoImageUrl == null
                      ? Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        )
                      : null,
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
                          fontSize: 15,
                          color: AppConstants.textTitle, // 🌟 교체
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // === 수정한 내용: 홈 피드에도 서버가 정한 작성자를 표시한다 ===
                        '$formattedDate · ${feed.authorLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppConstants.textCaption, // 🌟 교체
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppConstants.textCaption, // 🌟 교체
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          if (imageUrl != null)
            PrivatePhotoImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 260,
              placeholder: (context, url) => Container(
                height: 260,
                color: AppConstants.dividerColor, // 🌟 교체
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor, // 🌟 교체
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppConstants.textBody, // 🌟 교체
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.favorite_border_rounded,
                    color: AppConstants.textTitle, // 🌟 교체
                  ),
                  onPressed: onLike,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppConstants.textTitle, // 🌟 교체
                  ),
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
