import 'package:flutter/material.dart';

class ColorUtils {
  static Color getTextColor(Color bg) {
    return bg.computeLuminance() > 0.6 ? Colors.grey[800]! : Colors.white;
  }

  static Color stringToColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return Colors.grey[200]!;

    if (colorString.startsWith('#')) {
      final buffer = StringBuffer();
      if (colorString.length == 7) buffer.write('ff');
      buffer.write(colorString.replaceFirst('#', ''));
      return Color(int.tryParse(buffer.toString(), radix: 16) ?? Colors.grey[200]!.value);
    }

    final intColor = int.tryParse(colorString);
    return intColor != null ? Color(intColor) : Colors.grey[200]!;
  }
}