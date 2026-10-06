// === 수정한 내용: 저장된 모임·프로필 사진을 로그인 권한으로 조회한다 ===
import '../../services/private_photos.dart';

// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import '../../../constants/app_constants.dart';
import '../../../repositories/group_repository.dart';
import '../profile/profile_setup_sheet.dart';
import '../../../utils/ui_utils.dart';
import '../../../models/member_model.dart';
import '../common/common_widgets.dart';
import '../common/common_button.dart';
import '../../utils/color_utils.dart';
import '../../utils/data_refresh.dart';

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
  bool _themeChanged = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedEmoji = widget.initialEmoji;
    _existingCoverUrl = widget.initialCoverUrl;
    _existingLogoUrl = widget.initialLogoUrl;
    if (widget.initialColor != null) {
      // === 수정한 내용: 저장된 HEX 색상을 올바르게 읽고 이름만 수정할 때 기존 테마를 보존한다 ===
      final val = ColorUtils.stringToColor(widget.initialColor).toARGB32();
      for (int i = 0; i < AppConstants.themeColors.length; i++) {
        if (AppConstants.themeColors[i].toARGB32() == val) {
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
    final picked = (await pickImagesWithRecovery(
      context: context,
      picker: _picker,
      target: 'group:${widget.groupId}:${isCover ? 'cover' : 'logo'}',
      maxWidth: 1080,
      maxHeight: 1080,
    )).firstOrNull;
    if (mounted && picked != null) {
      setState(() {
        if (isCover) {
          _localCover = picked;
        } else {
          _localLogo = picked;
        }
      });
    }
  }

  Future<void> _showColorPicker() async {
    // === 수정한 내용: 실제 반환 객체와 같은 타입을 사용하여 테마 선택의 런타임 오류를 방지한다 ===
    final result = await showModalBottomSheet<ProfileSetupResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBackground, // 🌟 교체
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProfileSetupSheet(
        recoveryTarget: 'group:${widget.groupId}:logo',
        initialEmoji: _selectedEmoji,
        initialColorIndex: _selectedColorIndex,
      ),
    );
    if (mounted && result != null) {
      setState(() {
        if (result.hasImage) {
          _localLogo = result.image;
          _selectedEmoji = null;
        } else {
          _selectedEmoji = result.emoji;
          _selectedColorIndex = result.colorIndex;
          _themeChanged = true;
          _localLogo = null;
          _existingLogoUrl = null;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final colorStr = _selectedColorIndex != null
          ? '#${AppConstants.themeColors[_selectedColorIndex!].value.toRadixString(16).substring(2).toUpperCase()}'
          : (_themeChanged ? null : widget.initialColor);
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
        refreshHomeFeed(context);
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정하지 못했습니다. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.cardBackground, // 🌟 교체
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
              color: AppConstants.borderColor, // 🌟 교체
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '모임 정보 수정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppConstants.textTitle, // 🌟 교체
            ),
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
                color: AppConstants.dividerColor, // 🌟 교체
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.borderColor), // 🌟 교체
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
                              image: privatePhoto(_existingCoverUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child: (_localCover == null && _existingCoverUrl == null)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: AppConstants.textCaption, // 🌟 교체
                        ),
                        SizedBox(height: 8),
                        Text(
                          '대표 사진 변경',
                          style: TextStyle(
                            color: AppConstants.textBody, // 🌟 교체
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                      : AppConstants.dividerColor, // 🌟 교체
                  backgroundImage: _localLogo != null
                      ? (kIsWeb
                            ? NetworkImage(_localLogo!.path)
                            : FileImage(File(_localLogo!.path))
                                  as ImageProvider)
                      : (_existingLogoUrl != null
                            ? privatePhoto(_existingLogoUrl!)
                            : null),
                  child: (_localLogo == null && _existingLogoUrl == null)
                      ? (_selectedEmoji != null
                            ? Text(
                                _selectedEmoji!,
                                style: const TextStyle(fontSize: 24),
                              )
                            : const Icon(
                                Icons.color_lens_rounded,
                                color: AppConstants.textCaption, // 🌟 교체
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
                    hintStyle: const TextStyle(
                      color: AppConstants.textCaption,
                      fontSize: 15,
                    ), // 🌟 교체
                    filled: true,
                    fillColor: AppConstants.dividerColor, // 🌟 교체
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppConstants.borderColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppConstants.borderColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppConstants.primaryColor, // 🌟 교체
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 🌟 버튼 통일
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                )
              : Button(text: '수정 완료', onPressed: _save),
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
      final picked = (await pickImagesWithRecovery(
        context: context,
        picker: _picker,
        target: 'member:${widget.memberData.id}',
      )).firstOrNull;
      // === 수정한 내용: 멤버 사진 선택은 화면이 닫힌 뒤 상태를 변경하지 않는다 ===
      if (mounted && picked != null) setState(() => _localImage = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다. 다시 시도해 주세요.')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await widget.repository.updateGroupMemberProfile(
        memberId: widget.memberData.id,
        displayName: nickname,
        existingImageUrl: _existingImageUrl,
        newImageFile: _localImage,
        isBirthdayPublic: _isBirthdayPublic,
      );
      if (mounted) {
        refreshHomeFeed(context);
        Navigator.pop(context);
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정하지 못했습니다. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.cardBackground, // 🌟 교체
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
              color: AppConstants.borderColor, // 🌟 교체
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '내 모임 프로필 수정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppConstants.textTitle, // 🌟 교체
            ),
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
                color: AppConstants.dividerColor, // 🌟 교체
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppConstants.cardBackground,
                  width: 2,
                ), // 🌟 교체
              ),
              child: EditableAvatar(
                radius: 45,
                backgroundColor: AppConstants.dividerColor, // 🌟 교체
                localImage: _localImage,
                networkImageUrl: _existingImageUrl,
                fallbackIcon: Icons.person_rounded,
                onTap: () => (),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '닉네임',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppConstants.textTitle,
              ), // 🌟 교체
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppConstants.dividerColor, // 🌟 교체
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppConstants.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppConstants.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppConstants.primaryColor,
                  width: 1.5,
                ), // 🌟 교체
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
                  activeColor: AppConstants.primaryColor, // 🌟 교체
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '이 모임에 내 생일 공개하기 🎂',
                style: TextStyle(
                  fontSize: 14,
                  color: AppConstants.textTitle, // 🌟 교체
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 🌟 버튼 통일
          _isSaving
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                )
              : Button(text: '수정 완료', onPressed: _saveProfile),
        ],
      ),
    );
  }
}
