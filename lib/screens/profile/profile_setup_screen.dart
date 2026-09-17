import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main_skeleton.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
import '../../locator.dart';
import '../../repositories/user_repository.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;
  final _userRepo = locator<UserRepository>();

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) setState(() => _profileImage = pickedFile);
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
          ), // 🌟 블랙 테마 달력
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedBirthday = picked);
  }

  Future<void> _completeSignUp() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      UiUtils.showWarningDialog(
        context: context,
        title: '닉네임이 비어있어요!',
        message: '사용하실 닉네임을 꼭 입력해 주세요.',
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _userRepo.updateMyGlobalProfile(
        nickname: nickname,
        birthday: _selectedBirthday?.toIso8601String().split('T').first,
        newImageFile: _profileImage,
        isNewSetup: true,
      );
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainSkeleton()),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('프로필 설정 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🌟 순백색
      appBar: AppBar(
        title: const Text(
          '환영합니다! 🎉',
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
          onPressed: () async => await _userRepo.signOut(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '모락에서 사용할\n프로필을 설정해 주세요.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '나중에 언제든 변경할 수 있어요!',
                style: TextStyle(fontSize: 15, color: Colors.grey[500]),
              ),
              const SizedBox(height: 48),
              Center(
                child: EditableAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[50]!,
                  localImage: _profileImage,
                  fallbackIcon: Icons.person_rounded,
                  onTap: () => UiUtils.showImageActionMenu(
                    context: context,
                    onPick: _pickImage,
                    onDelete: () => setState(() => _profileImage = null),
                    hasImage: _profileImage != null,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const SectionTitle('닉네임'),
              const SizedBox(height: 12),
              CustomTextField(controller: _nicknameController, hint: '예: 모락대장'),
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
                  onPressed: _isLoading ? null : _completeSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87, // 🌟 블랙 버튼
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '모락 시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
