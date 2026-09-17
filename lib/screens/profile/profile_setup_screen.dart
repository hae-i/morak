import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_skeleton.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nicknameController = TextEditingController();

  DateTime? _selectedBirthday;
  bool _isLoading = false;

  // 🌟 프로필 사진 변수
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  // 🌟 갤러리에서 사진 고르기
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // 프로필 사진이니까 용량/크기 최적화!
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _profileImage = pickedFile);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('사진을 불러오지 못했습니다: $e')));
    }
  }

  // 🌟 생일 선택기 (DatePicker)
  Future<void> _pickBirthday() async {
    final DateTime? picked = await showDatePicker(
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
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _completeSignUp() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임을 입력해 주세요!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw '로그인 정보가 없습니다.';

      String? uploadedImageUrl;

      // 🌟 사진이 있다면 스토리지에 업로드!
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        final ext = _profileImage!.name.split('.').last.toLowerCase();
        final fileName = '${currentUser.id}.$ext'; // 내 아이디로 파일명 지정 (덮어쓰기 용이)
        final filePath = 'avatars/$fileName';

        await Supabase.instance.client.storage
            .from('profiles')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                upsert: true,
              ), // upsert: true로 기존 프사 덮어쓰기!
            );
        uploadedImageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl(filePath);
      }

      await Supabase.instance.client.from('users').insert({
        'id': currentUser.id,
        'display_name': nickname,
        'birthday': _selectedBirthday
            ?.toIso8601String()
            .split('T')
            .first, // "YYYY-MM-DD" 형식으로 저장
        if (uploadedImageUrl != null) 'profile_image_url': uploadedImageUrl,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainSkeleton()),
        );
      }
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

              // 🌟 1. 프로필 사진 첨부 영역
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: _profileImage == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 48,
                                color: Colors.grey[300],
                              )
                            : ClipOval(
                                child: kIsWeb
                                    ? Image.network(
                                        _profileImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_profileImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A80),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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

              const Text(
                '닉네임',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                maxLength: 15,
                decoration: InputDecoration(
                  hintText: '예: 모락대장',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF8A80),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🌟 2. 생년월일 입력 영역
              const Text(
                '생년월일',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
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
