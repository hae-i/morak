import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '만남 기록',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title.isNotEmpty ? title : '기록 내용 없음',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey[800],
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
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: attendees.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final member = attendees[index];
                    return Chip(
                      label: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.grey[100],
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (photos.isNotEmpty) ...[
              const Divider(height: 1, color: Colors.black12),
              Padding(
                padding: const EdgeInsets.all(12.0),
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
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(photos[index], fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '등록된 사진이 없어요.',
                      style: TextStyle(color: Colors.grey[400]),
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
