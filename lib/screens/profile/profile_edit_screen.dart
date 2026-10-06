// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import '../../utils/ui_utils.dart';
import '../../widgets/profile/birthday_field.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/common_button.dart';
import '../../constants/app_constants.dart';
import '../../locator.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/common/request_error_view.dart';

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
  bool _profileLoaded = false;

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
    // === 수정한 내용: 누락된 프로필과 조회 실패를 무한 로딩 대신 재시도로 처리하고 저장을 차단한다 ===
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _profileLoaded = false;
    });
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _nicknameController.text = profile.displayName;
          _existingProfileImageUrl = profile.profileImageUrl;
          if (profile.birthday != null) {
            _selectedBirthday = DateTime.tryParse(profile.birthday!);
          }
          _isLoading = false;
          _profileLoaded = true;
        });
      }
    } catch (e) {
      // 오류 원문은 화면이나 로그에 노출하지 않습니다.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = (await pickImagesWithRecovery(
        context: context,
        picker: _picker,
        target: 'global-profile',
      )).firstOrNull;
      // === 수정한 내용: 비동기 이미지 선택 완료 후 살아 있는 화면에서만 상태를 바꾼다 ===
      if (mounted && picked != null) {
        setState(() => _localProfileImage = picked);
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

  Future<void> _updateProfile() async {
    if (_isSaving || !_profileLoaded) return;
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
    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          '내 계정 편집',
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
          : !_profileLoaded
          ? RequestErrorView(
              message: '프로필을 불러오지 못했습니다.',
              onRetry: _loadMyProfile,
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
                  BirthdayField(value: _selectedBirthday, onTap: _pickBirthday),
                  const SizedBox(height: 56),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _isSaving
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppConstants.primaryColor,
                            ),
                          )
                        : Button(text: '수정 완료', onPressed: _updateProfile),
                  ),
                ],
              ),
            ),
    );
  }
}
