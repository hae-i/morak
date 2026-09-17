import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app_constants.dart';
import '../../../repositories/group_repository.dart';
import '../profile/profile_setup_sheet.dart';
import '../../../utils/ui_utils.dart';
import '../../../models/member_model.dart';
import '../common/common_widgets.dart';

// ==========================================
// 🌟 모임 정보 수정 바텀 시트
// ==========================================
class GroupEditSheet extends StatefulWidget {
  final String groupId, initialName;
  final String? initialEmoji, initialColor, initialCoverUrl, initialLogoUrl;
  final GroupRepository repository;
  final VoidCallback onUpdated;

  const GroupEditSheet({
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
  State<GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends State<GroupEditSheet> {
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
    if (result != null) {
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
        groupId: widget.groupId,
        name: name,
        hexColor: colorStr,
        emoji: _selectedEmoji,
        newCoverImage: _localCover,
        existingCoverUrl: _existingCoverUrl,
        newLogoImage: _localLogo,
        existingLogoUrl: _existingLogoUrl,
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
                child: CircleAvatar(
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

// ==========================================
// 🌟 모임 멤버 프로필 수정 바텀 시트
// ==========================================
class GroupProfileEditSheet extends StatefulWidget {
  final MemberModel memberData;
  final GroupRepository repository;
  final VoidCallback onUpdated;

  const GroupProfileEditSheet({
    super.key,
    required this.memberData,
    required this.repository,
    required this.onUpdated,
  });
  @override
  State<GroupProfileEditSheet> createState() => _GroupProfileEditSheetState();
}

class _GroupProfileEditSheetState extends State<GroupProfileEditSheet> {
  final TextEditingController _nicknameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _localImage;
  String? _existingImageUrl;
  bool _isSaving = false;
  bool _isBirthdayPublic = true;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.memberData.displayName;
    _existingImageUrl = widget.memberData.profileImageUrl;
    _isBirthdayPublic = widget.memberData.isBirthdayPublic;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _localImage = picked);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      // 🌟 memberData.id 로 접근!
      await widget.repository.updateGroupMemberProfile(
        memberId: widget.memberData.id,
        displayName: nickname,
        existingImageUrl: _existingImageUrl,
        newImageFile: _localImage,
        isBirthdayPublic: _isBirthdayPublic,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('🎉 프로필이 수정되었습니다!')));
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
            '내 모임 프로필 수정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => UiUtils.showImageActionMenu(
              context: context,
              onPick: _pickImage,
              onDelete: () => setState(() {
                _localImage = null;
                _existingImageUrl = null;
              }),
              hasImage: _localImage != null || _existingImageUrl != null,
            ),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: EditableAvatar(
                radius: 45,
                backgroundColor: Colors.grey[200]!,
                localImage: _localImage,
                networkImageUrl: _existingImageUrl,
                fallbackIcon: Icons.person_rounded,
                onTap: () => (),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '닉네임',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
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
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _isBirthdayPublic,
                  onChanged: (val) =>
                      setState(() => _isBirthdayPublic = val ?? true),
                  activeColor: const Color(0xFFFF8A80),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '이 모임에 내 생일 공개하기 🎂',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
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
