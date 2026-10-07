// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/profile/birthday_field.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/common_button.dart';
import '../../constants/app_constants.dart';
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
      final pickedFile = (await pickImagesWithRecovery(
        context: context,
        picker: _picker,
        target: 'global-profile',
      )).firstOrNull;
      // === 수정한 내용: 이미지와 날짜 선택은 화면 종료 뒤 상태를 바꾸지 않는다 ===
      if (mounted && pickedFile != null) {
        setState(() => _profileImage = pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다. 다시 시도해 주세요.')));
      }
    }
  }

  Future<void> _pickBirthday() async {
    // === 수정한 내용: 공통 날짜 선택기를 사용하고 화면의 mounted 검사는 유지한다 ===
    final picked = await UiUtils.pickBirthday(
      context: context,
      selected: _selectedBirthday,
    );
    if (mounted && picked != null) setState(() => _selectedBirthday = picked);
  }

  Future<void> _completeSignUp() async {
    if (_isLoading) return;
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
      // === 수정한 내용: 프로필 설정 후 Router 경로와 화면을 함께 갱신하고 대기 중인 초대로 복귀한다 ===
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('모락에 오신 걸 환영해요'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. 모임을 만들거나 초대 링크로 참여해요.'),
                SizedBox(height: 16),
                Text('2. 만난 날짜와 참석자, 장소를 기록해요.'),
                SizedBox(height: 16),
                Text('3. 사진과 함께 그날의 추억을 돌아봐요.'),
                SizedBox(height: 20),
                Text(
                  '모임 기록과 사진은 모임 멤버끼리 볼 수 있어요.',
                  style: TextStyle(fontSize: 13, color: AppConstants.textBody),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('시작하기'),
            ),
          ],
        ),
      );
      if (mounted) context.go(destinationAfterProfile(hasProfile: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('프로필을 저장하지 못했습니다. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === 수정한 내용: 설정 화면의 로그아웃 실패를 비동기 예외 대신 재시도 메시지로 처리한다 ===
  Future<void> _signOut() async {
    try {
      await _userRepo.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '환영합니다! 🎉',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: AppConstants.textTitle,
          ),
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
          onPressed: _signOut,
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
              CustomTextField(controller: _nicknameController, hint: '예: 모락이'),
              const SizedBox(height: 28),
              const SectionTitle('생년월일'),
              const SizedBox(height: 12),
              BirthdayField(value: _selectedBirthday, onTap: _pickBirthday),
              const SizedBox(height: 56),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      )
                    : Button(text: '모락 시작하기', onPressed: _completeSignUp),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
