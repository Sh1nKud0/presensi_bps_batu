import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';
import 'package:presensi_bps_batu/widgets/app_splash_screen.dart';
import 'package:presensi_bps_batu/widgets/glass_surface.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Splash fits small screens with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              textScaler: TextScaler.linear(2),
            ),
            child: GlassBackground(
              child: AppSplashScreen(onIntroCompleted: () => completed++),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(completed, 0);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(completed, 1);
      expect(find.text('magang presensi bps Batu'), findsOneWidget);
      expect(find.text('BPS Kota Batu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Reduced motion completes intro without waiting for animation', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppSplashScreen(onIntroCompleted: () => completed++),
        ),
      ),
    );
    await tester.pump();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
