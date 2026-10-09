// Run with: flutter test tool/generate_brand_assets.dart
// Exports the same vector mark used by Flutter, without third-party tooling.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/widgets/app_logo.dart';

Future<void> exportLogo(
  String path,
  int pixels, {
  bool background = false,
  double scale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final edge = pixels.toDouble();
  if (background) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, edge, edge),
      Paint()..color = const Color(0xFFF3F7FF),
    );
  }
  canvas.translate(edge * (1 - scale) / 2, edge * (1 - scale) / 2);
  const AppLogoPainter().paint(canvas, Size.square(edge * scale));
  final picture = recorder.endRecording();
  final image = await picture.toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Export native launcher and splash assets', () async {
    await exportLogo('assets/images/logo_presensi.png', 512);
    await exportLogo(
      'assets/images/app_icon.png',
      1024,
      background: true,
      scale: 0.86,
    );
    const res = 'android/app/src/main/res';
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await exportLogo(
        '$res/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        background: true,
        scale: 0.86,
      );
    }
    // Adaptive icon masks leave a 66/108 safe area; keep the pin within it.
    await exportLogo(
      '$res/drawable-nodpi/app_icon_foreground.png',
      432,
      scale: 0.68,
    );
    await exportLogo('$res/drawable-nodpi/splash_logo.png', 512);
    const icons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest = jsonDecode(
      await File('$icons/Contents.json').readAsString(),
    ) as Map<String, dynamic>;
    for (final entry in manifest['images'] as List<dynamic>) {
      if (entry['filename'] == null) continue;
      final size = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      await exportLogo(
        '$icons/${entry['filename']}',
        (size * scale).round(),
        background: true,
        scale: 0.86,
      );
    }
    const launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await exportLogo('$launch/LaunchImage$suffix.png', 112 * scale);
    }
  });
}
