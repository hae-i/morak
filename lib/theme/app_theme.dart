import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Flat sections and muted colors shared by all Material routes and overlays.
class AppTheme {
  static ThemeData get light {
    const controls = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(AppConstants.controlRadius),
      ),
    );
    const scheme = ColorScheme.light(
      primary: AppConstants.primaryColor,
      onPrimary: Colors.white,
      primaryContainer: AppConstants.secondaryColor,
      onPrimaryContainer: AppConstants.textTitle,
      secondary: AppConstants.textBody,
      onSecondary: Colors.white,
      secondaryContainer: AppConstants.dividerColor,
      onSecondaryContainer: AppConstants.textTitle,
      tertiary: AppConstants.highlightColor,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEBEFF0),
      onTertiaryContainer: AppConstants.textTitle,
      error: AppConstants.dangerColor,
      onError: Colors.white,
      errorContainer: AppConstants.dangerBackground,
      onErrorContainer: AppConstants.dangerColor,
      surface: AppConstants.scaffoldBackground,
      onSurface: AppConstants.textTitle,
      onSurfaceVariant: AppConstants.textBody,
      outline: AppConstants.textCaption,
      outlineVariant: AppConstants.borderColor,
      surfaceTint: Colors.transparent,
      surfaceDim: Color(0xFFE1E3DF),
      surfaceBright: AppConstants.scaffoldBackground,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF6F7F5),
      surfaceContainer: AppConstants.dividerColor,
      surfaceContainerHigh: Color(0xFFE7EAE5),
      surfaceContainerHighest: Color(0xFFE1E4DE),
      inverseSurface: AppConstants.primaryColor,
      onInverseSurface: Colors.white,
      inversePrimary: AppConstants.secondaryColor,
      primaryFixed: AppConstants.secondaryColor,
      primaryFixedDim: AppConstants.borderColor,
      onPrimaryFixed: AppConstants.textTitle,
      onPrimaryFixedVariant: AppConstants.textBody,
      secondaryFixed: AppConstants.dividerColor,
      secondaryFixedDim: AppConstants.borderColor,
      onSecondaryFixed: AppConstants.textTitle,
      onSecondaryFixedVariant: AppConstants.textBody,
      tertiaryFixed: Color(0xFFEBEFF0),
      tertiaryFixedDim: AppConstants.borderColor,
      onTertiaryFixed: AppConstants.textTitle,
      onTertiaryFixedVariant: AppConstants.textBody,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppConstants.scaffoldBackground,
      canvasColor: AppConstants.cardBackground,
      dividerColor: AppConstants.borderColor,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.scaffoldBackground,
        foregroundColor: AppConstants.textTitle,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppConstants.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppConstants.cardBackground,
        modalBackgroundColor: AppConstants.cardBackground,
        elevation: 0,
        modalElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppConstants.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppConstants.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(),
        endShape: RoundedRectangleBorder(),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppConstants.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppConstants.borderColor),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppConstants.primaryColor,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.fixed,
        elevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(elevation: 0, shape: controls),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: controls),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: controls),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: controls,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppConstants.dividerColor,
        selectedColor: AppConstants.secondaryColor,
        elevation: 0,
        pressElevation: 0,
        shape: controls,
        side: BorderSide.none,
        labelStyle: TextStyle(color: AppConstants.textBody),
      ),
      dividerTheme: const DividerThemeData(
        color: AppConstants.borderColor,
        thickness: 1,
      ),
    );
  }
}
