import 'package:flutter/material.dart';
import '../utils/color_utils.dart'; // 방금 만든 유틸 임포트

class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
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
    final String? colorRaw = group['theme_color'];
    final int colorInt = colorRaw != null
        ? (int.tryParse(colorRaw) ?? Colors.grey[200]!.value)
        : Colors.grey[200]!.value;
    final themeColor = Color(colorInt);

    final themeEmoji = group['theme_emoji'] ?? '☁️';
    final groupName = group['name'] ?? '이름 없는 모임';
    final textColor = ColorUtils.getTextColor(themeColor); // 유틸 사용!

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Center(child: Text(themeEmoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (role == 'host') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      child: Text('👑 방장', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.5), size: 28),
          ],
        ),
      ),
    );
  }
}