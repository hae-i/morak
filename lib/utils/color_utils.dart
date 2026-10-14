import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class ColorUtils {
  // Keep the original illustration geometry and alpha while softening its colors.
  static const illustrationFilter = ColorFilter.matrix([
    0.44882,
    0.50064,
    0.05054,
    0,
    0,
    0.14882,
    0.80064,
    0.05054,
    0,
    0,
    0.14882,
    0.50064,
    0.35054,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  /// Muting is for display only; parsing/serialization preserve stored colors.
  static Color muted(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(hsl.saturation.clamp(0, 0.14)).toColor();
  }

  static Color displayThemeColor(String? colorString) =>
      muted(stringToColor(colorString));

  static Color getTextColor(Color bg) {
    final luminance = bg.computeLuminance();
    final darkContrast =
        (luminance + 0.05) / (AppConstants.textTitle.computeLuminance() + 0.05);
    final lightContrast = 1.05 / (luminance + 0.05);
    return darkContrast >= lightContrast
        ? AppConstants.textTitle
        : Colors.white;
  }

  static Color stringToColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return Colors.grey[200]!;
    if (colorString.startsWith('#')) {
      final buffer = StringBuffer();
      if (colorString.length == 7) buffer.write('ff');
      buffer.write(colorString.replaceFirst('#', ''));
      return Color(
        int.tryParse(buffer.toString(), radix: 16) ?? Colors.grey[200]!.value,
      );
    }
    final intColor = int.tryParse(colorString);
    return intColor != null ? Color(intColor) : Colors.grey[200]!;
  }

  static Color getReadableColor(Color color) {
    if (color == Colors.grey[200]) return Colors.grey[800]!;

    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness > 0.6) {
      return hsl.withLightness(0.4).toColor(); // 명도를 40%로 확 낮춰서 가독성 확보!
    }
    return color;
  }
}
