import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resolve colors from the nearest Theme so open pages update immediately
/// when the device changes between light and dark mode.
extension AppThemeContext on BuildContext {
  AppPalette get appColors => AppPalette(Theme.of(this).colorScheme);
}

class AppPalette {
  final ColorScheme scheme;
  const AppPalette(this.scheme);
  bool get isDark => scheme.brightness == Brightness.dark;
  Color get primary => scheme.primary;
  Color get primaryContainer => scheme.primaryContainer;
  Color get onPrimary => scheme.onPrimary;
  Color get secondary => scheme.secondary;
  Color get secondaryContainer => scheme.secondaryContainer;
  Color get onSecondaryContainer => scheme.onSecondaryContainer;
  Color get tertiary => scheme.tertiary;
  // Existing pages use this token for success icons and text.
  Color get tertiaryContainer =>
      isDark ? hadirText : AppColors.tertiaryContainer;
  Color get tertiaryFixedDim => scheme.tertiaryFixedDim;
  Color get background => scheme.surface;
  Color get surfaceContainerLowest => scheme.surfaceContainerLowest;
  Color get surfaceContainerLow => scheme.surfaceContainerLow;
  Color get surfaceContainer => scheme.surfaceContainer;
  Color get surfaceContainerHigh => scheme.surfaceContainerHigh;
  Color get surfaceVariant => scheme.outlineVariant;
  Color get outline => scheme.outline;
  Color get outlineVariant => scheme.outlineVariant;
  Color get onSurface => scheme.onSurface;
  Color get onSurfaceVariant => scheme.onSurfaceVariant;
  Color get error => scheme.error;
  Color get errorContainer => scheme.errorContainer;
  Color get onErrorContainer => scheme.onErrorContainer;
  Color get hadirBg => isDark ? const Color(0xFF183C2A) : AppColors.hadirBg;
  Color get hadirText => isDark ? const Color(0xFF8EDBA9) : AppColors.hadirText;
  Color get izinBg => isDark ? const Color(0xFF44351B) : AppColors.izinBg;
  Color get izinText =>
      isDark ? const Color(0xFFFFCC80) : const Color(0xFF9A5200);
  Color get dispensasiBg =>
      isDark ? const Color(0xFF123C45) : const Color(0xFFCFFAFE);
  Color get dispensasiText =>
      isDark ? const Color(0xFF80DEEA) : const Color(0xFF00677A);
  Color get liburBg =>
      isDark ? const Color(0xFF35264B) : const Color(0xFFF3E8FF);
  Color get liburText =>
      isDark ? const Color(0xFFD0B4FF) : const Color(0xFF7C3AED);
  Color get sakitBg =>
      isDark ? const Color(0xFF392F49) : const Color(0xFFE4DFEC);
  Color get sakitText =>
      isDark ? const Color(0xFFD0B4E9) : const Color(0xFF674EA7);
  Color get pengajuanText =>
      isDark ? const Color(0xFFFFA6CD) : const Color(0xFFDB2777);
}

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
  );
  static const headlineSm = TextStyle(
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );
  static const bodyLg = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const bodyMd = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
  static const labelMd = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );
  static const displayLg = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? const Color(0xFFAEC6FF) : AppColors.primary,
        onPrimary: isDark ? const Color(0xFF002B75) : AppColors.onPrimary,
        secondary: isDark ? const Color(0xFFBAC8DF) : AppColors.secondary,
        secondaryContainer: isDark
            ? const Color(0xFF35455E)
            : AppColors.secondaryContainer,
        onSecondaryContainer: isDark
            ? const Color(0xFFD0E1FB)
            : AppColors.onSecondaryContainer,
        surface: isDark ? const Color(0xFF111418) : AppColors.background,
        surfaceContainerLowest: isDark
            ? const Color(0xFF191D23)
            : AppColors.surfaceContainerLowest,
        surfaceContainerLow: isDark
            ? const Color(0xFF1D2127)
            : AppColors.surfaceContainerLow,
        surfaceContainer: isDark
            ? const Color(0xFF23272E)
            : AppColors.surfaceContainer,
        surfaceContainerHigh: isDark
            ? const Color(0xFF2B3038)
            : AppColors.surfaceContainerHigh,
        onSurface: isDark ? const Color(0xFFE3E7EE) : AppColors.onSurface,
        onSurfaceVariant: isDark
            ? const Color(0xFFBDC5D2)
            : AppColors.onSurfaceVariant,
        outlineVariant: isDark
            ? const Color(0xFF414751)
            : AppColors.surfaceVariant,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surface,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(color: scheme.surfaceContainerLowest),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF323842),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    fontFamily: 'Inter',
  );
}
