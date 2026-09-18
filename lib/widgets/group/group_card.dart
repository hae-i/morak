import 'package:flutter/material.dart';

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // 🌟 20 -> 16
          border: Border.all(color: const Color(0xFFEEEEEE)), // 🌟 그림자 없애고 테두리
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54, // 🌟 60 -> 54
              decoration: BoxDecoration(
                color: isDefaultColor
                    ? Colors.grey[100]
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
                        color: isDefaultColor ? Colors.grey[400] : groupColor,
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (role == 'host') ...[
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
