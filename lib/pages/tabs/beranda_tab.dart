import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class BerandaTab extends StatefulWidget {
  final VoidCallback onAbsenTap;
  const BerandaTab({super.key, required this.onAbsenTap});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> {
  bool _loading = true;
  Map<String, dynamic>? _absensiHariIni;
  String _namaUser = '';
  bool _hariLibur = false;

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final profile = await supabase.from('profiles').select('nama_lengkap').eq('id', userId).single();

      final absensiHariIni = await supabase
          .from('absensi')
          .select()
          .eq('user_id', userId)
          .eq('tanggal', today)
          .maybeSingle();

      // Cek apakah hari ini libur (weekend atau hari libur admin) - supaya reminder tidak muncul
      final now = DateTime.now();
      bool hariLibur = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
      if (!hariLibur) {
        final libur = await supabase.from('hari_libur').select().eq('tanggal', today).maybeSingle();
        hariLibur = libur != null;
      }

      setState(() {
        _namaUser = profile['nama_lengkap'] ?? 'Peserta';
        _absensiHariIni = absensiHariIni;
        _hariLibur = hariLibur;
      });
    } catch (e) {
      debugPrint('Gagal muat data beranda: $e');
    } finally {
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
                  'Presensi Magang',
                  style: AppText.headlineMdMobile.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: AppText.bodyLg.copyWith(fontSize: 16),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.surfaceVariant),
            ),
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
                Row(
                  children: [
                    Expanded(
                      child: _statusKolom(
                        icon: Icons.login,
                        iconColor: context.appColors.tertiaryContainer,
                        value: _formatJam(_absensiHariIni?['jam_masuk']),
                        label: 'Masuk',
                      ),
                    ),
                    Container(width: 1, height: 48, color: context.appColors.surfaceVariant),
                    Expanded(
                      child: _statusKolom(
                        icon: Icons.logout,
                        iconColor: sudahPulang ? context.appColors.secondary : context.appColors.outline,
                        value: _formatJam(_absensiHariIni?['jam_pulang']),
                        label: 'Pulang',
                      ),
                    ),
                    Container(width: 1, height: 48, color: context.appColors.surfaceVariant),
                    Expanded(
                      child: _statusKolom(
                        icon: jamKerjaPenuh ? Icons.flag_circle : Icons.schedule,
                        iconColor: jamKerjaPenuh ? context.appColors.tertiaryContainer : context.appColors.primary,
                        value: '${durasi.inHours}j ${durasi.inMinutes % 60}m',
                        label: jamKerjaPenuh ? 'Kerja • 8j+' : 'Kerja',
                        valueColor: jamKerjaPenuh ? context.appColors.tertiaryContainer : context.appColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tombol utama
          SizedBox(
            height: 64,
            child: ElevatedButton.icon(
              onPressed: sudahMasuk && sudahPulang ? null : widget.onAbsenTap,
              icon: const Icon(Icons.fingerprint, size: 28),
              label: Text(
                sudahMasuk && sudahPulang ? 'Presensi Hari Ini Selesai' : 'Absen Sekarang',
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

          // Reminder: belum absen masuk, sudah lewat jam 08:00, dan bukan hari libur
          if (!_loading && !sudahMasuk && !_hariLibur && DateTime.now().hour >= 8) ...[
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
                          'Segera lakukan presensi. Jika ada kendala (dinas luar/GPS error), ajukan Absen Susulan di menu Profil.',
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
        Text(value, style: AppText.headlineSm.copyWith(color: valueColor ?? context.appColors.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: AppText.labelMd.copyWith(fontSize: 11)),
      ],
    );
  }
}
