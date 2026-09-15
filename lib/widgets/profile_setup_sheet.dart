import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/color_utils.dart';

class ProfileSetupSheet extends StatefulWidget {
  final String? initialEmoji;
  final int? initialColorIndex;

  const ProfileSetupSheet({super.key, this.initialEmoji, this.initialColorIndex});

  @override
  State<ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends State<ProfileSetupSheet> {
  String? _selectedEmoji;
  int? _selectedColorIndex;

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.initialEmoji;
    _selectedColorIndex = widget.initialColorIndex;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('프로필 꾸미기 ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // 이모지 선택 영역
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = null),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _selectedEmoji == null ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.do_not_disturb_alt_rounded, color: Colors.grey, size: 28),
                  ),
                ),
                ...AppConstants.emojis.map((emoji) => GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _selectedEmoji == emoji ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 32),
            // 색상 선택 영역
            Wrap(
              spacing: 16, runSpacing: 16,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = null),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle, border: _selectedColorIndex == null ? Border.all(color: Colors.grey[800]!, width: 3) : null),
                    child: _selectedColorIndex == null ? Icon(Icons.check_rounded, color: Colors.grey[800]) : null,
                  ),
                ),
                ...List.generate(AppConstants.themeColors.length, (index) {
                  final color = AppConstants.themeColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.grey[800]!, width: 3) : null),
                      child: isSelected ? Icon(Icons.check_rounded, color: ColorUtils.getTextColor(color)) : null,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, {'emoji': _selectedEmoji, 'colorIndex': _selectedColorIndex}),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}