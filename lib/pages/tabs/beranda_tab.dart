import '../../widgets/adaptive_tiles.dart';
import '../../widgets/glass_surface.dart';
import '../pembatalan_pulang_page.dart';
import '../../services/checkout_cancellation.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/daily_attendance.dart';
import '../../theme/app_theme.dart';
import '../../widgets/request_notifications_button.dart';

class BerandaTab extends StatefulWidget {
  final VoidCallback onAbsenTap;
  final bool isActive;
  const BerandaTab({super.key, required this.onAbsenTap, this.isActive = true});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> with WidgetsBindingObserver {
  bool _loading = true;
  DailyAttendance? _daily;
  String? _attendanceError;
  Map<String, dynamic>? _absensiHariIni;
  String _namaUser = '';
  bool _isAdmin = false;
  bool _profileLoaded = false;
  bool _refreshing = false;
  bool _hariLibur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muatData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BerandaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _muatData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _muatData();
  }

  Future<void> _muatData() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() => _loading = true);
    try {
      final userId = appData.userId!;

      if (!_profileLoaded) {
        final profile = await appData.profile();
        if (!mounted) return;
        setState(() {
          _profileLoaded = true;
          _isAdmin = profile['role'] == 'admin';
          _namaUser = profile['nama_lengkap'] ?? 'Peserta';
        });
      }

      final daily = await DailyAttendanceRepository().load(userId);
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _attendanceError = null;
        _absensiHariIni = daily.attendance;
        _hariLibur = daily.holiday;
      });
    } catch (e) {
      debugPrint('Gagal muat data beranda: $e');
      if (mounted) setState(() => _attendanceError = 'Status presensi belum dapat dimuat. Tarik untuk mencoba lagi.');
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatJam(dynamic value) {
    if (value == null) return '--:--';
    final dt = DateTime.parse(value.toString()).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Duration _durasiKerja() {
    if (_absensiHariIni == null || _absensiHariIni!['jam_masuk'] == null) return Duration.zero;
    final masuk = DateTime.parse(_absensiHariIni!['jam_masuk'].toString());
    final akhir = _absensiHariIni!['jam_pulang'] != null
        ? DateTime.parse(_absensiHariIni!['jam_pulang'].toString())
        : DateTime.now().toUtc();
    return akhir.difference(masuk);
  }

  @override
  Widget build(BuildContext context) {
    final sudahMasuk = _absensiHariIni != null && _absensiHariIni!['jam_masuk'] != null;
    final sudahPulang = _absensiHariIni != null && _absensiHariIni!['jam_pulang'] != null;
    final durasi = _durasiKerja();
    final jamKerjaPenuh = durasi.inHours >= 8;
    final blocked = _attendanceError ?? _daily?.blockReason;

    return RefreshIndicator(
      onRefresh: _muatData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header nama aplikasi
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo BPS - kalau asset belum ditambahkan, otomatis fallback ke ikon placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo_bps.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: context.appColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance, color: context.appColors.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'magang presensi bps Batu',
                  style: AppText.headlineMdMobile.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              if (_profileLoaded && appData.loggedIn)
                RequestNotificationsButton(
                  key: ValueKey('${appData.userId!}/$_isAdmin'),
                  userId: appData.userId!,
                  isAdmin: _isAdmin,
                )
              else
                const IconButton(
                  tooltip: 'Memuat notifikasi',
                  onPressed: null,
                  icon: Icon(Icons.notifications_outlined),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppText.bodyLg.copyWith(fontSize: 16, color: context.appColors.onSurface),
              children: [
                const TextSpan(text: 'Halo, '),
                TextSpan(
                  text: _namaUser.isEmpty ? 'Peserta' : _namaUser,
                  style: TextStyle(color: context.appColors.primary, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' 👋'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Siap untuk mulai berkarya hari ini?', style: AppText.bodyMd),
          const SizedBox(height: 24),

          // Kartu status hari ini (tanpa badge tanggal di header)
          GlassSurface(
            padding: const EdgeInsets.all(16),
            radius: 24,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('STATUS HARI INI', style: AppText.labelMd),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _formatTanggalLengkap(),
                    textAlign: TextAlign.center,
                    style: AppText.headlineSm.copyWith(
                      color: context.appColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AdaptiveTiles(minTileWidth: 88, maxColumns: 3,
                  children: [
                    _statusKolom(
                        icon: Icons.login,
                        iconColor: context.appColors.tertiaryContainer,
                        value: _formatJam(_absensiHariIni?['jam_masuk']),
                        label: 'Masuk',
                    ),
                    _statusKolom(
                        icon: Icons.logout,
                        iconColor: sudahPulang ? context.appColors.secondary : context.appColors.outline,
                        value: _formatJam(_absensiHariIni?['jam_pulang']),
                        label: 'Pulang',
                    ),
                    _statusKolom(
                        icon: jamKerjaPenuh ? Icons.flag_circle : Icons.schedule,
                        iconColor: jamKerjaPenuh ? context.appColors.tertiaryContainer : context.appColors.primary,
                        value: '${durasi.inHours}j ${durasi.inMinutes % 60}m',
                        label: jamKerjaPenuh ? 'Kerja • 8j+' : 'Kerja',
                        valueColor: jamKerjaPenuh ? context.appColors.tertiaryContainer : context.appColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol utama
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: ElevatedButton.icon(
              onPressed: _loading || blocked != null || _daily == null ? null : widget.onAbsenTap,
              icon: const Icon(Icons.fingerprint, size: 28),
              label: Text(
                _loading ? 'Memeriksa presensi...' : blocked != null ? 'Presensi tidak tersedia' : sudahMasuk ? 'Absen Pulang' : 'Absen Sekarang',
                style: AppText.headlineSm.copyWith(color: context.appColors.onPrimary),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.primary,
                foregroundColor: context.appColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),

          if (blocked != null && !_loading) ...[
            const SizedBox(height: 12),
            Text(blocked, style: TextStyle(color: context.appColors.onSurfaceVariant)),
          ],
          if (canCancelCheckout(_absensiHariIni, hasActiveRequest: _daily?.requestBlockReason != null))
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PembatalanPulangPage()));
                if (mounted) await _muatData();
              },
              icon: const Icon(Icons.undo),
              label: const Text('Ajukan Pembatalan Absen Pulang'),
            ),
          // Reminder: belum absen masuk, sudah lewat jam 08:00, dan bukan hari libur
          if (!_loading && blocked == null && !sudahMasuk && !_hariLibur && DateTime.now().hour >= 8) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.appColors.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.notification_important, color: context.appColors.error, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anda belum absen hari ini!',
                          style: AppText.bodyMd.copyWith(
                            color: context.appColors.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Segera lakukan presensi. Jika ada kendala (kegiatan di luar BPS/GPS error), ajukan Absen Susulan di menu Profil.',
                          style: AppText.bodyMd.copyWith(color: context.appColors.onErrorContainer, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (jamKerjaPenuh) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.appColors.hadirBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_circle, color: context.appColors.hadirText, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Target jam kerja hari ini sudah tercapai (8 jam+).',
                      style: AppText.bodyMd.copyWith(color: context.appColors.hadirText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTanggalLengkap() {
    const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulan = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final now = DateTime.now();
    return '${hari[now.weekday - 1]}, ${now.day} ${bulan[now.month]} ${now.year}';
  }

  Widget _statusKolom({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: AppText.headlineSm.copyWith(color: valueColor ?? context.appColors.onSurface)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: AppText.labelMd.copyWith(fontSize: 11)),
      ],
    );
  }
}
