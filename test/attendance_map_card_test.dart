import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';
import 'package:presensi_bps_batu/widgets/attendance_map_card.dart';

// Render a bundled image instead of downloading any map tiles in tests.
class _LocalTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/images/logo_bps.png');
}

void main() {
  const office = LatLng(-7.8668, 112.5073);

  Widget app({
    required TileProvider tiles,
    LatLng? position,
    double? distance,
    bool ready = false,
    bool refreshing = false,
    VoidCallback? refresh,
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) => MaterialApp(
    theme: buildAppTheme(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 320,
            child: AttendanceMapCard(
              office: office,
              radius: 100,
              position: position,
              distance: distance,
              accuracy: position == null ? null : 8,
              locationReady: ready,
              refreshing: refreshing,
              onRefresh: refresh ?? () {},
              tileProvider: tiles,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('Map remains visible without GPS and refresh is available', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      app(tiles: _LocalTiles(), refresh: () => refreshes++),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Menunggu GPS'), findsOneWidget);
    final locate = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Pusatkan posisi saya',
      ),
    );
    expect(locate.onPressed, isNull);
    await tester.tap(find.text('Perbarui'));
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Refresh state does not mark a cached location as valid', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        tiles: _LocalTiles(),
        position: office,
        distance: 0,
        refreshing: true,
      ),
    );
    await tester.pump();
    expect(find.text('Mencari GPS'), findsOneWidget);
    expect(find.text('Dalam area'), findsNothing);
    final refresh = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Perbarui'),
    );
    expect(refresh.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Markers and zoom controls work in ${brightness.name}', (
      tester,
    ) async {
      const position = LatLng(-7.8665, 112.5075);
      await tester.pumpWidget(
        app(
          tiles: _LocalTiles(),
          position: position,
          distance: 50,
          ready: true,
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dalam area'), findsOneWidget);
      expect(find.text('50 m'), findsOneWidget);
      expect(find.text('Akurasi GPS ±8 m'), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final camera = map.mapController!;
      final zoom = camera.camera.zoom;
      await tester.tap(find.byTooltip('Perbesar peta'));
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, closeTo(zoom + 1, 0.01));
      await tester.tap(find.byTooltip('Perkecil peta'));
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, closeTo(zoom, 0.01));
      await tester.tap(find.byTooltip('Pusatkan posisi saya'));
      await tester.pumpAndSettle();
      expect(camera.camera.center, position);
      expect(camera.camera.zoom, 17.5);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'New GPS fix fits both points and preserves manual zoom until reset',
    (tester) async {
      final tiles = _LocalTiles();
      await tester.pumpWidget(app(tiles: tiles));
      await tester.pumpAndSettle();
      const position = LatLng(-7.8768, 112.5173);
      await tester.pumpWidget(
        app(tiles: tiles, position: position, distance: 1550, ready: true),
      );
      await tester.pumpAndSettle();
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(camera.camera.visibleBounds.contains(position), isTrue);
      expect(camera.camera.visibleBounds.contains(office), isTrue);
      expect(find.text('Di luar area'), findsOneWidget);
      expect(find.text('1.6 km'), findsOneWidget);
      await tester.tap(find.byTooltip('Perbesar peta'));
      await tester.pumpAndSettle();
      final zoom = camera.camera.zoom;
      const next = LatLng(-7.8769, 112.5174);
      await tester.pumpWidget(
        app(tiles: tiles, position: next, distance: 1560, ready: true),
      );
      await tester.pumpAndSettle();
      expect(camera.camera.zoom, zoom);
      await tester.tap(find.byTooltip('Lihat kantor dan posisi Anda'));
      await tester.pumpAndSettle();
      expect(camera.camera.visibleBounds.contains(next), isTrue);
      expect(camera.camera.visibleBounds.contains(office), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Map details remain readable with 200% text and an out-of-range status',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          tiles: _LocalTiles(),
          position: const LatLng(-7.87, 112.51),
          distance: 750,
          ready: true,
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('Jarak ke kantor'), findsOneWidget);
      expect(find.text('Perbarui'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
