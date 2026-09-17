import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/ui_utils.dart'; // 🌟 공통 팝업
import '../../widgets/common_widgets.dart'; // 🌟 공통 위젯

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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final data = await Supabase.instance.client
          .from('users')
          .select('display_name, profile_image_url, birthday')
          .eq('id', user.id)
          .single();
      setState(() {
        _nicknameController.text = data['display_name'] ?? '';
        _existingProfileImageUrl = data['profile_image_url'];
        if (data['birthday'] != null)
          _selectedBirthday = DateTime.parse(data['birthday']);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) setState(() => _localProfileImage = pickedFile);
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
          colorScheme: const ColorScheme.light(primary: Color(0xFFFF8A80)),
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
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw '로그인 정보가 없습니다.';
      String? finalImageUrl = _existingProfileImageUrl;

      if (_localProfileImage != null) {
        final ext = _localProfileImage!.name.split('.').last.toLowerCase();
        final fileName = '${currentUser.id}.$ext';
        await Supabase.instance.client.storage
            .from('profiles')
            .uploadBinary(
              'avatars/$fileName',
              await _localProfileImage!.readAsBytes(),
              fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
            );
        finalImageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl('avatars/$fileName');
      }

      await Supabase.instance.client
          .from('users')
          .update({
            'display_name': nickname,
            'birthday': _selectedBirthday?.toIso8601String().split('T').first,
            if (finalImageUrl != null) 'profile_image_url': finalImageUrl,
          })
          .eq('id', currentUser.id);

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
              child: CircularProgressIndicator(color: Color(0xFFFF8A80)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 💡 EditableAvatar 레고 블록 도입!
                  Center(
                    child: EditableAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[100]!,
                      localImage: _localProfileImage,
                      networkImageUrl: _existingProfileImageUrl,
                      fallbackIcon: Icons.person_rounded,
                      // 💡 UiUtils 카톡 액션 메뉴 연동!
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

                  // 💡 SectionTitle 과 CustomTextField 도입!
                  const SectionTitle('닉네임'), const SizedBox(height: 8),
                  CustomTextField(
                    controller: _nicknameController,
                    hint: '예: 모락대장',
                  ),
                  const SizedBox(height: 24),

                  const SectionTitle('생년월일'), const SizedBox(height: 8),
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
                        backgroundColor: const Color(0xFFFF8A80),
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
