import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_selection_recovery.dart';

import '../../constants/app_constants.dart';
import '../../utils/color_utils.dart';
import '../common/common_button.dart';

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
  // === 수정한 내용: 테마 사진 복구를 원래 모임 작업과 연결하여 다른 모임에 자동 적용하지 않는다 ===
  final String recoveryTarget;
  final String? initialEmoji;
  final int? initialColorIndex;

  const ProfileSetupSheet({
    super.key,
    this.initialEmoji,
    this.initialColorIndex,
    this.recoveryTarget = 'theme-logo',
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
      final XFile? pickedFile = (await pickImagesWithRecovery(
        context: context,
        picker: _picker,
        target: widget.recoveryTarget,
      )).firstOrNull;
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
              '프로필 꾸미기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textTitle,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '테마 색상 / 사진',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppConstants.textCaption,
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
                      color: AppConstants.dividerColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppConstants.borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppConstants.textBody,
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
                            ? Border.all(
                                color: AppConstants.textTitle,
                                width: 3,
                              )
                            : Border.all(color: Colors.black12),
                      ),
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
                color: AppConstants.textCaption,
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
                          ? AppConstants.dividerColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.do_not_disturb_alt_rounded,
                      color: AppConstants.textCaption,
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
                            ? AppConstants.dividerColor
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

            // 🌟 하단 완료 버튼을 MorakButton 으로 교체!
            Button(text: '완료', onPressed: _onSubmit),
          ],
        ),
      ),
    );
  }
}
