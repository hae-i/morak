import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/meetup_model.dart';
import '../../models/meetup_place.dart';
import '../maps/places_map.dart';
import '../../models/member_model.dart';
import '../../services/private_photos.dart';
import '../../utils/naver_place_link.dart';

/// A record is a story first; the full photo collection opens in the viewer.
class MeetupStory extends StatelessWidget {
  final MeetupModel meetup;
  final List<MemberModel> members;
  final VoidCallback onOpenPhotos;

  const MeetupStory({
    super.key,
    required this.meetup,
    required this.members,
    required this.onOpenPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceIds = meetup.attendanceMemberIds.toSet();
    final attendees = members
        .where((m) => attendanceIds.contains(m.id))
        .toList();
    final knownIds = attendees.map((m) => m.id).toSet();
    final historicalCount = attendanceIds.difference(knownIds).length;
    final location = meetup.location?.trim() ?? '';
    final menu = meetup.menu?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppConstants.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '그날의 조각들',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                _detail(
                  Icons.place_outlined,
                  '만난 곳',
                  location.isEmpty ? '장소를 남기지 않았어요' : location,
                ),
                if (location.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => openNaverPlaceSearch(context, location),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('네이버 지도에서 장소 찾기'),
                  ),
                const SizedBox(height: 20),
                _detail(
                  Icons.restaurant_rounded,
                  '함께 먹은 것',
                  menu.isEmpty ? '메뉴를 남기지 않았어요' : menu,
                ),
                const SizedBox(height: 20),
                _detail(
                  Icons.people_outline_rounded,
                  '함께한 사람들',
                  attendanceIds.isEmpty
                      ? '참석 기록이 없어요'
                      : '${attendanceIds.length}명이 함께한 만남',
                ),
                if (attendees.isNotEmpty || historicalCount > 0) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in attendees)
                        Chip(
                          avatar: Icon(
                            member.isActive
                                ? Icons.person_outline
                                : Icons.history_rounded,
                            size: 18,
                          ),
                          label: Text(
                            member.isActive ? member.displayName : '탈퇴한 멤버',
                          ),
                          backgroundColor: AppConstants.scaffoldBackground,
                          side: BorderSide.none,
                        ),
                      if (historicalCount > 0)
                        Chip(label: Text('이전 참석 기록 $historicalCount명')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (meetup.place != null) ...[
            const Text(
              '우리의 만남 장소',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 220,
                child: PlacesMap(
                  pins: [PlacePin(place: meetup.place!, visits: [])],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              meetup.place!.address,
              style: const TextStyle(
                color: AppConstants.textBody,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (meetup.photos.isNotEmpty) ...[
            const Text(
              '이날을 기억하는 한 장',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: '만남 사진 ${meetup.photos.length}장 보기',
              child: InkWell(
                onTap: onOpenPhotos,
                borderRadius: BorderRadius.circular(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: PrivatePhotoImage(
                      imageUrl: meetup.photos.first,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ColoredBox(
                        color: AppConstants.secondaryColor,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: AppConstants.secondaryColor,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenPhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('이날의 사진 ${meetup.photos.length}장 보기'),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConstants.secondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 36,
                    color: AppConstants.primaryColor,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '사진이 없어도 소중한 만남이에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '함께한 사람과 장소가 이날의 추억으로 남아요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppConstants.textBody, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppConstants.primaryColor, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textBody,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
