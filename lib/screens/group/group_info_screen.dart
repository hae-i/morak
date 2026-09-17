import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';
import '../../utils/ui_utils.dart'; // 🌟 공통 팝업 임포트
import '../../widgets/common_widgets.dart'; // 🌟 공통 위젯 임포트
import '../../repositories/group_repository.dart';
import '../../widgets/profile_setup_sheet.dart';

class GroupInfoScreen extends StatefulWidget {
  final Map<String, dynamic> groupData;
  final GroupRepository repository;

  const GroupInfoScreen({
    super.key,
    required this.groupData,
    required this.repository,
  });
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Future<void> _deleteGroup() async {
    // 💡 UiUtils 한 줄 컷!
    final confirm = await UiUtils.showBeautifulDialog(
      context: context,
      title: '모임 삭제',
      content: '정말 이 모임을 삭제할까요?\n모든 기록이 함께 사라집니다.',
      confirmText: '삭제하기',
      confirmColor: Colors.redAccent,
      icon: Icons.delete_forever_rounded,
    );
    if (confirm == true) {
      await widget.repository.deleteGroup(widget.groupData['id']);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  void _openGroupEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GroupEditSheet(
        groupId: widget.groupData['id'],
        initialName: widget.groupData['name'],
        initialEmoji: widget.groupData['theme_emoji'],
        initialColor: widget.groupData['theme_color'],
        initialCoverUrl: widget.groupData['cover_image_url'],
        initialLogoUrl: widget.groupData['logo_image_url'],
        repository: widget.repository,
        onUpdated: () => Navigator.pop(context, 'updated'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = ColorUtils.stringToColor(
      widget.groupData['theme_color'],
    );
    final isDefaultColor = activeColor == Colors.grey[200]!;
    final coverUrl = widget.groupData['cover_image_url'];
    final logoUrl = widget.groupData['logo_image_url'];
    final emoji = widget.groupData['theme_emoji'];

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
              widget.groupData['name'],
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

class _GroupEditSheet extends StatefulWidget {
  final String groupId, initialName;
  final String? initialEmoji, initialColor, initialCoverUrl, initialLogoUrl;
  final GroupRepository repository;
  final VoidCallback onUpdated;
  const _GroupEditSheet({
    super.key,
    required this.groupId,
    required this.initialName,
    this.initialEmoji,
    this.initialColor,
    this.initialCoverUrl,
    this.initialLogoUrl,
    required this.repository,
    required this.onUpdated,
  });
  @override
  State<_GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends State<_GroupEditSheet> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _localCover;
  XFile? _localLogo;
  String? _selectedEmoji;
  int? _selectedColorIndex;
  bool _isSaving = false;
  String? _existingCoverUrl;
  String? _existingLogoUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedEmoji = widget.initialEmoji;
    _existingCoverUrl = widget.initialCoverUrl;
    _existingLogoUrl = widget.initialLogoUrl;
    if (widget.initialColor != null) {
      final val = int.tryParse(widget.initialColor!) ?? Colors.grey[200]!.value;
      for (int i = 0; i < AppConstants.themeColors.length; i++) {
        if (AppConstants.themeColors[i].value == val) {
          _selectedColorIndex = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isCover) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked != null)
      setState(() {
        if (isCover)
          _localCover = picked;
        else
          _localLogo = picked;
      });
  }

  Future<void> _showColorPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProfileSetupSheet(
        initialEmoji: _selectedEmoji,
        initialColorIndex: _selectedColorIndex,
      ),
    );
    if (result != null)
      setState(() {
        if (result['image'] != null) {
          _localLogo = result['image'];
          _selectedEmoji = null;
        } else {
          _selectedEmoji = result['emoji'];
          _selectedColorIndex = result['colorIndex'];
          _localLogo = null;
          _existingLogoUrl = null;
        }
      });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final colorStr = _selectedColorIndex != null
          ? '#${AppConstants.themeColors[_selectedColorIndex!].value.toRadixString(16).substring(2).toUpperCase()}'
          : null;
      await widget.repository.updateGroup(
        widget.groupId,
        name,
        colorStr,
        _selectedEmoji,
        _localCover,
        _existingCoverUrl,
        _localLogo,
        _existingLogoUrl,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '모임 정보 수정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            // 💡 UiUtils 카톡 액션 메뉴 연동!
            onTap: () => UiUtils.showImageActionMenu(
              context: context,
              onPick: () => _pickImage(true),
              onDelete: () => setState(() {
                _localCover = null;
                _existingCoverUrl = null;
              }),
              hasImage: _localCover != null || _existingCoverUrl != null,
            ),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 2),
                image: _localCover != null
                    ? DecorationImage(
                        image: kIsWeb
                            ? NetworkImage(_localCover!.path)
                            : FileImage(File(_localCover!.path))
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : (_existingCoverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_existingCoverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child: (_localCover == null && _existingCoverUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '대표 사진 변경',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              GestureDetector(
                onTap: _showColorPicker,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _selectedColorIndex != null
                          ? AppConstants.themeColors[_selectedColorIndex!]
                          : Colors.grey[200],
                      backgroundImage: _localLogo != null
                          ? (kIsWeb
                                ? NetworkImage(_localLogo!.path)
                                : FileImage(File(_localLogo!.path))
                                      as ImageProvider)
                          : (_existingLogoUrl != null
                                ? NetworkImage(_existingLogoUrl!)
                                : null),
                      child: (_localLogo == null && _existingLogoUrl == null)
                          ? (_selectedEmoji != null
                                ? Text(
                                    _selectedEmoji!,
                                    style: const TextStyle(fontSize: 24),
                                  )
                                : Icon(
                                    Icons.color_lens_rounded,
                                    color: Colors.grey[400],
                                  ))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickImage(false),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A80),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 💡 CustomTextField 한 줄 컷!
              Expanded(
                child: CustomTextField(
                  controller: _nameController,
                  hint: '모임 이름',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A80),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '수정 완료',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
