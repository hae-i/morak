import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../widgets/common/common_button.dart';

class UiUtils {
  // === 수정한 내용: 프로필 생일 선택의 기본 날짜·범위·테마를 한곳에서 유지한다 ===
  static Future<DateTime?> pickBirthday({
    required BuildContext context,
    DateTime? selected,
  }) => showDatePicker(
    context: context,
    initialDate: selected ?? DateTime(1996, 3, 12),
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppConstants.primaryColor,
        ),
      ),
      child: child!,
    ),
  );

  // 🌟 1. 공통 모던 다이얼로그 (확인/취소 묻기)
  static Future<bool?> showBeautifulDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: confirmColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textTitle,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppConstants.textBody,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      text: '취소',
                      color: AppConstants.dividerColor,
                      textColor: AppConstants.textCaption,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Button(
                      text: confirmText,
                      color: confirmColor,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 2. 공통 경고창 (빈칸 알림 등)
  static void showWarningDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppConstants.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppConstants.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textTitle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppConstants.textBody,
                ),
              ),
              const SizedBox(height: 24),
              Button(text: '확인', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  // 🌟 3. 하단 사진 액션 메뉴 (앨범/삭제)
  static void showImageActionMenu({
    required BuildContext context,
    required VoidCallback onPick,
    required VoidCallback onDelete,
    required bool hasImage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBackground,
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
                  color: AppConstants.textTitle,
                ),
                title: const Text(
                  '앨범에서 사진 선택',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textTitle,
                  ),
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
                    color: AppConstants.dangerColor,
                  ),
                  title: const Text(
                    '사진 삭제하기',
                    style: TextStyle(
                      color: AppConstants.dangerColor,
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
}
