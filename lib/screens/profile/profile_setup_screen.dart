import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_skeleton.dart';
import '../../utils/ui_utils.dart'; // 🌟 공통 팝업
import '../../widgets/common_widgets.dart'; // 🌟 공통 위젯

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
          colorScheme: const ColorScheme.light(primary: Color(0xFFFF8A80)),
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
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw '로그인 정보가 없습니다.';
      String? uploadedImageUrl;

      if (_profileImage != null) {
        final ext = _profileImage!.name.split('.').last.toLowerCase();
        final fileName = '${currentUser.id}.$ext';
        await Supabase.instance.client.storage
            .from('profiles')
            .uploadBinary(
              'avatars/$fileName',
              await _profileImage!.readAsBytes(),
              fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
            );
        uploadedImageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl('avatars/$fileName');
      }

      await Supabase.instance.client.from('users').insert({
        'id': currentUser.id,
        'display_name': nickname,
        'birthday': _selectedBirthday?.toIso8601String().split('T').first,
        if (uploadedImageUrl != null) 'profile_image_url': uploadedImageUrl,
      });

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '환영합니다! 🎉',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[800]),
          onPressed: () async => await Supabase.instance.client.auth.signOut(),
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
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '나중에 언제든 변경할 수 있어요!',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // 💡 EditableAvatar 레고 블록 도입!
              Center(
                child: EditableAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[100]!,
                  localImage: _profileImage,
                  fallbackIcon: Icons.person_rounded,
                  // 💡 UiUtils 카톡 액션 메뉴 연동!
                  onTap: () => UiUtils.showImageActionMenu(
                    context: context,
                    onPick: _pickImage,
                    onDelete: () => setState(() => _profileImage = null),
                    hasImage: _profileImage != null,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 💡 SectionTitle 과 CustomTextField 도입!
              const SectionTitle('닉네임'), const SizedBox(height: 8),
              CustomTextField(controller: _nicknameController, hint: '예: 모락대장'),
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
                  onPressed: _isLoading ? null : _completeSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '모락 시작하기',
                          style: TextStyle(
                            fontSize: 18,
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
