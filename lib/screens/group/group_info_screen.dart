// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/color_utils.dart';
import '../../utils/ui_utils.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../models/group_model.dart';
import '../../widgets/group/group_edit_sheets.dart';
import '../../constants/app_constants.dart';
import '../../utils/data_refresh.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel groupData;

  const GroupInfoScreen({super.key, required this.groupData});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupRepo = locator<GroupRepository>();
  String? _role;
  bool get _canEdit => _role == 'host' || _role == 'deputy';
  bool get _canDelete => _role == 'host';
  // === 수정한 내용: 서버에서 본인 소속을 조회하고 일반 멤버에게 수정·삭제 작업을 노출하지 않는다 ===
  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = Supabase.instance.client.auth.currentUser?.id;
    if (user == null) return;
    try {
      final membership = await _groupRepo.fetchMyMembership(
        widget.groupData.id,
      );
      if (mounted && Supabase.instance.client.auth.currentUser?.id == user) {
        setState(
          () => _role = membership?['is_deleted'] == true
              ? null
              : membership?['role'] as String?,
        );
      }
    } catch (_) {
      if (mounted && Supabase.instance.client.auth.currentUser?.id == user) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('관리 권한을 확인하지 못했습니다. 화면을 다시 열어 주세요.')),
        );
      }
    }
  }

  Future<void> _deleteGroup() async {
    if (!_canDelete) return;
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '모임 삭제',
      content: '정말 이 모임을 삭제할까요?\n모든 기록이 함께 사라집니다.',
      confirmText: '삭제하기',
      confirmColor: Colors.redAccent,
      icon: Icons.delete_forever_rounded,
    );
    if (confirm == true) {
      // === 수정한 내용: 삭제 실패는 화면에 알리고 성공한 경우에만 캐시와 상위 화면을 갱신한다 ===
      try {
        await _groupRepo.deleteGroup(widget.groupData.id);
        if (!mounted) return;
        refreshHomeFeed(context);
        Navigator.pop(context, 'deleted');
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모임을 삭제하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      }
    }
  }

  void _openGroupEditSheet() {
    if (!_canEdit) return;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '모임 상세 정보',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppConstants.scaffoldBackground,
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
              height: 160,
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
                        image: privatePhoto(coverUrl),
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
                  width: 70,
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
                            image: privatePhoto(logoUrl),
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

            if (_canEdit)
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderColor),
                ),
                // === 수정한 내용: 설정 메뉴의 배경 위에 Material을 제공해 실제 화면 진입 시 assertion을 막는다 ===
                child: Material(
                  type: MaterialType.transparency,
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
                      if (_canDelete)
                        const Divider(
                          height: 1,
                          indent: 64,
                          color: AppConstants.dividerColor,
                        ),
                      if (_canDelete)
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
              ),
          ],
        ),
      ),
    );
  }
}
