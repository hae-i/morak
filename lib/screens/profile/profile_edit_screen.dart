import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
import '../../locator.dart';
import '../../repositories/user_repository.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isLoading = true;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _localProfileImage;
  String? _existingProfileImageUrl;
  final _userRepo = locator<UserRepository>();

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _nicknameController.text = profile.displayName;
          _existingProfileImageUrl = profile.profileImageUrl;
          if (profile.birthday != null)
            _selectedBirthday = DateTime.parse(profile.birthday!);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked != null) setState(() => _localProfileImage = picked);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(1996, 3, 12),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.black87,
          ), // 🌟 포인트 색상 블랙
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedBirthday = picked);
  }

  Future<void> _updateProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      UiUtils.showWarningDialog(
        context: context,
        title: '닉네임이 비어있어요!',
        message: '사용하실 닉네임을 꼭 입력해 주세요.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _userRepo.updateMyGlobalProfile(
        nickname: nickname,
        birthday: _selectedBirthday?.toIso8601String().split('T').first,
        existingImageUrl: _existingProfileImageUrl,
        newImageFile: _localProfileImage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 프로필이 수정되었습니다!'),
            backgroundColor: Colors.black87,
          ),
        );
        Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: Colors.white, // 🌟 순백색
      appBar: AppBar(
        title: const Text(
          '내 계정 편집',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.black87,
          ),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.black87,
                strokeWidth: 2,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: EditableAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[50]!,
                      localImage: _localProfileImage,
                      networkImageUrl: _existingProfileImageUrl,
                      fallbackIcon: Icons.person_rounded,
                      onTap: () => UiUtils.showImageActionMenu(
                        context: context,
                        onPick: _pickImage,
                        onDelete: () => setState(() {
                          _localProfileImage = null;
                          _existingProfileImageUrl = null;
                        }),
                        hasImage:
                            _localProfileImage != null ||
                            _existingProfileImageUrl != null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SectionTitle('닉네임'),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _nicknameController,
                    hint: '예: 모락대장',
                  ),
                  const SizedBox(height: 28),
                  const SectionTitle('생년월일'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50], // 🌟 플랫 배경
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedBirthday != null
                                ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                                : '예) 1996-03-12',
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedBirthday != null
                                  ? Colors.black87
                                  : Colors.grey[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.calendar_month_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  SizedBox(
                    width: double.infinity,
                    height: 54, // 🌟 버튼 다이어트
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87, // 🌟 블랙 버튼
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '수정 완료',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
