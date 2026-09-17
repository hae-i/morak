import 'package:flutter/material.dart';

import '../../utils/color_utils.dart';
import '../../utils/ui_utils.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../models/group_model.dart';
import '../../widgets/group/group_edit_sheets.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel groupData;

  const GroupInfoScreen({super.key, required this.groupData});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupRepo = locator<GroupRepository>();

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
      await _groupRepo.deleteGroup(widget.groupData.id);
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
        repository: _groupRepo,
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
      backgroundColor: Colors.white, // 🌟 순백색!
      appBar: AppBar(
        title: const Text(
          '모임 상세 정보',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              height: 160, // 🌟 높이 다이어트
              width: double.infinity,
              decoration: BoxDecoration(
                color: coverUrl != null
                    ? Colors.black
                    : (isDefaultColor
                          ? Colors.grey[100]
                          : activeColor.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF0F0F0)),
                image: coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black26,
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Center(
                child: Container(
                  width: 70, // 🌟 로고 사이즈 살짝 줄임
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                                  style: const TextStyle(fontSize: 34),
                                )
                              : Icon(
                                  Icons.groups_rounded,
                                  color: coverUrl != null
                                      ? activeColor
                                      : (isDefaultColor
                                            ? Colors.grey[400]
                                            : activeColor),
                                  size: 34,
                                ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.groupData.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 48),

            // 🌟 리스트 컨테이너 다이어트 (그림자 제거, 라인 추가)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)), // 얇은 라인
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      '모임 정보 수정',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[300],
                    ),
                    onTap: _openGroupEditSheet,
                  ),
                  const Divider(
                    height: 1,
                    indent: 64,
                    color: Color(0xFFF5F5F5),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      '모임 삭제하기',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey[300],
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
