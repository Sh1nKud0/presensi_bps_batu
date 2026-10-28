import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:presensi_bps_batu/widgets/evidence_picker.dart';

class _Picker extends ImagePicker {
  ImageSource? source;
  bool denied = false;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    if (denied) throw PlatformException(code: 'camera_access_denied');
    return XFile('/test/bukti.jpg');
  }
}

void main() {
  Widget app(_Picker picker, ValueChanged<XFile?> result) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result(await pilihBukti(context, picker: picker)),
          child: const Text('Lampirkan'),
        ),
      ),
    ),
  );

  for (final source in ImageSource.values) {
    testWidgets('Evidence can be selected using ${source.name}', (
      tester,
    ) async {
      final picker = _Picker();
      XFile? result;
      await tester.pumpWidget(app(picker, (file) => result = file));
      await tester.tap(find.text('Lampirkan'));
      await tester.pumpAndSettle();
      expect(find.text('Ambil foto'), findsOneWidget);
      expect(find.text('Pilih dari galeri'), findsOneWidget);
      await tester.tap(
        find.text(
          source == ImageSource.camera ? 'Ambil foto' : 'Pilih dari galeri',
        ),
      );
      await tester.pumpAndSettle();
      expect(picker.source, source);
      expect(result?.path, '/test/bukti.jpg');
    });
  }
  testWidgets('Cancelling does not open a camera or replace the attachment', (
    tester,
  ) async {
    final picker = _Picker();
    XFile? result = XFile('/existing.jpg');
    await tester.pumpWidget(
      app(picker, (file) {
        if (file != null) result = file;
      }),
    );
    await tester.tap(find.text('Lampirkan'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Ambil foto'))).pop();
    await tester.pumpAndSettle();
    expect(picker.source, isNull);
    expect(result?.path, '/existing.jpg');
  });
  testWidgets('Denied camera permission displays an actionable message', (
    tester,
  ) async {
    final picker = _Picker()..denied = true;
    await tester.pumpWidget(app(picker, (_) {}));
    await tester.tap(find.text('Lampirkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Izin kamera atau galeri ditolak'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
