import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/member_model.dart'; // 🌟 모델 임포트

class MemberManageSheet extends StatelessWidget {
  final MemberModel member; // 🌟 Map 대신 MemberModel 타입으로 변경
  final VoidCallback onKick;
  final bool canChangeRoles;
  final VoidCallback? onDeputyRole;
  final VoidCallback onChangeRole;
  final VoidCallback? onTransferHost;

  const MemberManageSheet({
    super.key,
    required this.member,
    required this.onKick,
    this.canChangeRoles = true,
    this.onDeputyRole,
    required this.onChangeRole,
    this.onTransferHost,
  });

  @override
  Widget build(BuildContext context) {
    final memberName = member.displayName;
    final role = member.role;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$memberName 관리',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textTitle,
              ),
            ),
            const SizedBox(height: 24),
            // === 수정한 내용: 이미 방장인 실제 계정에게도 위임하되 기존 강등 메뉴는 유지한다 ===
            if (canChangeRoles &&
                role == 'host' &&
                member.userId.isNotEmpty &&
                onTransferHost != null)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text(
                  '방장 위임',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textTitle,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onTransferHost!();
                },
              ),
            // === 수정한 내용: 부방장은 관리자 역할을 바꿀 수 없고 방장에게만 부방장 임명·해제를 표시한다 ===
            if (canChangeRoles &&
                member.userId.isNotEmpty &&
                role != 'host' &&
                onDeputyRole != null)
              ListTile(
                leading: const Icon(Icons.manage_accounts_rounded),
                title: Text(role == 'deputy' ? '부방장 해제' : '부방장 임명'),
                onTap: () {
                  Navigator.pop(context);
                  onDeputyRole!();
                },
              ),
            if (canChangeRoles && member.userId.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppConstants.textTitle,
                ),
                title: Text(
                  // === 수정한 내용: 기존 승급 메뉴를 본인 권한도 넘기는 방장 위임으로 명확히 표시한다 ===
                  role == 'host' ? '일반 멤버로 강등' : '방장 위임',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textTitle,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onChangeRole();
                },
              ),
            // === 수정한 내용: 방장은 먼저 위임·강등해야 내보낼 수 있으므로 불가능한 메뉴를 숨긴다 ===
            if (role != 'host')
              ListTile(
                leading: const Icon(
                  Icons.person_remove_rounded,
                  color: AppConstants.dangerColor,
                ),
                title: const Text(
                  '모임에서 내보내기',
                  style: TextStyle(
                    color: AppConstants.dangerColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
