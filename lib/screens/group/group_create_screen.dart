import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';
import '../../repositories/group_repository.dart';
import '../../widgets/profile_setup_sheet.dart';

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
  final _repository = GroupRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  int? _selectedColorIndex;
  String? _selectedEmoji;
  String? _globalProfileImageUrl;

  final ImagePicker _picker = ImagePicker();
  XFile? _localProfileImage;
  XFile? _coverImage;
  XFile? _logoImage; // 🌟 동그라미 로고용 변수 추가!
  bool _isBirthdayPublic = true; // 🌟 생일 공개 여부!

  @override
  void initState() {
    super.initState();
    _loadGlobalProfile();
  }

  Future<void> _loadGlobalProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('display_name, profile_image_url')
          .eq('id', userId)
          .single();
      setState(() {
        _myNicknameController.text = data['display_name'] ?? '';
        _globalProfileImageUrl = data['profile_image_url'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _myNicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null)
        setState(() {
          if (isProfile)
            _localProfileImage = pickedFile;
          else
            _logoImage = pickedFile;
        });
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      if (pickedFile != null) setState(() => _coverImage = pickedFile);
    } catch (e) {
      debugPrint('$e');
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
    if (result != null)
      setState(() {
        _selectedEmoji = result['emoji'];
        _selectedColorIndex = result['colorIndex'];
      });
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
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
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A80),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
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
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    final myNickname = _myNicknameController.text.trim();
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
      await _repository.createGroup(
        groupName,
        myNickname,
        _selectedEmoji,
        selectedHexColor,
        finalProfileImageUrl,
        _coverImage,
        _logoImage,
        _isBirthdayPublic,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedColorIndex != null
        ? AppConstants.themeColors[_selectedColorIndex!]
        : Colors.grey[200]!;
    final isDefaultColor = _selectedColorIndex == null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentPage == 0 ? '새 모임 만들기 ☁️' : '모임 프로필 설정 👤',
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
                              onTap: _pickCoverImage,
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
                            Center(
                              child: Stack(
                                children: [
                                  // 🌟 동그라미 로고 영역!
                                  GestureDetector(
                                    onTap: _showProfileSetupSheet,
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: isDefaultColor
                                          ? Colors.white
                                          : activeColor,
                                      backgroundImage: _logoImage != null
                                          ? (kIsWeb
                                                ? NetworkImage(_logoImage!.path)
                                                : FileImage(
                                                    File(_logoImage!.path),
                                                  ) as ImageProvider)
                                          : null,
                                      child: _logoImage == null
                                          ? (_selectedEmoji != null
                                                ? Text(
                                                    _selectedEmoji!,
                                                    style: const TextStyle(
                                                      fontSize: 40,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.color_lens_rounded,
                                                    size: 32,
                                                    color: Colors.grey[300],
                                                  ))
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _pickImage(false), // 로고 픽커
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF8A80),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                            _buildSectionTitle('모임 이름'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _nameController,
                              '예) 모락모락 가족모임 👨‍👩‍👧‍👦',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
                              child: GestureDetector(
                                onTap: () => _pickImage(true), // 내 프사 픽커
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: _localProfileImage != null
                                          ? ClipOval(
                                              child: kIsWeb
                                                  ? Image.network(
                                                      _localProfileImage!.path,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Image.file(
                                                      File(
                                                        _localProfileImage!
                                                            .path,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                            )
                                          : (_globalProfileImageUrl != null
                                                ? ClipOval(
                                                    child: Image.network(
                                                      _globalProfileImageUrl!,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person_rounded,
                                                    size: 48,
                                                    color: Colors.grey[400],
                                                  )),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF8A80),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildSectionTitle('이 모임에서 사용할 닉네임'),
                            const SizedBox(height: 12),
                            _buildTextField(_myNicknameController, '예) 든든한 첫째'),
                            const SizedBox(height: 24),
                            // 🌟 생일 공개 체크박스 추가!
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
                    _showWarningDialog(
                      '모임 이름이 비어있어요!',
                      '어떤 모임인지 알 수 있게\n멋진 이름을 지어주세요. ☁️',
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
                    _showWarningDialog(
                      '닉네임이 비어있어요!',
                      '모임원들이 알아볼 수 있게\n닉네임을 꼭 입력해 주세요. 👤',
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
