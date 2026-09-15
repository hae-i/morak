import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _myNicknameController = TextEditingController();
  bool _isLoading = false;

  final List<Color> _themeColors = const [
    Color(0xFFFF8A80), Color(0xFFFFCC80), Color(0xFFFFF59D),
    Color(0xFFA5D6A7), Color(0xFF81D4FA), Color(0xFFCE93D8),
  ];
  final List<String> _emojis = ['🍻', '🥩', '⚾️', '✈️', '💻', '🏕️', '☕️', '🎤', '🏀', '🎂', '🐶', '📚'];

  int? _selectedColorIndex;
  String? _selectedEmoji;

  @override
  void dispose() {
    _nameController.dispose();
    _myNicknameController.dispose();
    super.dispose();
  }

  Color _getTextColor(Color bg) {
    return bg.computeLuminance() > 0.6 ? Colors.grey[800]! : Colors.white;
  }

  void _showProfileSetupSheet() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 24),
                        const Text('프로필 꾸미기 ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),

                        Text('대표 이모지', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12, runSpacing: 12,
                          children: [
                            GestureDetector(
                              onTap: () { setState(() => _selectedEmoji = null); setSheetState(() {}); },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _selectedEmoji == null ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.do_not_disturb_alt_rounded, color: Colors.grey, size: 28),
                              ),
                            ),
                            ..._emojis.map((emoji) => GestureDetector(
                              onTap: () { setState(() => _selectedEmoji = emoji); setSheetState(() {}); },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: _selectedEmoji == emoji ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                                child: Text(emoji, style: const TextStyle(fontSize: 28)),
                              ),
                            )),
                          ],
                        ),
                        const SizedBox(height: 32),

                        Text('배경 색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16, runSpacing: 16,
                          children: [
                            GestureDetector(
                              onTap: () { setState(() => _selectedColorIndex = null); setSheetState(() {}); },
                              child: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: _selectedColorIndex == null ? Border.all(color: Colors.grey[800]!, width: 3) : null),
                                child: _selectedColorIndex == null ? Icon(Icons.check_rounded, color: Colors.grey[800]) : null,
                              ),
                            ),
                            ...List.generate(_themeColors.length, (index) {
                              final color = _themeColors[index];
                              final isSelected = _selectedColorIndex == index;
                              return GestureDetector(
                                onTap: () { setState(() => _selectedColorIndex = index); setSheetState(() {}); },
                                child: Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.grey[800]!, width: 3) : null),
                                  child: isSelected ? Icon(Icons.check_rounded, color: _getTextColor(color)) : null,
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    final myNickname = _myNicknameController.text.trim();

    if (groupName.isEmpty || myNickname.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) throw '로그인 정보가 없습니다. 다시 로그인해주세요.';

      final int themeColorValue = _selectedColorIndex != null
          ? _themeColors[_selectedColorIndex!].value
          : Colors.grey[200]!.value;

      // groups 테이블에 모임 생성
      final groupData = await Supabase.instance.client.from('groups').insert({
        'name': groupName,
        'description': '',
        'theme_color': themeColorValue.toString(),
        'theme_emoji': _selectedEmoji,
      }).select().single();

      final String newGroupId = groupData['id'];

      // group_members 테이블에 방장으로 추가
      await Supabase.instance.client.from('group_members').insert({
        'group_id': newGroupId,
        'user_id': currentUser.id,
        'role': 'host',
        'display_name': myNickname, // 🌟 해결책 2: nickname을 DB 기둥 이름(display_name)과 똑같이 맞춤!
        'joined_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 모임이 생성되었습니다!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모임 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _selectedColorIndex != null ? _themeColors[_selectedColorIndex!] : Colors.grey[200]!;
    final isDefaultColor = _selectedColorIndex == null;
    final textColor = _getTextColor(activeColor);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('새 모임 만들기 ☁️')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showProfileSetupSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                      child: Center(child: _selectedEmoji != null ? Text(_selectedEmoji!, style: const TextStyle(fontSize: 48)) : Icon(Icons.groups_rounded, color: isDefaultColor ? Colors.grey[400] : textColor, size: 48)),
                    ),
                    Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 16))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Text('어떤 모임인가요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _nameController, maxLength: 30, decoration: InputDecoration(hintText: '모임 이름', filled: true, fillColor: Colors.white, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDefaultColor ? Colors.grey[400]! : activeColor, width: 1.5)))),
            const SizedBox(height: 24),
            const Text('이 모임에서 사용할 내 이름은?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _myNicknameController, decoration: InputDecoration(hintText: '내 이름', filled: true, fillColor: Colors.white, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDefaultColor ? Colors.grey[400]! : activeColor, width: 1.5)))),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(backgroundColor: isDefaultColor ? Colors.grey[800] : activeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('모임 만들기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDefaultColor ? Colors.white : textColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}