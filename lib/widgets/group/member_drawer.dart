import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utils/color_utils.dart';
import '../../../utils/ui_utils.dart';
import '../../../repositories/group_repository.dart';
import '../../../models/member_model.dart';

class MemberDrawer extends StatefulWidget {
  final String groupId, groupName;
  final List<MemberModel> members;
  final VoidCallback onMembersUpdated;
  final Color activeColor;
  final bool isDefaultColor;
  final GroupRepository repository;
  final void Function(MemberModel) onMemberTap;

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
  });

  @override
  State<MemberDrawer> createState() => _MemberDrawerState();
}

class _MemberDrawerState extends State<MemberDrawer> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  String _sortType = 'joined';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteLink() async {
    final encodedName = Uri.encodeComponent(widget.groupName);
    final inviteLink =
        'morak://invite?groupId=${widget.groupId}&groupName=$encodedName';

    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔗 초대 링크가 복사되었습니다! 카톡에 붙여넣기 해보세요!')),
      );
    }
  }

  Future<void> _addMember() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.addMember(
        widget.groupId,
        _nameController.text.trim(),
      );
      _nameController.clear();
      widget.onMembersUpdated();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeMember(MemberModel member) async {
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '멤버 내보내기',
      content: '${member.displayName} 님을 정말 내보내시겠습니까?',
      confirmText: '내보내기',
      confirmColor: Colors.redAccent,
      icon: Icons.person_remove_rounded,
    );
    if (confirm == true) {
      try {
        await widget.repository.removeMember(member.id);
        widget.onMembersUpdated();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('에러: $e')));
      }
    }
  }

  Future<void> _changeRole(MemberModel member) async {
    final currentRole = member.role;
    final newRole = currentRole == 'host' ? 'member' : 'host';
    final actionText = newRole == 'host' ? '방장으로 승급' : '일반 멤버로 강등';
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '권한 변경',
      content: '${member.displayName} 님을 $actionText 시키겠습니까?',
      confirmText: '변경',
      confirmColor: widget.isDefaultColor ? Colors.blue : widget.activeColor,
      icon: Icons.manage_accounts_rounded,
    );
    if (confirm == true) {
      try {
        await widget.repository.updateMemberRole(member.id, newRole);
        widget.onMembersUpdated();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('권한 변경 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final btnTextColor = widget.isDefaultColor
        ? Colors.white
        : ColorUtils.getTextColor(widget.activeColor);

    // 🌟 MemberModel의 속성들로 정렬 로직 수정!
    List<MemberModel> sortedMembers = List.from(widget.members);
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
      backgroundColor: Colors.grey[50],
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Text(
                    '멤버 관리 👥',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton.icon(
                onPressed: _copyInviteLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDefaultColor
                      ? Colors.grey[800]
                      : widget.activeColor,
                  foregroundColor: btnTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.share_rounded, color: btnTextColor),
                label: Text(
                  '초대링크 복사하기',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: btnTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '멤버 ${sortedMembers.length}명',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => setState(() => _sortType = value),
                    offset: const Offset(0, 30),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            sortLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.grey[800],
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
            const Divider(height: 1),
            Expanded(
              child: sortedMembers.isEmpty
                  ? const Center(child: Text('멤버가 없어요.'))
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
                            backgroundColor: Colors.grey[200],
                            backgroundImage: member.profileImageUrl != null
                                ? NetworkImage(member.profileImageUrl!)
                                : null,
                            child: member.profileImageUrl == null
                                ? Text(
                                    isHost ? '👑' : member.displayName[0],
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: isHost ? 14 : 16,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            member.displayName + (isMe ? ' (나)' : ''),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: isMe
                              ? const SizedBox.shrink()
                              : PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'role') _changeRole(member);
                                    if (value == 'kick') _removeMember(member);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'role',
                                      child: Text(
                                        isHost ? '일반 멤버로 강등' : '방장 권한 부여',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'kick',
                                      child: Text(
                                        '내보내기',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 12
                    : 24,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '수동으로 멤버 추가',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _addMember(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isSaving
                      ? const CircularProgressIndicator(color: Colors.grey)
                      : IconButton(
                          onPressed: _addMember,
                          icon: const Icon(Icons.person_add_rounded),
                          color: Colors.grey[800],
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                          ),
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
