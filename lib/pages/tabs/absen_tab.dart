import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../main.dart';
import '../../theme/app_theme.dart';

const double kLatitudeKantor = -7.8668;
const double kLongitudeKantor = 112.5073;
const double kRadiusMeter = 100;

class AbsenTab extends StatefulWidget {
  const AbsenTab({super.key});

  @override
  State<AbsenTab> createState() => _AbsenTabState();
}

class _AbsenTabState extends State<AbsenTab> {
  bool _isLoading = false;
  bool _lokasiDiambil = false;
  String _statusText = '';
  Position? _currentPosition;
  double? _jarakKeKantor;
  Map<String, dynamic>? _absensiHariIni;

  @override
  void initState() {
    super.initState();
    _cekAbsensiHariIni();
    _ambilLokasi();
  }

  Future<void> _cekAbsensiHariIni() async {
    final userId = supabase.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final response = await supabase
          .from('absensi')
          .select()
          .eq('user_id', userId)
          .eq('tanggal', today)
          .maybeSingle();
      if (mounted) setState(() => _absensiHariIni = response);
    } catch (e) {
      debugPrint('Gagal cek absensi: $e');
    }
  }

  Future<void> _ambilLokasi() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Mengambil lokasi...';
    });

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
        _statusText = '';
      });
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _statusText = '';
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final jarak = Geolocator.distanceBetween(
        position.latitude, position.longitude, kLatitudeKantor, kLongitudeKantor,
      );
      setState(() {
        _currentPosition = position;
        _jarakKeKantor = jarak;
        _lokasiDiambil = true;
      });
    } catch (e) {
      debugPrint('Gagal ambil lokasi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = '';
        });
      }
    }
  }

  Future<void> _kirimAbsensi() async {
    if (!_lokasiDiambil || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi belum siap, coba lagi sebentar.')),
      );
      return;
    }

    final sudahMasuk = _absensiHariIni != null && _absensiHariIni!['jam_masuk'] != null;
    final isMasuk = !sudahMasuk;

    if (_jarakKeKantor! > kRadiusMeter) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Di Luar Area Kantor'),
          content: Text(
            'Anda berada ${_jarakKeKantor!.toStringAsFixed(0)} meter dari kantor BPS Kota Batu.\n\n'
            'Presensi hanya bisa dilakukan dalam radius $kRadiusMeter meter.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = 'Mengirim presensi...';
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final now = DateTime.now().toUtc().toIso8601String();

      if (isMasuk) {
        final inserted = await supabase
            .from('absensi')
            .insert({
              'user_id': userId,
              'tanggal': today,
              'jam_masuk': now,
              'latitude_masuk': _currentPosition!.latitude,
              'longitude_masuk': _currentPosition!.longitude,
              'jarak_dari_kantor_meter': _jarakKeKantor,
              'status': 'hadir',
            })
            .select()
            .single();
        if (mounted) setState(() => _absensiHariIni = inserted);
      } else {
        final updated = await supabase
            .from('absensi')
            .update({
              'jam_pulang': now,
              'latitude_pulang': _currentPosition!.latitude,
              'longitude_pulang': _currentPosition!.longitude,
            })
            .eq('user_id', userId)
            .eq('tanggal', today)
            .select()
            .single();
        if (mounted) setState(() => _absensiHariIni = updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMasuk ? 'Absen masuk berhasil!' : 'Absen pulang berhasil!'),
          backgroundColor: AppColors.tertiaryContainer,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sudahMasuk = _absensiHariIni != null && _absensiHariIni!['jam_masuk'] != null;
    final sudahPulang = _absensiHariIni != null && _absensiHariIni!['jam_pulang'] != null;
    final selesai = sudahMasuk && sudahPulang;
    final dalamRadius = _jarakKeKantor != null && _jarakKeKantor! <= kRadiusMeter;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lakukan Absensi', style: AppText.headlineMdMobile),
          const SizedBox(height: 16),

          // Kartu peta / lokasi
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceVariant),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Peta asli (OpenStreetMap)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: _currentPosition == null
                      ? Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Center(child: CircularProgressIndicator()),
                        )
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            initialZoom: 17,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.presensi_bps_batu',
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: const ll.LatLng(kLatitudeKantor, kLongitudeKantor),
                                  radius: kRadiusMeter,
                                  useRadiusInMeter: true,
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderColor: AppColors.primary.withOpacity(0.4),
                                  borderStrokeWidth: 1.5,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                // Marker kantor BPS
                                Marker(
                                  point: const ll.LatLng(kLatitudeKantor, kLongitudeKantor),
                                  width: 32,
                                  height: 32,
                                  child: Icon(Icons.apartment, color: AppColors.secondary, size: 28),
                                ),
                                // Marker lokasi user
                                Marker(
                                  point: ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.location_on, color: AppColors.primary, size: 36),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.my_location, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lokasi Saat Ini', style: AppText.labelMd.copyWith(color: AppColors.onSurface)),
                                const SizedBox(height: 2),
                                Text(
                                  _currentPosition == null
                                      ? 'Mencari lokasi...'
                                      : 'Lat ${_currentPosition!.latitude.toStringAsFixed(4)}, Long ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                  style: AppText.bodyMd,
                                ),
                                if (_jarakKeKantor != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Jarak dari kantor: ${_jarakKeKantor!.toStringAsFixed(0)} m',
                                      style: AppText.bodyMd.copyWith(fontSize: 12, color: AppColors.secondary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPosition == null
                                  ? AppColors.outline
                                  : dalamRadius
                                      ? AppColors.tertiaryFixedDim
                                      : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentPosition == null
                                ? 'Menunggu lokasi'
                                : dalamRadius
                                    ? 'Dalam radius kantor'
                                    : 'Di luar radius kantor',
                            style: AppText.labelMd.copyWith(
                              color: _currentPosition == null
                                  ? AppColors.outline
                                  : dalamRadius
                                      ? AppColors.tertiaryContainer
                                      : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info status hari ini
          if (selesai)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.hadirBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.hadirText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Presensi hari ini sudah lengkap (masuk & pulang).',
                      style: AppText.bodyMd.copyWith(color: AppColors.hadirText),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _kirimAbsensi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.9)),
                      )
                    : Text(
                        sudahMasuk ? 'Kirim Absen Pulang' : 'Kirim Absen Masuk',
                        style: AppText.headlineSm.copyWith(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_statusText, style: AppText.bodyMd, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}