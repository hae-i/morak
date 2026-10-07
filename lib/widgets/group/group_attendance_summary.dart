import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/member_model.dart';

class GroupAttendanceSummary extends StatelessWidget {
  final List<MemberModel> members;
  final int totalMeetups;
  final Future<void> Function() onRefresh;

  const GroupAttendanceSummary({
    super.key,
    required this.members,
    required this.totalMeetups,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final activeMembers = members.where((member) => member.isActive).toList()
      ..sort((a, b) {
        final result = b.attendedCount.compareTo(a.attendedCount);
        return result != 0 ? result : a.displayName.compareTo(b.displayName);
      });
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            '함께 쌓은 시간',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '만남 $totalMeetups번 · 현재 멤버 ${activeMembers.length}명',
            style: const TextStyle(color: AppConstants.textBody),
          ),
          const SizedBox(height: 16),
          const Text(
            '참석률은 모임의 전체 만남 수를 기준으로 계산해요.\n가입 전 만남도 포함되므로 순위보다 함께한 횟수를 돌아봐 주세요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppConstants.textBody,
            ),
          ),
          const SizedBox(height: 24),
          if (totalMeetups == 0)
            const Text('첫 만남을 기록하면 함께한 시간이 여기에 쌓여요.')
          else if (activeMembers.isEmpty)
            const Text('현재 멤버의 참석 기록이 없어요.')
          else
            for (final member in activeMembers)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite_outline_rounded,
                          size: 20,
                          color: AppConstants.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${member.attendedCount}번',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (member.attendedCount / totalMeetups).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: AppConstants.scaffoldBackground,
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '전체 $totalMeetups번 중 ${member.attendedCount}번 함께했어요 · ${(member.attendedCount / totalMeetups * 100).clamp(0, 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppConstants.textBody,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
