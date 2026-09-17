import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // 🌟 메이슨리 패키지 임포트!

import '../../utils/color_utils.dart';

class MeetupDetailScreen extends StatelessWidget {
  final Map<String, dynamic> meetup;
  final List<Map<String, dynamic>> groupMembers;
  final Color activeColor;

  const MeetupDetailScreen({
    super.key,
    required this.meetup,
    required this.groupMembers,
    required this.activeColor,
  });

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return '${dt.year}년 ${dt.month}월 ${dt.day}일';
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      meetup['location'] ?? '',
      meetup['menu'] ?? '',
    ].where((s) => s.toString().isNotEmpty).join(' · ');

    final photos = meetup['photos'] as List<dynamic>? ?? [];

    final attendanceIds = (meetup['attendances'] as List<dynamic>? ?? [])
        .map((att) => att['member_id'].toString())
        .toList();

    final attendees = groupMembers
        .where((m) => attendanceIds.contains(m['id'].toString()))
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
                    _formatDate(meetup['meet_date']),
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                        member['display_name'],
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

            // 🌟 3. 구글 이미지/핀터레스트 스타일의 메이슨리 그리드 뷰!
            if (photos.isNotEmpty) ...[
              const Divider(height: 1, color: Colors.black12),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: MasonryGridView.count(
                  crossAxisCount: 2, // 2열로 배치
                  mainAxisSpacing: 8, // 세로 간격
                  crossAxisSpacing: 8, // 가로 간격
                  shrinkWrap: true, // 스크롤 뷰 안에 넣기 위해 필수
                  physics: const NeverScrollableScrollPhysics(), // 부모의 스크롤을 따름
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12), // 모서리 둥글게!
                      child: Image.network(
                        photos[index].toString(),
                        fit: BoxFit.cover, // 원본 비율을 유지하며 예쁘게 채움
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
