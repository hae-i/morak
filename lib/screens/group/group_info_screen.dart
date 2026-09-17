import 'package:flutter/material.dart';

import '../../utils/color_utils.dart';
import '../../utils/ui_utils.dart';
import '../../repositories/group_repository.dart';
import '../../models/group_model.dart';
import '../../widgets/group/group_edit_sheets.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel groupData;
  final GroupRepository groupRepo;

  const GroupInfoScreen({
    super.key,
    required this.groupData,
    required this.groupRepo,
  });
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Future<void> _deleteGroup() async {
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '모임 삭제',
      content: '정말 이 모임을 삭제할까요?\n모든 기록이 함께 사라집니다.',
      confirmText: '삭제하기',
      confirmColor: Colors.redAccent,
      icon: Icons.delete_forever_rounded,
    );
    if (confirm == true) {
      await widget.groupRepo.deleteGroup(widget.groupData.id);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  void _openGroupEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupEditSheet(
        groupId: widget.groupData.id,
        initialName: widget.groupData.name,
        initialEmoji: widget.groupData.themeEmoji,
        initialColor: widget.groupData.themeColor,
        initialCoverUrl: widget.groupData.coverImageUrl,
        initialLogoUrl: widget.groupData.logoImageUrl,
        repository: widget.groupRepo,
        onUpdated: () => Navigator.pop(context, 'updated'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = ColorUtils.stringToColor(widget.groupData.themeColor);
    final isDefaultColor = activeColor == Colors.grey[200]!;
    final coverUrl = widget.groupData.coverImageUrl;
    final logoUrl = widget.groupData.logoImageUrl;
    final emoji = widget.groupData.themeEmoji;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '모임 상세 정보',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: coverUrl != null
                    ? Colors.black
                    : (isDefaultColor
                          ? Colors.grey[200]
                          : activeColor.withOpacity(0.15)),
                borderRadius: BorderRadius.circular(24),
                image: coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: coverUrl != null ? Colors.white24 : Colors.white54,
                    shape: BoxShape.circle,
                    image: logoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(logoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: logoUrl == null
                      ? Center(
                          child: (emoji != null && emoji.isNotEmpty)
                              ? Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 40),
                                )
                              : Icon(
                                  Icons.groups_rounded,
                                  color: coverUrl != null
                                      ? Colors.white
                                      : (isDefaultColor
                                            ? Colors.grey[400]
                                            : activeColor),
                                  size: 40,
                                ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.groupData.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 48),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.black87,
                      ),
                    ),
                    title: const Text(
                      '모임 정보 수정',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: _openGroupEditSheet,
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: const Text(
                      '모임 삭제하기',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: _deleteGroup,
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
