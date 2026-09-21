import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF00288E);
  static const primaryContainer = Color(0xFF1E40AF);
  static const onPrimary = Color(0xFFFFFFFF);

  static const secondary = Color(0xFF505F76);
  static const secondaryContainer = Color(0xFFD0E1FB);
  static const onSecondaryContainer = Color(0xFF54647A);

  static const tertiary = Color(0xFF003D27);
  static const tertiaryContainer = Color(0xFF00563A);
  static const tertiaryFixedDim = Color(0xFF4EDEA3);

  static const background = Color(0xFFF7F9FB);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const surfaceContainerHigh = Color(0xFFE6E8EA);
  static const surfaceVariant = Color(0xFFE0E3E5);

  static const outline = Color(0xFF757684);
  static const outlineVariant = Color(0xFFC4C5D5);

  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF444653);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Badge warna khusus riwayat
  static const hadirBg = Color(0xFFE6F4EA);
  static const hadirText = Color(0xFF137333);
  static const izinBg = Color(0xFFFEF7E0);
  static const izinText = Color(0xFFB06000);
}

class AppText {
  static const headlineMdMobile = TextStyle(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const headlineSm = TextStyle(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const bodyLg = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );
  static const bodyMd = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );
  static const labelMd = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.onSurfaceVariant,
  );
  static const displayLg = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.onSurface,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    ),
    fontFamily: 'Inter',
  );
}