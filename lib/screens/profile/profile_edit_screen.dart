import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  XFile? _localProfileImage; // 갤러리에서 새로 고른 사진
  String? _existingProfileImageUrl; // DB에 있던 기존 사진

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  // 🌟 내 기존 정보 불러오기
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
        if (data['birthday'] != null) {
          _selectedBirthday = DateTime.parse(data['birthday']);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
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
    if (picked != null) setState(() => _selectedBirthday = picked);
  }

  Future<void> _updateProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임을 입력해 주세요!')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw '로그인 정보가 없습니다.';

      String? finalImageUrl = _existingProfileImageUrl;

      if (_localProfileImage != null) {
        final bytes = await _localProfileImage!.readAsBytes();
        final ext = _localProfileImage!.name.split('.').last.toLowerCase();
        final fileName = '${currentUser.id}.$ext';
        final filePath = 'avatars/$fileName';

        await Supabase.instance.client.storage
            .from('profiles')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
            );
        finalImageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl(filePath);
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
        Navigator.pop(context, true); // 수정 성공 후 마이페이지로 돌아감!
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showImageActionMenu({
    required VoidCallback onPick,
    required VoidCallback onDelete,
    required bool hasImage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.black87,
                ),
                title: const Text(
                  '앨범에서 사진 선택',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onPick();
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    '사진 삭제하기',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
                  Center(
                    child: GestureDetector(
                      // 🌟 메뉴 연동!
                      onTap: () => _showImageActionMenu(
                        onPick: _pickImage,
                        onDelete: () => setState(() {
                          _localProfileImage = null;
                          _existingProfileImageUrl = null;
                        }),
                        hasImage:
                            _localProfileImage != null ||
                            _existingProfileImageUrl != null,
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: _localProfileImage != null
                            ? ClipOval(
                                child: kIsWeb
                                    ? Image.network(
                                        _localProfileImage!.path,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_localProfileImage!.path),
                                        fit: BoxFit.cover,
                                      ),
                              )
                            : (_existingProfileImageUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        _existingProfileImageUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: Colors.grey[300],
                                    )),
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
