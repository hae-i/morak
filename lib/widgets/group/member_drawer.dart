// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_constants.dart';
import '../../../utils/ui_utils.dart';
import '../../../repositories/group_repository.dart';
import '../../../models/member_model.dart';
import 'member_manage_sheet.dart';

class MemberDrawer extends StatefulWidget {
  final String groupId, groupName;
  final List<MemberModel> members;
  final VoidCallback onMembersUpdated;
  final Color activeColor;
  final bool isDefaultColor;
  final GroupRepository repository;
  final void Function(MemberModel) onMemberTap;
  final VoidCallback? onClose;
  // === 수정한 내용: 모임 설정·공유를 넓은 화면과 작은 화면의 같은 사이드바 하단으로 이동한다 ===
  final VoidCallback? onSettings;
  final VoidCallback? onShare;
  final VoidCallback? onBack;
  final VoidCallback? onLeave;

  const MemberDrawer({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.onMembersUpdated,
    required this.activeColor,
    required this.isDefaultColor,
    required this.repository,
    required this.onMemberTap,
    this.onClose,
    this.onSettings,
    this.onShare,
    this.onBack,
    this.onLeave,
  });

  @override
  State<MemberDrawer> createState() => _MemberDrawerState();
}

class _MemberDrawerState extends State<MemberDrawer> {
  String _sortType = 'joined';

  // 🌟 (불필요해진 _nameController, _isSaving, _addMember 함수 모두 삭제 완료!)

