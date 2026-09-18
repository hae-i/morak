import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // 🌟 24 -> 16 날렵하게
        border: Border.all(color: const Color(0xFFEEEEEE)), // 🌟 그림자 폭파! 얇은 선!
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
                            image: NetworkImage(group!.logoImageUrl!),
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
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
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
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 260, // 🌟 높이 다이어트
              placeholder: (context, url) => Container(
                height: 260,
                color: Colors.grey[50],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.black87,
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
                  color: Colors.black87,
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
                    color: Colors.black87,
                  ),
                  onPressed: onLike,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.black87,
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
