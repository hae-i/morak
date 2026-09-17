import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/common/common_widgets.dart';
import '../../locator.dart';
import '../../repositories/group_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/profile/profile_setup_sheet.dart';

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
  int? _selectedColorIndex;
  String? _selectedEmoji;
  String? _globalProfileImageUrl;

  final ImagePicker _picker = ImagePicker();
  XFile? _localProfileImage;
  XFile? _coverImage;
  XFile? _logoImage;
  bool _isBirthdayPublic = true;

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
    try {
      final profile = await _userRepo.fetchMyGlobalProfile();
      if (profile != null && mounted) {
        setState(() {
          _myNicknameController.text = profile.displayName;
          _globalProfileImageUrl = profile.profileImageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isProfile, bool isCover) async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isCover ? 1080 : 512,
      maxHeight: isCover ? 1080 : 512,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        if (isCover)
          _coverImage = pickedFile;
        else if (isProfile)
          _localProfileImage = pickedFile;
        else
          _logoImage = pickedFile;
      });
    }
  }

  Future<void> _showProfileSetupSheet() async {
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
          _logoImage = result['image'];
          _selectedEmoji = null;
        } else {
          _selectedEmoji = result['emoji'];
          _selectedColorIndex = result['colorIndex'];
          _logoImage = null;
        }
      });
    }
  }
  // ... [상단 import 및 클래스 선언 생략 (기존 파일 앞부분 동일)] ...

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim(); // 🌟 변수명 주의
    final myNickname = _myNicknameController.text.trim(); // 🌟 변수명 주의
    setState(() => _isSaving = true);

    try {
      String? finalProfileImageUrl = _globalProfileImageUrl;
      if (_localProfileImage != null) {
        final ext = _localProfileImage!.name.split('.').last.toLowerCase();
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final fileName =
            '${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage
            .from('profiles')
            .uploadBinary(
              'avatars/$fileName',
              await _localProfileImage!.readAsBytes(),
              fileOptions: FileOptions(contentType: 'image/$ext'),
            );
        finalProfileImageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl('avatars/$fileName');
      }
      final selectedHexColor = _selectedColorIndex != null
          ? '#${AppConstants.themeColors[_selectedColorIndex!].value.toRadixString(16).substring(2).toUpperCase()}'
          : null;

      // 🌟 [에러 해결] 파라미터 이름을 명시적으로 지정하여 컴파일 에러 해결!
      await _groupRepo.createGroup(
        name: groupName, // 🌟 name -> groupName
        nickname: myNickname, // 🌟 nickname -> myNickname
        emoji: _selectedEmoji,
        hexColor: selectedHexColor,
        profileImageUrl: finalProfileImageUrl,
        coverImage: _coverImage,
        logoImage: _logoImage,
        isBirthdayPublic: _isBirthdayPublic,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('🎉 모임이 생성되었습니다!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedColorIndex != null
        ? AppConstants.themeColors[_selectedColorIndex!]
        : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentPage == 0 ? '새 모임 만들기 ☁️' : '모임 프로필 설정',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[800]),
          onPressed: () {
            if (_currentPage == 1) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentPage = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8A80)),
            )
          : PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
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
                              // 💡 UiUtils로 한 줄 컷!
                              onTap: () => UiUtils.showImageActionMenu(
                                context: context,
                                onPick: () => _pickImage(false, true),
                                onDelete: () =>
                                    setState(() => _coverImage = null),
                                hasImage: _coverImage != null,
                              ),
                              child: Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.grey[200]!,
                                    width: 2,
                                  ),
                                  image: _coverImage != null
                                      ? DecorationImage(
                                          image: kIsWeb
                                              ? NetworkImage(_coverImage!.path)
                                              : FileImage(
                                                  File(_coverImage!.path),
                                                ) as ImageProvider,
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _coverImage == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 40,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '모임 대표 배경 사진 (선택)',
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
                            const SizedBox(height: 32),

                            // 💡 EditableAvatar 레고 블록으로 한 줄 컷!
                            Center(
                              child: EditableAvatar(
                                radius: 48,
                                backgroundColor: _selectedColorIndex == null
                                    ? Colors.white
                                    : activeColor,
                                localImage: _logoImage,
                                emoji: _selectedEmoji,
                                fallbackIcon: Icons.color_lens_rounded,
                                onTap: _showProfileSetupSheet,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                '터치해서 모임 로고/테마 변경 ✨',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // 💡 CustomTextField 레고 블록으로 두 줄 컷!
                            const SectionTitle('모임 이름'),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _nameController,
                              hint: '예) 모락모락 가족모임 👨‍👩‍👧‍👦',
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
                            // 💡 EditableAvatar 레고 블록으로 한 줄 컷!
                            Center(
                              child: EditableAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200]!,
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
                            const SizedBox(height: 40),

                            // 💡 CustomTextField 레고 블록으로 두 줄 컷!
                            const SectionTitle('이 모임에서 사용할 닉네임'),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _myNicknameController,
                              hint: '예) 든든한 첫째',
                            ),

                            const SizedBox(height: 24),
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isBirthdayPublic,
                                    onChanged: (val) => setState(
                                      () => _isBirthdayPublic = val ?? true,
                                    ),
                                    activeColor: const Color(0xFFFF8A80),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '이 모임에 내 생일 공개하기 🎂',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
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
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage == 0) {
                  if (_nameController.text.trim().isEmpty) {
                    UiUtils.showWarningDialog(
                      context: context,
                      title: '모임 이름이 비어있어요!',
                      message: '어떤 모임인지 알 수 있게\n멋진 이름을 지어주세요. ☁️',
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
                    UiUtils.showWarningDialog(
                      context: context,
                      title: '닉네임이 비어있어요!',
                      message: '모임원들이 알아볼 수 있게\n닉네임을 꼭 입력해 주세요. 👤',
                    );
                    return;
                  }
                  if (_isSaving) return;
                  _createGroup();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _currentPage == 0 ? '다음' : '모임 시작하기',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
