import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';

// === 수정한 내용: 프로필 설정·편집의 동일한 생일 입력 UI를 공통화하고 기존 표시 형식을 유지한다 ===
class BirthdayField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  const BirthdayField({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppConstants.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value != null
                ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                : '예) 1996-03-12',
            style: TextStyle(
              fontSize: 15,
              color: value != null ? Colors.black87 : Colors.grey[400],
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.calendar_month_rounded, color: Colors.grey[400], size: 20),
        ],
      ),
    ),
  );
}
