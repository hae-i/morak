import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';

@immutable
class ProfileSetupResult {
  final XFile? image;
  final String? emoji;
  final int? colorIndex;

  const ProfileSetupResult({this.image, this.emoji, this.colorIndex});

  bool get hasImage => image != null;
  bool get hasEmoji => emoji != null;
  bool get hasColor => colorIndex != null;
}

class ProfileSetupSheet extends StatefulWidget {
  final String? initialEmoji;
  final int? initialColorIndex;

  const ProfileSetupSheet({
    super.key,
    this.initialEmoji,
    this.initialColorIndex,
  });
  @override
  State<ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends State<ProfileSetupSheet> {
  String? _selectedEmoji;
  int? _selectedColorIndex;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.initialEmoji;
    _selectedColorIndex = widget.initialColorIndex;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        if (!mounted) return;
        Navigator.pop(
          context,
          ProfileSetupResult(
            image: pickedFile,
            emoji: _selectedEmoji,
            colorIndex: _selectedColorIndex,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진을 가져오는 중 오류가 발생했습니다.')));
    }
  }

  void _onSubmit() {
    Navigator.pop(
      context,
      ProfileSetupResult(
        emoji: _selectedEmoji,
        colorIndex: _selectedColorIndex,
      ),
    );
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
            const Text(
              '프로필 꾸미기 ✨',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '테마 색상 / 사진',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEEEEEE),
                        width: 1.5,
                      ),
                    ), // 🌟 다이어트
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ...List.generate(AppConstants.themeColors.length, (index) {
                  final color = AppConstants.themeColors[index];
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColorIndex = index;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 3)
                            : Border.all(color: Colors.black12),
                      ), // 🌟 선택 시 블랙 선!
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: ColorUtils.getTextColor(color),
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '이모지',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEmoji = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedEmoji == null
                          ? Colors.grey[100]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.do_not_disturb_alt_rounded,
                      color: Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
                ...AppConstants.emojis.map(
                  (emoji) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = emoji;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedEmoji == emoji
                            ? Colors.grey[100]
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54, // 🌟 버튼 다이어트
              child: ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87, // 🌟 블랙
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(
                    fontSize: 16,
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
