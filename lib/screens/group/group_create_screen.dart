import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';
import '../../repositories/supabase_repository.dart';
import '../../widgets/profile_setup_sheet.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});
  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _nameController = TextEditingController();
  final _myNicknameController = TextEditingController();
  final _repository = SupabaseRepository();

  bool _isLoading = false;
  int? _selectedColorIndex;
  String? _selectedEmoji;

  @override
  void dispose() {
    _nameController.dispose();
    _myNicknameController.dispose();
    super.dispose();
  }

  Future<void> _showProfileSetupSheet() async {
    // 💡 분리해둔 공통 시트 호출! 리턴값을 받아옴
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ProfileSetupSheet(initialEmoji: _selectedEmoji, initialColorIndex: _selectedColorIndex),
    );

    if (result != null) {
      setState(() {
        _selectedEmoji = result['emoji'];
        _selectedColorIndex = result['colorIndex'];
      });
    }
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    final myNickname = _myNicknameController.text.trim();
    if (groupName.isEmpty || myNickname.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final colorValue = _selectedColorIndex != null ? AppConstants.themeColors[_selectedColorIndex!].value : Colors.grey[200]!.value;

      // 💡 통신은 Repository가 알아서 해줌!
      await _repository.createGroup(groupName, myNickname, _selectedEmoji, colorValue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 모임이 생성되었습니다!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('모임 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedColorIndex != null ? AppConstants.themeColors[_selectedColorIndex!] : Colors.grey[200]!;
    final isDefaultColor = _selectedColorIndex == null;
    final textColor = ColorUtils.getTextColor(activeColor);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('새 모임 만들기 ☁️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showProfileSetupSheet,
              child: CircleAvatar(
                radius: 50, backgroundColor: activeColor,
                child: _selectedEmoji != null
                    ? Text(_selectedEmoji!, style: const TextStyle(fontSize: 48))
                    : Icon(Icons.add_photo_alternate_rounded, size: 40, color: isDefaultColor ? Colors.grey[400] : textColor.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 32),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '모임 이름')),
            const SizedBox(height: 16),
            TextField(controller: _myNicknameController, decoration: const InputDecoration(labelText: '내 닉네임')),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createGroup,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('모임 시작하기'),
          ),
        ),
      ),
    );
  }
}