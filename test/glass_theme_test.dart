import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:presensi_bps_batu/pages/admin_dashboard_page.dart';
import 'package:presensi_bps_batu/pages/izin_page.dart';
import 'package:presensi_bps_batu/pages/tabs/absen_susulan_page.dart';
import 'package:presensi_bps_batu/pages/tabs/riwayat_tab.dart';
import 'package:presensi_bps_batu/pages/tabs/profil_tab.dart';
import 'package:presensi_bps_batu/pages/tabs/beranda_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/pages/login_page.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';
import 'package:presensi_bps_batu/widgets/glass_surface.dart';
import 'package:presensi_bps_batu/widgets/glass_bottom_navigation.dart';

class _TestAuthStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: FlutterAuthClientOptions(
        pkceAsyncStorage: _TestAuthStorage(),
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final brightness in Brightness.values) {
    testWidgets(
      'Glass navigation keeps all destinations usable on a narrow screen in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: GlassBackground(child: child!),
            ),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Text('Tab $selected'),
                bottomNavigationBar: GlassBottomNavigation(
                  selectedIndex: selected,
                  onSelected: (index) => setState(() => selected = index),
                ),
              ),
            ),
          ),
        );
        for (final (index, label) in [
          'Beranda',
          'Absen',
          'Riwayat',
          'Profil',
        ].indexed) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text('Tab $index'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Glass login scrolls with keyboard and enlarged text in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: GlassBackground(child: child!),
            ),
            home: const LoginPage(),
          ),
        );
        await tester.pumpAndSettle();
        final login = find.widgetWithText(ElevatedButton, 'Login');
        await tester.ensureVisible(login);
        await tester.tap(login);
        await tester.pumpAndSettle();
        expect(find.text('Email tidak boleh kosong'), findsOneWidget);
        expect(find.text('Password tidak boleh kosong'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'High contrast removes blur while glass actions remain tappable',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Scaffold(
              body: GlassSurface(
                blur: true,
                child: TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('Buka'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in <String, Widget>{
    'Rekap admin': const AdminDashboardPage(initialTab: 1),
    'Izin': const IzinPage(),
    'Susulan': const AbsenSusulanPage(),
    'Riwayat': const RiwayatTab(),
    'Profil': const ProfilTab(),
    'Beranda': BerandaTab(onAbsenTap: () {}),
  }.entries) {
    testWidgets('${entry.key} remains readable at 320px and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: GlassBackground(child: child!),
          ),
          home: Scaffold(body: entry.value),
        ),
      );
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(tester.element(find.byWidget(entry.value)))
          .clearSnackBars();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final vertical = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      );
      for (var i = 0; i < 5 && vertical.evaluate().isNotEmpty; i++) {
        await tester.drag(vertical.first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
