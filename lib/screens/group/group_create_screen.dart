// === 수정한 내용: 실패 시 내부 오류와 개인정보 대신 이해 가능한 재시도 메시지를 표시한다 ===
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import '../../constants/app_constants.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/common_button.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/profile/profile_setup_sheet.dart';
import '../../utils/operation_id.dart';
import '../../utils/data_refresh.dart';
import '../../widgets/common/request_error_view.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _nameController = TextEditingController();
  final _myNicknameController = TextEditingController();
  final _groupRepo = locator<GroupRepository>();
  final _userRepo = locator<UserRepository>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _profileLoaded = false;
  int? _selectedColorIndex;
  String? _selectedEmoji;
  String? _globalProfileImageUrl;

  final ImagePicker _picker = ImagePicker();
  XFile? _localProfileImage;
  XFile? _coverImage;
  XFile? _logoImage;
  bool _isBirthdayPublic = true;
  // === 수정한 내용: 같은 생성 화면의 재시도는 동일한 요청 ID로 중복 그룹을 만들지 않는다 ===
  final String _creationRequestId = newOperationId();

  String? _nameError;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    _loadGlobalProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _myNicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalProfile() async {
    // === 수정한 내용: 프로필 누락과 조회 실패는 재시도할 수 있게 하고 불완전한 정보로 생성을 막는다 ===
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _profileLoaded = false;
    });
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _myNicknameController.text = profile.displayName;
          _globalProfileImageUrl = profile.profileImageUrl;
          _isLoading = false;
          _profileLoaded = true;
        });
      }
    } catch (_) {
      // 오류 원문은 사용자에게 노출하지 않습니다.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isProfile, bool isCover) async {
    final pickedFile = (await pickImagesWithRecovery(
      context: context,
      picker: _picker,
      target: isCover
          ? 'group-create:cover'
          : (isProfile ? 'group-create:profile' : 'group-create:logo'),
      maxWidth: isCover ? 1080 : 512,
      maxHeight: isCover ? 1080 : 512,
    )).firstOrNull;
    // === 수정한 내용: 이미지와 테마 선택 결과는 폐기되지 않은 화면에만 반영한다 ===
    if (mounted && pickedFile != null) {
      setState(() {
        if (isCover) {
          _coverImage = pickedFile;
        } else if (isProfile) {
          _localProfileImage = pickedFile;
        } else {
          _logoImage =
              pickedFile; // 🌟 혹시라도 메뉴에서 바로 로고를 고를 때 대비 (현재는 시트를 통하므로 잘 안 쓰임)
        }
      });
    }
  }

  Future<void> _showProfileSetupSheet() async {
    // 🌟 모임 로고/테마 설정을 담당하는 바텀 시트 호출
    final result = await showModalBottomSheet<ProfileSetupResult>(
      // 🌟 Map 대신 타입 명시
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBackground,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProfileSetupSheet(
        recoveryTarget: 'group-create:logo',
        initialEmoji: _selectedEmoji,
        initialColorIndex: _selectedColorIndex,
      ),
    );

    // 🌟 사용자가 시트에서 '완료'를 누르고 넘겨준 데이터(result)를 변수에 매핑
    if (mounted && result != null) {
      setState(() {
        if (result.hasImage) {
          // 💡 사진을 선택한 경우: 이모지와 색상을 지우고 사진만 적용
          _logoImage = result.image;
          _selectedEmoji = null;
        } else {
          // 💡 이모지와 색상을 선택한 경우: 사진을 지우고 테마 적용
          _selectedEmoji = result.emoji;
          _selectedColorIndex = result.colorIndex;
          _logoImage = null;
        }
      });
    }
  }

  Future<void> _createGroup() async {
    if (_isSaving || _isLoading || !_profileLoaded) return;
    final groupName = _nameController.text.trim();
    final myNickname = _myNicknameController.text.trim();
    if (groupName.isEmpty || myNickname.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      // === 수정한 내용: 멤버 사진 업로드도 그룹 저장과 같은 실패 정리 경로에서 관리한다 ===
      final selectedHexColor = _selectedColorIndex != null
          ? '#${AppConstants.themeColors[_selectedColorIndex!].value.toRadixString(16).substring(2).toUpperCase()}'
          : null;

      await _groupRepo.createGroup(
        name: groupName,
        nickname: myNickname,
        emoji: _selectedEmoji,
        hexColor: selectedHexColor,
        profileImageUrl: _globalProfileImageUrl,
        memberImage: _localProfileImage,
        coverImage: _coverImage,
        logoImage: _logoImage,
        isBirthdayPublic: _isBirthdayPublic,
        requestId: _creationRequestId,
      );

      if (mounted) {
        // === 수정한 내용: 모임 생성 성공 뒤 홈에 이전 모임 목록 기반의 피드가 남지 않도록 갱신한다 ===
        refreshHomeFeed(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 모임이 생성되었습니다!'),
            backgroundColor: AppConstants.textTitle,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('요청을 완료하지 못했습니다. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🌟 뒤로가기 로직을 별도 함수로 분리
  void _handleBackNavigation() {
    if (_currentPage == 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = 0);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedColorIndex != null
        ? AppConstants.themeColors[_selectedColorIndex!]
        : AppConstants.dividerColor;

    // 🌟 PopScope 로 감싸서 시스템 뒤로가기 버튼(제스처)을 가로챕니다.
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: AppConstants.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            _currentPage == 0 ? '새 모임 만들기' : '모임 프로필 설정',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          backgroundColor: AppConstants.scaffoldBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppConstants.textTitle,
            ),
            onPressed: _handleBackNavigation, // 🌟 상단 뒤로가기 버튼도 동일 함수 연결
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppConstants.primaryColor,
                ),
              )
            : !_profileLoaded
            ? RequestErrorView(
                message: '프로필을 불러오지 못했습니다.',
                onRetry: _loadGlobalProfile,
              )
            : PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // 스와이프 차단 유지
                children: [
                  // 🌟 PAGE 1: 모임 정보
                  CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => UiUtils.showImageActionMenu(
                                  context: context,
                                  onPick: () => _pickImage(false, true),
                                  onDelete: () =>
                                      setState(() => _coverImage = null),
                                  hasImage: _coverImage != null,
                                ),
                                child: Container(
                                  height: 140,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppConstants.cardBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppConstants.borderColor,
                                    ),
                                    image: _coverImage != null
                                        ? DecorationImage(
                                            image: kIsWeb
                                                ? NetworkImage(
                                                    _coverImage!.path,
                                                  )
                                                : FileImage(
                                                    File(_coverImage!.path),
                                                  ) as ImageProvider,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _coverImage == null
                                      ? const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 36,
                                              color: AppConstants.textCaption,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '모임 대표 배경 사진 (선택)',
                                              style: TextStyle(
                                                color: AppConstants.textBody,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 32),

                              Center(
                                child: EditableAvatar(
                                  radius: 46,
                                  backgroundColor: _selectedColorIndex == null
                                      ? AppConstants.dividerColor
                                      : activeColor,
                                  localImage:
                                      _logoImage, // 🌟 바텀 시트에서 고른 사진이 여기 꽂힙니다.
                                  emoji: _selectedEmoji,
                                  fallbackIcon: Icons.color_lens_rounded,
                                  onTap: _showProfileSetupSheet,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Center(
                                child: Text(
                                  '모임 로고/테마 설정 (선택)',
                                  style: TextStyle(
                                    color: AppConstants.textCaption,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 48),

                              const SectionTitle('모임 이름', isRequired: true),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _nameController,
                                hint: '예) 모락모락 가족모임 👨‍👩‍👧‍👦',
                                errorText: _nameError,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 🌟 PAGE 2: 프로필 설정
                  CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: EditableAvatar(
                                  radius: 48,
                                  backgroundColor: AppConstants.dividerColor,
                                  localImage: _localProfileImage,
                                  networkImageUrl: _globalProfileImageUrl,
                                  fallbackIcon: Icons.person_rounded,
                                  onTap: () => UiUtils.showImageActionMenu(
                                    context: context,
                                    onPick: () => _pickImage(true, false),
                                    onDelete: () => setState(() {
                                      _localProfileImage = null;
                                      _globalProfileImageUrl = null;
                                    }),
                                    hasImage:
                                        _localProfileImage != null ||
                                        _globalProfileImageUrl != null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 48),

                              const SectionTitle(
                                '이 모임에서 사용할 닉네임',
                                isRequired: true,
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _myNicknameController,
                                hint: '박모락',
                                errorText: _nicknameError,
                              ),
                              const SizedBox(height: 24),
                              InkWell(
                                onTap: () => setState(
                                  () => _isBirthdayPublic = !_isBirthdayPublic,
                                ),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _isBirthdayPublic,
                                        onChanged: (val) => setState(
                                          () => _isBirthdayPublic = val ?? true,
                                        ),
                                        activeColor: AppConstants.primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '이 모임에 내 생일 공개하기',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppConstants.textTitle,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: _isSaving
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                    ),
                  )
                : Button(
                    text: _currentPage == 0 ? '다음' : '모임 시작하기',
                    onPressed: () {
                      setState(() {
                        _nameError = null;
                        _nicknameError = null;
                      });

                      if (_currentPage == 0) {
                        if (_nameController.text.trim().isEmpty) {
                          setState(
                            () => _nameError = '어떤 모임인지 알 수 있게 멋진 이름을 지어주세요.',
                          );
                          return;
                        }
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        setState(() => _currentPage = 1);
                      } else {
                        if (_myNicknameController.text.trim().isEmpty) {
                          setState(
                            () => _nicknameError =
                                '모임원들이 알아볼 수 있게 닉네임을 꼭 입력해 주세요.',
                          );
                          return;
                        }
                        if (_isSaving) return;
                        _createGroup();
                      }
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
