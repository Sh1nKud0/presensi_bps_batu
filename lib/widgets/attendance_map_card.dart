import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/link.dart';

import '../theme/app_theme.dart';

class AttendanceMapCard extends StatefulWidget {
  final LatLng office;
  final LatLng? position;
  final double radius;
  final double? distance;
  final double? accuracy;
  final bool locationReady;
  final bool refreshing;
  final VoidCallback onRefresh;
  final TileProvider? tileProvider;

  const AttendanceMapCard({
    super.key,
    required this.office,
    required this.radius,
    required this.onRefresh,
    this.position,
    this.distance,
    this.accuracy,
    this.locationReady = false,
    this.refreshing = false,
    this.tileProvider,
  });

  @override
  State<AttendanceMapCard> createState() => _AttendanceMapCardState();
}

class _AttendanceMapCardState extends State<AttendanceMapCard> {
  final _controller = MapController();
  bool _ready = false;
  bool _followLocation = true;

  CameraFit _fit() {
    const distance = Distance();
    return CameraFit.coordinates(
      coordinates: [
        for (final bearing in [0, 90, 180, 270])
          distance.offset(widget.office, widget.radius, bearing.toDouble()),
        if (widget.position != null) widget.position!,
      ],
      padding: const EdgeInsets.fromLTRB(40, 65, 76, 40),
      maxZoom: 17.5,
    );
  }

  @override
  void didUpdateWidget(covariant AttendanceMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        _followLocation &&
        (widget.position != oldWidget.position ||
            widget.office != oldWidget.office ||
            widget.radius != oldWidget.radius)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready && _followLocation) _controller.fitCamera(_fit());
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double delta) {
    if (!_ready) return;
    _followLocation = false;
    _controller.move(
      _controller.camera.center,
      (_controller.camera.zoom + delta).clamp(3.0, 19.0),
    );
  }

  // Apply the visual treatment only to map tiles, keeping markers and text crisp.
  ColorFilter _tileColors(bool dark) => ColorFilter.matrix(
    dark
        ? const [
            -0.2126,
            -0.7152,
            -0.0722,
            0,
            235,
            -0.2126,
            -0.7152,
            -0.0722,
            0,
            238,
            -0.2126,
            -0.7152,
            -0.0722,
            0,
            244,
            0,
            0,
            0,
            1,
            0,
          ]
        : const [
            0.6063,
            0.3576,
            0.0361,
            0,
            0,
            0.1063,
            0.8576,
            0.0361,
            0,
            0,
            0.1063,
            0.3576,
            0.5361,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final inside = widget.distance != null && widget.distance! <= widget.radius;
    final status = !widget.locationReady
        ? (widget.refreshing ? 'Mencari GPS' : 'Menunggu GPS')
        : inside
        ? 'Dalam area'
        : 'Di luar area';
    final statusBg = !widget.locationReady
        ? colors.surfaceContainerHigh
        : inside
        ? colors.hadirBg
        : colors.errorContainer;
    final statusColor = !widget.locationReady
        ? colors.onSurfaceVariant
        : inside
        ? colors.hadirText
        : colors.onErrorContainer;
    final distance = widget.distance == null
        ? '—'
        : widget.distance! >= 1000
        ? '${(widget.distance! / 1000).toStringAsFixed(1)} km'
        : '${widget.distance!.toStringAsFixed(0)} m';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.surfaceVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area presensi',
                        style: AppText.bodyLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'BPS Kota Batu',
                        style: AppText.bodyMd.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 290,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.office,
                    initialZoom: 17,
                    initialCameraFit: _fit(),
                    minZoom: 3,
                    maxZoom: 19,
                    backgroundColor: colors.surfaceContainerLow,
                    onMapReady: () => _ready = true,
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture) _followLocation = false;
                    },
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.presensi_bps_batu',
                      maxNativeZoom: 19,
                      tileProvider: widget.tileProvider,
                      tileBuilder: (context, tile, image) => image.loadError
                          ? Container(
                              color: colors.surfaceContainerLow,
                              child: Center(
                                child: Text(
                                  'Peta tidak tersedia',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                          : ColorFiltered(
                              colorFilter: _tileColors(colors.isDark),
                              child: tile,
                            ),
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: widget.office,
                          radius: widget.radius,
                          useRadiusInMeter: true,
                          color: colors.primary.withValues(alpha: 0.12),
                          borderColor: colors.primary.withValues(alpha: 0.65),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.office,
                          width: 48,
                          height: 48,
                          child: Tooltip(
                            message: 'Kantor BPS Kota Batu',
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.surfaceContainerLowest,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.account_balance_rounded,
                                color: colors.onPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        if (widget.position != null)
                          Marker(
                            point: widget.position!,
                            width: 30,
                            height: 30,
                            child: Tooltip(
                              message: 'Posisi Anda',
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surfaceContainerLowest,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    elevation: 3,
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Perbesar peta',
                          onPressed: () => _zoom(1),
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Perkecil peta',
                          onPressed: () => _zoom(-1),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Lihat kantor dan posisi Anda',
                          icon: const Icon(Icons.center_focus_strong),
                          onPressed: () {
                            if (!_ready) return;
                            _followLocation = true;
                            _controller.fitCamera(_fit());
                          },
                        ),
                        IconButton(
                          tooltip: 'Pusatkan posisi saya',
                          icon: const Icon(Icons.my_location),
                          onPressed: widget.position == null
                              ? null
                              : () {
                                  if (!_ready) return;
                                  _followLocation = false;
                                  _controller.move(widget.position!, 17.5);
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: colors.surfaceContainerLowest.withValues(
                      alpha: 0.94,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Link(
                        uri: Uri.parse(
                          'https://www.openstreetmap.org/copyright',
                        ),
                        target: LinkTarget.blank,
                        builder: (context, followLink) => InkWell(
                          onTap: followLink,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jarak ke kantor',
                        style: AppText.labelMd.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(distance, style: AppText.headlineSm),
                      if (widget.accuracy != null)
                        Text(
                          'Akurasi GPS ±${widget.accuracy!.toStringAsFixed(0)} m',
                          style: AppText.bodyMd.copyWith(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  icon: widget.refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Perbarui'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
