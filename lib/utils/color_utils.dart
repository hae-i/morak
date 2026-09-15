import 'package:flutter/material.dart';

class ColorUtils {
  // 배경색 밝기에 따라 글자색(흑/백) 반환
  static Color getTextColor(Color bg) {
    return bg.computeLuminance() > 0.6 ? Colors.grey[800]! : Colors.white;
  }

  // 헥스(Hex) 문자열을 Color 객체로 변환
  static Color hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey[200]!;

    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}