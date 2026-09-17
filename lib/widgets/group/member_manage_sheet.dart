import 'package:flutter/material.dart';

class MemberManageSheet extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onKick;
  final VoidCallback onChangeRole;

  const MemberManageSheet({
    super.key,
    required this.member,
    required this.onKick,
    required this.onChangeRole,
  });

  @override
  Widget build(BuildContext context) {
    final memberName = member['display_name'] ?? '알 수 없음';
    final role = member['role'] ?? 'member';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$memberName 관리', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: Text(role == 'host' ? '일반 멤버로 강등' : '방장 권한 부여'),
              onTap: () {
                Navigator.pop(context);
                onChangeRole();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
              title: const Text('모임에서 내보내기', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                onKick();
              },
            ),
          ],
        ),
      ),
    );
  }
}