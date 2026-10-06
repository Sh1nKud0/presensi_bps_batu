import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/attendance_map_card.dart';
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
  String? _keteranganLibur; // null kalau bukan hari libur
  String? _errorLokasi;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  @override
  void initState() {
    super.initState();
    _cekHariLibur();
    _cekAbsensiHariIni();
    _ambilLokasi();

    // Auto-retry begitu user menyalakan GPS, tanpa perlu keluar-masuk app
    _serviceStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled && _currentPosition == null) {
        _ambilLokasi();
      }
    });
  }

  @override
  void dispose() {
    _serviceStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _cekHariLibur() async {
    final now = DateTime.now();

    // Cek weekend otomatis
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      setState(() => _keteranganLibur = now.weekday == DateTime.saturday ? 'Hari Sabtu (Libur)' : 'Hari Minggu (Libur)');
      return;
    }

    // Cek hari libur yang diinput admin
    try {
      final today = now.toIso8601String().substring(0, 10);
      final response = await supabase
          .from('hari_libur')
          .select()
          .eq('tanggal', today)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() => _keteranganLibur = response['keterangan']);
      }
    } catch (e) {
      debugPrint('Gagal cek hari libur: $e');
    }
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
      _errorLokasi = null;
    });

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
        _statusText = '';
        _errorLokasi = 'Izin lokasi ditolak. Aktifkan izin lokasi di pengaturan HP.';
      });
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
        _statusText = '';
        _errorLokasi = 'GPS/Lokasi tidak aktif. Nyalakan GPS di HP Anda — halaman ini otomatis lanjut begitu GPS aktif.';
      });
      return;
    }

    // Tampilkan lokasi terakhir yang diketahui dulu (instan), sambil menunggu fix baru yang akurat
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted && _currentPosition == null) {
        final jarakSementara = Geolocator.distanceBetween(
          lastKnown.latitude, lastKnown.longitude, kLatitudeKantor, kLongitudeKantor,
        );
        setState(() {
          _currentPosition = lastKnown;
          _jarakKeKantor = jarakSementara;
          _statusText = 'Menyempurnakan akurasi lokasi...';
        });
      }
    } catch (_) {
      // abaikan, lanjut coba getCurrentPosition
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Waktu habis mencari lokasi'),
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
      if (mounted && _currentPosition == null) {
        setState(() {
          _errorLokasi = 'Gagal mendapat lokasi akurat. Coba pastikan Anda di area terbuka (dekat jendela/luar ruangan), lalu coba lagi.';
        });
      }
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
    if (_keteranganLibur != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hari ini adalah hari libur, presensi tidak diperlukan.')),
      );
      return;
    }

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lakukan Absensi', style: AppText.headlineMdMobile),
          const SizedBox(height: 16),

          AttendanceMapCard(
            office: const ll.LatLng(kLatitudeKantor, kLongitudeKantor),
            radius: kRadiusMeter,
            position: _currentPosition == null ? null : ll.LatLng(
              _currentPosition!.latitude, _currentPosition!.longitude),
            distance: _jarakKeKantor,
            accuracy: _currentPosition?.accuracy,
            locationReady: _lokasiDiambil,
            refreshing: _isLoading,
            onRefresh: _ambilLokasi,
          ),
          const SizedBox(height: 24),

          // Banner error lokasi (GPS mati, izin ditolak, timeout, dll)
          if (_errorLokasi != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.appColors.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_off, color: context.appColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorLokasi!,
                          style: TextStyle(color: context.appColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _ambilLokasi,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Coba Lagi'),
                      style: OutlinedButton.styleFrom(foregroundColor: context.appColors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Banner hari libur - blokir presensi
          if (_keteranganLibur != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.liburBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.beach_access, color: context.appColors.liburText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari Libur: $_keteranganLibur',
                          style: TextStyle(color: context.appColors.liburText, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Presensi tidak diperlukan hari ini.',
                          style: TextStyle(color: context.appColors.liburText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (selesai)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.hadirBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: context.appColors.hadirText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Presensi hari ini sudah lengkap (masuk & pulang).',
                      style: AppText.bodyMd.copyWith(color: context.appColors.hadirText),
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
                  backgroundColor: context.appColors.primary,
                  foregroundColor: context.appColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.onPrimary.withValues(alpha: 0.9)),
                      )
                    : Text(
                        sudahMasuk ? 'Kirim Absen Pulang' : 'Kirim Absen Masuk',
                        style: AppText.headlineSm.copyWith(color: context.appColors.onPrimary, fontSize: 16),
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