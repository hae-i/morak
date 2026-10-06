import 'package:flutter/material.dart';

import '../../constants/app_constants.dart'; // 🌟 추가
import '../../utils/color_utils.dart';
import '../../models/group_model.dart';

class GroupCard extends StatelessWidget {
  final GroupModel group;
  final String role;
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final groupColor = ColorUtils.stringToColor(group.themeColor);
    final isDefaultColor = groupColor == Colors.grey[200]!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppConstants.cardBackground, // 🌟 교체
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.borderColor), // 🌟 교체
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDefaultColor
                    ? AppConstants
                          .dividerColor // 🌟 교체
                    : groupColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child:
                    (group.themeEmoji != null && group.themeEmoji!.isNotEmpty)
                    ? Text(
                        group.themeEmoji!,
                        style: const TextStyle(fontSize: 24),
                      )
                    : Icon(
                        Icons.groups_rounded,
                        color: isDefaultColor
                            ? AppConstants.textCaption
                            : groupColor, // 🌟 교체
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textTitle, // 🌟 교체
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // === 수정한 내용: 내 모임 목록에서 방장과 부방장을 구분한다 ===
                      if (role == 'host' || role == 'deputy') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50], // 방장 뱃지는 오렌지색 그대로 유지
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role == 'host' ? '👑 방장' : '부방장',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppConstants.textCaption,
            ), // 🌟 교체
          ],
        ),
      ),
    );
  }
}
