import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';
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
  // 모던 다이얼로그
  Future<bool?> _showBeautifulDialog(
    String title,
    String content,
    String confirmText,
    Color confirmColor,
    IconData icon,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: confirmColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.grey[100],
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final confirm = await _showBeautifulDialog(
      '모임 삭제',
      '정말 이 모임을 삭제할까요?\n모든 기록이 함께 사라집니다.',
      '삭제하기',
      Colors.redAccent,
      Icons.delete_forever_rounded,
    );
    if (confirm == true) {
      await widget.repository.deleteGroup(widget.groupData['id']);
      if (mounted) Navigator.pop(context, 'deleted'); // 삭제되었다고 이전 화면에 알려줌
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
        onUpdated: () => Navigator.pop(context, 'updated'), // 수정되었다고 이전 화면에 알려줌
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
            // 🌟 큼직한 프로필 표시
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

            // 🌟 수정 / 삭제 리스트
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

// 💡 그룹 수정용 바텀시트 (GroupDetailScreen에 있던 걸 이쪽으로 옮겼습니다!)
class _GroupEditSheet extends StatefulWidget {
  final String groupId, initialName;
  final String? initialEmoji, initialColor, initialCoverUrl, initialLogoUrl;
  final GroupRepository repository;
  final VoidCallback onUpdated;
  const _GroupEditSheet({
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

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedEmoji = widget.initialEmoji;
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
        _selectedEmoji = result['emoji'];
        _selectedColorIndex = result['colorIndex'];
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
        widget.initialCoverUrl,
        _localLogo,
        widget.initialLogoUrl,
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
            onTap: () => _pickImage(true),
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
                    : (widget.initialCoverUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.initialCoverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child: (_localCover == null && widget.initialCoverUrl == null)
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
                          : (widget.initialLogoUrl != null
                                ? NetworkImage(widget.initialLogoUrl!)
                                : null),
                      child:
                          (_localLogo == null && widget.initialLogoUrl == null)
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
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '모임 이름',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF8A80),
                        width: 1.5,
                      ),
                    ),
                  ),
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
