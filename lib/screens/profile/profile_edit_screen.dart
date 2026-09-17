import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
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
  final _userRepo = UserRepository();

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
            primary: AppConstants.primaryColor,
          ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('🎉 프로필이 수정되었습니다!')));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '내 계정 편집',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            ) // 🌟 색상 변경!
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: EditableAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[100]!,
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
                  const SizedBox(height: 40),
                  const SectionTitle('닉네임'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _nicknameController,
                    hint: '예: 모락대장',
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('생년월일'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedBirthday != null
                                ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                                : '예) 1996-03-12',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedBirthday != null
                                  ? Colors.black87
                                  : Colors.grey[400],
                            ),
                          ),
                          Icon(
                            Icons.calendar_month_rounded,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              '수정 완료',
                              style: TextStyle(
                                fontSize: 18,
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
