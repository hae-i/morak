import 'package:flutter/material.dart';

import '../utils/color_utils.dart';
import '../models/group_model.dart';

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
    // 🌟 리팩토링된 ColorUtils 사용!
    final groupColor = ColorUtils.stringToColor(group.themeColor);
    // 기본 회색인지 확인 (그림자 효과를 위해)
    final isDefaultColor = groupColor == Colors.grey[200]!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDefaultColor
                  ? Colors.black.withOpacity(0.02)
                  : groupColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDefaultColor
                    ? Colors.grey[200]
                    : groupColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: group.themeEmoji.isNotEmpty
                    ? Text(
                        group.themeEmoji,
                        style: const TextStyle(fontSize: 28),
                      )
                    : Icon(
                        Icons.groups_rounded,
                        color: isDefaultColor ? Colors.grey[400] : groupColor,
                        size: 32,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (role == 'host') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '👑 방장',
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
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
