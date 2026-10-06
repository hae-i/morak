import 'package:flutter/material.dart';

class AppConstants {
  // 🌟 1. 메인 브랜드 컬러
  static const Color primaryColor = Color(0xFF65524D); // 코코아 브라운
  static const Color secondaryColor = Color(0xFFF3D2BA); // 살구 베이지

  // 🌟 2. 배경 컬러 (이 두 개를 조합!)
  static const Color scaffoldBackground = Color(0xFFFAF6F3); // 앱 전체 바닥
  static const Color cardBackground = Colors.white; // 둥근 박스/카드 배경

  // 🌟 3. 텍스트 컬러 (단계별 통일)
  static const Color textTitle = Color(0xFF212121); // 진한 흑색 (기존 black87 대체)
  static const Color textBody = Color(0xFF757575); // 기본 회색 (기존 grey[600] 대체)
  static const Color textCaption = Color(0xFF9E9E9E); // 연한 회색 (기존 grey[400] 대체)

  // 🌟 4. 테두리 및 구분선 (파편화된 Hex 코드들 싹 다 통합!)
  static const Color borderColor = Color(0xFFEEEEEE);
  static const Color dividerColor = Color(0xFFF5F5F5);

  // 🌟 5. 상태 컬러
  static const Color dangerColor = Color(0xFFFF5252); // 기존 redAccent 대체
  static const Color highlightColor = Color(0xFF3F51B5); // 기존 indigo 대체

  static const List<Color> themeColors = [
    Color(0xFFFF8A80),
    Color(0xFFFFB74D),
    Color(0xFFFFD54F),
    Color(0xFFAED581),
    Color(0xFF4DD0E1),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
    Color(0xFFF06292),
    Color(0xFF90A4AE),
    Color(0xFF795548),
  ];

  static const List<String> emojis = [
    '🍻',
    '🥩',
    '⚾️',
    '✈️',
    '💻',
    '🏕️',
    '☕️',
    '🎤',
    '🏀',
    '🎂',
    '🐶',
    '📚',
  ];
}
