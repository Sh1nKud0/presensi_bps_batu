import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:presensi_bps_batu/main.dart';
import 'package:presensi_bps_batu/pages/login_page.dart';
import 'package:presensi_bps_batu/pages/tabs/beranda_tab.dart';
import 'package:presensi_bps_batu/pages/register_page.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';
import 'package:presensi_bps_batu/theme/theme_controller.dart';
import 'package:presensi_bps_batu/widgets/theme_switch_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appThemeController.load();
  });

  test('Stored theme is restored, with light as the initial default', () async {
    final controller = AppThemeController();
    await controller.load();
    expect(controller.value, ThemeMode.light);
    await controller.setDarkMode(true);
    final restored = AppThemeController();
    await restored.load();
    expect(restored.value, ThemeMode.dark);
    await restored.setDarkMode(false);
    await controller.load();
    expect(controller.value, ThemeMode.light);
    controller.dispose();
    restored.dispose();
  });

  testWidgets('Default stays light even when the device uses dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(LoginPage))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Theme switch updates all routes and saves the choice', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final loginContext = tester.element(find.byType(LoginPage));
    Navigator.of(loginContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: ThemeSwitchTile()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.text('Mode gelap'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(
      Theme.of(tester.element(find.byType(ThemeSwitchTile))).brightness,
      Brightness.dark,
    );
    final restored = AppThemeController();
    await restored.load();
    expect(restored.value, ThemeMode.dark);
    await tester.tap(find.text('Mode gelap'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await restored.load();
    expect(restored.value, ThemeMode.light);
    Navigator.of(tester.element(find.byType(ThemeSwitchTile))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(LoginPage))).brightness,
      Brightness.light,
    );
    restored.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Home greeting remains readable in ${brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: brightness),
          home: Scaffold(body: BerandaTab(onAbsenTap: () {})),
        ),
      );
      await tester.pumpAndSettle();
      final greeting = tester.widget<Text>(find.textContaining('Halo, '));
      final context = tester.element(find.textContaining('Halo, '));
      expect(
        greeting.textSpan!.style!.color,
        Theme.of(context).colorScheme.onSurface,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Login validation and registration work in ${brightness.name}',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await appThemeController.setDarkMode(brightness == Brightness.dark);
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pumpAndSettle();
        expect(find.text('Email tidak boleh kosong'), findsOneWidget);
        expect(find.text('Password tidak boleh kosong'), findsOneWidget);
        await tester.tap(find.text('Belum punya akun? Daftar di sini'));
        await tester.pumpAndSettle();
        expect(find.byType(RegisterPage), findsOneWidget);
        expect(
          Theme.of(tester.element(find.byType(RegisterPage))).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull);
      },
    );
    test(
      'Text, buttons and badges have readable contrast in ${brightness.name}',
      () {
        final colors = AppPalette(
          buildAppTheme(brightness: brightness).colorScheme,
        );
        final pairs = [
          (colors.onSurface, colors.background),
          (colors.onSurfaceVariant, colors.surfaceContainerLowest),
          (colors.onPrimary, colors.primary),
          (colors.hadirText, colors.hadirBg),
          (colors.izinText, colors.izinBg),
          (colors.dispensasiText, colors.dispensasiBg),
          (colors.liburText, colors.liburBg),
          (colors.sakitText, colors.sakitBg),
        ];
        for (final (text, background) in pairs) {
          final a = text.computeLuminance();
          final b = background.computeLuminance();
          final contrast = a > b
              ? (a + 0.05) / (b + 0.05)
              : (b + 0.05) / (a + 0.05);
          expect(
            contrast,
            greaterThanOrEqualTo(4.5),
            reason: '$text on $background',
          );
        }
      },
    );
  }
}