  Future<void> _removeMember(MemberModel member) async {
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '멤버 내보내기',
      content: '${member.displayName} 님을 정말 내보내시겠습니까?',
      confirmText: '내보내기',
      confirmColor: AppConstants.dangerColor,
      icon: Icons.person_remove_rounded,
    );
    if (confirm == true) {
      try {
        await widget.repository.removeMember(member.id);
        // === 수정한 내용: 요청 완료 후 부모 갱신은 멤버 화면이 살아 있을 때만 호출한다 ===
        if (mounted) widget.onMembersUpdated();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('요청을 완료하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      }
    }
  }

  Future<void> _changeRole(MemberModel member, {bool transfer = false}) async {
    final currentRole = member.role;
    final newRole = transfer
        ? 'host'
        : (currentRole == 'host' ? 'member' : 'host');
    // === 수정한 내용: 방장 위임 시 본인도 일반 멤버가 됨을 확인하고 원자적 RPC를 사용한다 ===
    final actionText = newRole == 'host'
        ? '방장으로 위임하고 나는 일반 멤버로 변경'
        : '일반 멤버로 강등';
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '권한 변경',
      content: '${member.displayName} 님을 $actionText 시키겠습니까?',
      confirmText: '변경',
      confirmColor: AppConstants.highlightColor,
      icon: Icons.manage_accounts_rounded,
    );
    if (confirm == true) {
      try {
        if (newRole == 'host') {
          await widget.repository.transferHost(widget.groupId, member.id);
        } else {
          await widget.repository.updateMemberRole(member.id, newRole);
        }
        if (mounted) widget.onMembersUpdated();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('권한을 변경하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      }
    }
  }

  // === 수정한 내용: 부방장 임명·해제는 방장만 확인 후 수행한다 ===
  Future<void> _changeDeputy(MemberModel member) async {
    final role = member.role == 'deputy' ? 'member' : 'deputy';
    final confirmed = await UiUtils.showBeautifulDialog(
      context: context,
      title: '부방장 권한 변경',
      content:
          '${member.displayName} 님을 ${role == 'deputy' ? '부방장으로 임명' : '일반 멤버로 변경'}하시겠습니까?',
      confirmText: '변경',
      confirmColor: AppConstants.primaryColor,
      icon: Icons.manage_accounts_rounded,
    );
    if (!mounted || confirmed != true) return;
    try {
      await widget.repository.updateMemberRole(member.id, role);
      if (mounted) widget.onMembersUpdated();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('부방장 권한을 변경하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final iAmHost = widget.members.any(
      (m) => m.userId == currentUserId && m.isHost,
    );

    final iAmManager = widget.members.any(
      (m) => m.userId == currentUserId && m.isManager,
    );
    // === 수정한 내용: 탈퇴 멤버는 과거 기록에는 남기되 현재 멤버 목록·관리 대상에서 제외한다 ===
    List<MemberModel> sortedMembers = widget.members
        .where((m) => m.isActive)
        .toList();
    if (_sortType == 'joined') {
      sortedMembers.sort(
        (a, b) => (a.joinedAt ?? '').compareTo(b.joinedAt ?? ''),
      );
    } else if (_sortType == 'name') {
      sortedMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
    } else if (_sortType == 'rate') {
      sortedMembers.sort((a, b) {
        int r = b.attendanceRate.compareTo(a.attendanceRate);
        return r != 0 ? r : (a.joinedAt ?? '').compareTo(b.joinedAt ?? '');
      });
    }

    String sortLabel = _sortType == 'joined'
        ? '참가순'
        : (_sortType == 'name' ? '가나다순' : '참여율순');

    return Drawer(
      backgroundColor: AppConstants.cardBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      tooltip: '모임 목록으로',
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      onPressed: widget.onBack,
                    ),
                  Expanded(
                    child: Text(
                      widget.groupName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textTitle,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppConstants.textTitle,
                    ),
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '멤버 ${sortedMembers.length}명',
                    style: const TextStyle(
                      color: AppConstants.textBody,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(() => _sortType = value),
                    offset: const Offset(0, 30),
                    color: AppConstants.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.dividerColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConstants.borderColor),
                      ),
                      child: Row(
                        children: [
                          Text(
                            sortLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppConstants.textTitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppConstants.textTitle,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'joined',
                        child: Text('참가순', style: TextStyle(fontSize: 14)),
                      ),
                      const PopupMenuItem(
                        value: 'name',
                        child: Text('가나다순', style: TextStyle(fontSize: 14)),
                      ),
                      const PopupMenuItem(
                        value: 'rate',
                        child: Text('참여율순', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppConstants.dividerColor),

            // 🌟 하단 입력창(수동추가)이 통째로 삭제되고 리스트뷰만 넓게 사용합니다.
            Expanded(
              child: sortedMembers.isEmpty
                  ? const Center(
                      child: Text(
                        '멤버가 없어요.',
                        style: TextStyle(color: AppConstants.textCaption),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: sortedMembers.length,
                      itemBuilder: (context, index) {
                        final member = sortedMembers[index];
                        final isHost = member.role == 'host';
                        final isMe =
                            currentUserId != null &&
                            member.userId == currentUserId;

                        return ListTile(
                          onTap: () => widget.onMemberTap(member),
                          leading: CircleAvatar(
                            backgroundColor: AppConstants.dividerColor,
                            backgroundImage: member.profileImageUrl != null
                                ? privatePhoto(member.profileImageUrl!)
                                : null,
                            child: member.profileImageUrl == null
                                ? Text(
                                    isHost ? '👑' : member.displayName[0],
                                    style: TextStyle(
                                      color: AppConstants.textTitle,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isHost ? 14 : 16,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            // === 수정한 내용: 활성 부방장의 관리 역할을 멤버 목록에 표시한다 ===
                            member.displayName +
                                (member.role == 'deputy' ? ' (부방장)' : '') +
                                (isMe ? ' (나)' : ''),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppConstants.textTitle,
                            ),
                          ),

                          // 🌟 못생긴 PopupMenuButton 대신 아이콘 터치 시 예쁜 바텀 시트 호출!
                          trailing:
                              (isMe ||
                                  !iAmManager ||
                                  (!iAmHost && member.role != 'member'))
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: AppConstants.textCaption,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor:
                                          AppConstants.cardBackground,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                      ),
                                      builder: (context) => MemberManageSheet(
                                        member: member,
                                        onKick: () => _removeMember(member),
                                        canChangeRoles: iAmHost,
                                        onDeputyRole: () =>
                                            _changeDeputy(member),
                                        onChangeRole: () => _changeRole(member),
                                        // === 수정한 내용: 기존 복수 방장 모임에서도 다른 방장에게 본인 권한을 위임할 수 있게 한다 ===
                                        onTransferHost: () =>
                                            _changeRole(member, transfer: true),
                                      ),
                                    );
                                  },
                                ),
                        );
                      },
                    ),
            ),
            // === 수정한 내용: 하단 왼쪽에 나가기, 오른쪽에 작은 공유·설정 아이콘을 배치한다 ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onLeave,
                    style: TextButton.styleFrom(
                      foregroundColor: AppConstants.dangerColor,
                    ),
                    child: const Text(
                      '나가기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '모임 공유',
                    onPressed: widget.onShare,
                    icon: const Icon(Icons.share_outlined),
                  ),
                  IconButton(
                    tooltip: '모임 설정',
                    onPressed: widget.onSettings,
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
