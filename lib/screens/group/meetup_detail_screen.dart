import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/meetup_model.dart';
import '../../models/member_model.dart';
import 'photo_viewer_screen.dart';

class MeetupDetailScreen extends StatelessWidget {
  final MeetupModel meetup;
  final List<MemberModel> groupMembers;
  final Color activeColor;

  const MeetupDetailScreen({
    super.key,
    required this.meetup,
    required this.groupMembers,
    required this.activeColor,
  });

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      meetup.location ?? '',
      meetup.menu ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');
    final photos = meetup.photos;
    final attendanceIds = meetup.attendanceMemberIds;
    final attendees = groupMembers
        .where((m) => attendanceIds.contains(m.id))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white, // 🌟 순백색
      appBar: AppBar(
        title: const Text(
          '만남 기록',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(meetup.date),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title.isNotEmpty ? title : '기록 내용 없음',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (attendees.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  '참석자 ${attendees.length}명',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36, // 🌟 Chip 높이 다이어트
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: attendees.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = attendees[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white, // 🌟 깔끔한 흰색 바탕에 얇은 테두리
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                        borderRadius: BorderRadius.circular(10), // 날렵하게!
                      ),
                      child: Center(
                        child: Text(
                          member.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (photos.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoViewerScreen(
                            imageUrls: photos,
                            initialIndex: index,
                            groupMembers: groupMembers,
                            activeColor: activeColor,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          10,
                        ), // 🌟 모서리 둥글기 세련되게
                        child: CachedNetworkImage(
                          imageUrl: photos[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 120,
                            color: Colors.grey[50],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black87,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 54,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '등록된 사진이 없어요.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
