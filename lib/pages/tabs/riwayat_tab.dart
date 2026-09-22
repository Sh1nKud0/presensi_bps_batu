import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class RiwayatTab extends StatefulWidget {
  const RiwayatTab({super.key});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

enum _StatusHari { hadir, terlambat, izin, sakit, dinasLuar, tidakAda }

class _RiwayatTabState extends State<RiwayatTab> {
  bool _loading = true;
  int _bulan = DateTime.now().month;
  int _tahun = DateTime.now().year;

  // key: tanggal (1-31) -> data
  Map<int, Map<String, dynamic>> _dataAbsensiPerTanggal = {};
  Map<int, Map<String, dynamic>> _dataIzinPerTanggal = {};
  Map<int, String> _dataHariLiburPerTanggal = {}; // tanggal -> keterangan
  List<Map<String, dynamic>> _aktivitasTerbaru = [];

  static const namaBulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  static const namaHariSingkat = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  Future<void> _muatData() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final awal = DateTime(_tahun, _bulan, 1).toIso8601String().substring(0, 10);
      final akhir = DateTime(_tahun, _bulan + 1, 0).toIso8601String().substring(0, 10);

      final absensi = await supabase
          .from('absensi')
          .select()
          .eq('user_id', userId)
          .gte('tanggal', awal)
          .lte('tanggal', akhir);

      final izin = await supabase
          .from('izin')
          .select()
          .eq('user_id', userId)
          .gte('tanggal_mulai', awal)
          .lte('tanggal_mulai', akhir);

      final hariLibur = await supabase
          .from('hari_libur')
          .select()
          .gte('tanggal', awal)
          .lte('tanggal', akhir);

      final mapHariLibur = <int, String>{};
      for (final h in hariLibur) {
        final tgl = DateTime.parse(h['tanggal'].toString()).day;
        mapHariLibur[tgl] = h['keterangan'];
      }

      final mapAbsensi = <int, Map<String, dynamic>>{};
      for (final a in absensi) {
        final tgl = DateTime.parse(a['tanggal'].toString()).day;
        mapAbsensi[tgl] = a;
      }

      final mapIzin = <int, Map<String, dynamic>>{};
      for (final i in izin) {
        final tgl = DateTime.parse(i['tanggal_mulai'].toString()).day;
        mapIzin[tgl] = i;
      }

      // Gabungkan untuk daftar aktivitas terbaru, urutkan tanggal desc
      final gabungan = <Map<String, dynamic>>[];
      mapAbsensi.forEach((tgl, data) => gabungan.add({'tipe': 'absensi', 'tanggal': tgl, 'data': data}));
      mapIzin.forEach((tgl, data) => gabungan.add({'tipe': 'izin', 'tanggal': tgl, 'data': data}));
      gabungan.sort((a, b) => (b['tanggal'] as int).compareTo(a['tanggal'] as int));

      setState(() {
        _dataAbsensiPerTanggal = mapAbsensi;
        _dataIzinPerTanggal = mapIzin;
        _dataHariLiburPerTanggal = mapHariLibur;
        _aktivitasTerbaru = gabungan;
      });
    } catch (e) {
      debugPrint('Gagal muat riwayat: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _gantiBulan(int delta) {
    setState(() {
      _bulan += delta;
      if (_bulan > 12) {
        _bulan = 1;
        _tahun++;
      } else if (_bulan < 1) {
        _bulan = 12;
        _tahun--;
      }
    });
    _muatData();
  }

  _StatusHari _statusTanggal(int tanggal) {
    if (_dataAbsensiPerTanggal.containsKey(tanggal)) {
      final a = _dataAbsensiPerTanggal[tanggal]!;
      if (a['status'] == 'dinas_luar') return _StatusHari.dinasLuar;
      if (a['jam_masuk'] != null) {
        final jamMasuk = DateTime.parse(a['jam_masuk'].toString()).toLocal();
        if (jamMasuk.hour > 7 || (jamMasuk.hour == 7 && jamMasuk.minute > 30)) {
          return _StatusHari.terlambat;
        }
        return _StatusHari.hadir;
      }
    }
    if (_dataIzinPerTanggal.containsKey(tanggal)) {
      final i = _dataIzinPerTanggal[tanggal]!;
      return i['jenis'] == 'sakit' ? _StatusHari.sakit : _StatusHari.izin;
    }
    return _StatusHari.tidakAda;
  }

  Color _warnaDot(_StatusHari status) {
    switch (status) {
      case _StatusHari.hadir:
        return AppColors.tertiaryContainer;
      case _StatusHari.terlambat:
        return const Color(0xFFB06000);
      case _StatusHari.izin:
      case _StatusHari.sakit:
        return AppColors.primaryContainer;
      case _StatusHari.dinasLuar:
        return const Color(0xFF0891B2);
      case _StatusHari.tidakAda:
        return Colors.transparent;
    }
  }

  String _formatJam(dynamic value) {
    if (value == null) return '--:--';
    final dt = DateTime.parse(value.toString()).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final jumlahHariBulan = DateTime(_tahun, _bulan + 1, 0).day;
    final hariPertama = DateTime(_tahun, _bulan, 1);
    final slotKosongDiAwal = hariPertama.weekday - 1; // Senin=1 -> 0 slot kosong

    final now = DateTime.now();
    final isBulanIni = now.year == _tahun && now.month == _bulan;

    int totalHadir = 0;
    int totalTerlambat = 0;
    int totalIzin = 0;
    int totalLibur = 0;

    for (int d = 1; d <= jumlahHariBulan; d++) {
      final tgl = DateTime(_tahun, _bulan, d);
      final isWeekend = tgl.weekday == DateTime.saturday || tgl.weekday == DateTime.sunday;
      if (isWeekend || _dataHariLiburPerTanggal.containsKey(d)) {
        totalLibur++;
        continue;
      }
      final status = _statusTanggal(d);
      if (status == _StatusHari.hadir) {
        totalHadir++;
      } else if (status == _StatusHari.terlambat) {
        totalHadir++;
        totalTerlambat++;
      } else if (status == _StatusHari.izin || status == _StatusHari.sakit) {
        totalIzin++;
      }
    }

    return RefreshIndicator(
      onRefresh: _muatData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Riwayat', style: AppText.headlineMdMobile),
          const SizedBox(height: 16),

          // Kontrol bulan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
            ),
            child: Row(
              children: [
                _tombolBulan(Icons.chevron_left, () => _gantiBulan(-1)),
                Expanded(
                  child: Column(
                    children: [
                      Text('PERIODE MAGANG', style: AppText.labelMd.copyWith(fontSize: 10)),
                      Text('${namaBulan[_bulan]} $_tahun', style: AppText.headlineSm),
                    ],
                  ),
                ),
                _tombolBulan(Icons.chevron_right, () => _gantiBulan(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kalender
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  // Header hari
                  Row(
                    children: List.generate(7, (i) {
                      final isWeekend = i >= 5;
                      return Expanded(
                        child: Center(
                          child: Text(
                            namaHariSingkat[i],
                            style: AppText.labelMd.copyWith(
                              color: isWeekend ? AppColors.error : AppColors.onSurfaceVariant,
                              fontWeight: isWeekend ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  // Grid tanggal
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 2,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: slotKosongDiAwal + jumlahHariBulan,
                    itemBuilder: (context, index) {
                      if (index < slotKosongDiAwal) return const SizedBox();

                      final tanggal = index - slotKosongDiAwal + 1;
                      final tglObj = DateTime(_tahun, _bulan, tanggal);
                      final isWeekend = tglObj.weekday == DateTime.saturday || tglObj.weekday == DateTime.sunday;
                      final isHariIni = isBulanIni && tanggal == now.day;
                      final status = _statusTanggal(tanggal);
                      final keteranganLibur = _dataHariLiburPerTanggal[tanggal];

                      if (isWeekend) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$tanggal',
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        );
                      }

                      if (keteranganLibur != null) {
                        return Tooltip(
                          message: keteranganLibur,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$tanggal',
                              style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: isHariIni ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$tanggal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHariIni ? FontWeight.w700 : FontWeight.w500,
                                color: isHariIni ? Colors.white : AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isHariIni ? Colors.white70 : _warnaDot(status),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Legenda
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _legendaItem(AppColors.tertiaryContainer, 'Hadir'),
                        _legendaItem(const Color(0xFFB06000), 'Terlambat'),
                        _legendaItem(AppColors.primaryContainer, 'Izin/Sakit'),
                        _legendaItem(const Color(0xFF0891B2), 'Dinas Luar'),
                        _legendaItem(const Color(0xFF7C3AED), 'Libur Nasional'),
                        Text('Sab/Min Libur', style: AppText.labelMd.copyWith(color: AppColors.error, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Statistik 2x2
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              _kartuStat(Icons.check_circle, AppColors.tertiaryContainer, 'Total Hadir', '$totalHadir', 'Hari'),
              _kartuStat(Icons.timer, const Color(0xFFB06000), 'Terlambat', '$totalTerlambat', 'Kali'),
              _kartuStat(Icons.assignment, AppColors.primary, 'Izin/Sakit', '$totalIzin', 'Hari'),
              _kartuStat(Icons.weekend, AppColors.error, 'Hari Libur', '$totalLibur', 'Hari'),
            ],
          ),
          const SizedBox(height: 24),

          // Aktivitas terbaru
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aktivitas Presensi Terakhir', style: AppText.headlineSm.copyWith(fontSize: 16)),
              if (!_loading && _aktivitasTerbaru.isNotEmpty)
                Text('${_aktivitasTerbaru.length} entri', style: AppText.labelMd.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(8),
              child: _aktivitasTerbaru.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Belum ada aktivitas di bulan ini', style: AppText.bodyMd, textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _aktivitasTerbaru.length,
                      itemBuilder: (context, index) => _kartuAktivitas(_aktivitasTerbaru[index]),
                    ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _tombolBulan(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.onSurface),
      ),
    );
  }

  Widget _legendaItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: AppText.labelMd.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _kartuStat(IconData icon, Color color, String label, String value, String satuan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.labelMd.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const SizedBox(width: 4),
                    Text(satuan, style: AppText.labelMd.copyWith(fontSize: 10, color: color)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuAktivitas(Map<String, dynamic> item) {
    final tipe = item['tipe'] as String;
    final data = item['data'] as Map<String, dynamic>;
    final tanggal = item['tanggal'] as int;
    final tglObj = DateTime(_tahun, _bulan, tanggal);

    const namaHariPanjang = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final labelTanggal = '${namaHariPanjang[tglObj.weekday - 1]}, $tanggal ${namaBulan[_bulan]} $_tahun';

    if (tipe == 'absensi') {
      final isDinasLuar = data['status'] == 'dinas_luar';
      final jamMasuk = data['jam_masuk'] != null ? DateTime.parse(data['jam_masuk'].toString()).toLocal() : null;
      bool terlambat = false;
      int menitTerlambat = 0;
      if (jamMasuk != null && !isDinasLuar) {
        final cutoff = DateTime(jamMasuk.year, jamMasuk.month, jamMasuk.day, 7, 30);
        if (jamMasuk.isAfter(cutoff)) {
          terlambat = true;
          menitTerlambat = jamMasuk.difference(cutoff).inMinutes;
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                  child: Icon(Icons.badge, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(labelTanggal, style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDinasLuar
                        ? const Color(0xFFCFFAFE)
                        : terlambat
                            ? const Color(0xFFFCEFD8)
                            : AppColors.hadirBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isDinasLuar
                        ? 'Dinas Luar'
                        : terlambat
                            ? 'Terlambat $menitTerlambat Mnt'
                            : 'Tepat Waktu',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDinasLuar
                          ? const Color(0xFF0891B2)
                          : terlambat
                              ? const Color(0xFFB06000)
                              : AppColors.hadirText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.login, size: 16, color: terlambat ? const Color(0xFFB06000) : AppColors.tertiaryContainer),
                  const SizedBox(width: 6),
                  Text(_formatJam(data['jam_masuk']), style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  const SizedBox(width: 20),
                  Icon(Icons.logout, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(_formatJam(data['jam_pulang']), style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final status = data['status_persetujuan'] as String? ?? 'menunggu';
      Color badgeBg;
      Color badgeText;
      if (status == 'disetujui') {
        badgeBg = AppColors.secondaryContainer;
        badgeText = AppColors.primary;
      } else if (status == 'ditolak') {
        badgeBg = AppColors.errorContainer;
        badgeText = AppColors.onErrorContainer;
      } else {
        badgeBg = const Color(0xFFFCEFD8);
        badgeText = const Color(0xFFB06000);
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                  child: Icon(Icons.event_note, size: 16, color: AppColors.primaryContainer),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelTanggal, style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      Text(
                        data['keterangan'] ?? (data['jenis'] == 'sakit' ? 'Sakit' : 'Izin'),
                        style: AppText.labelMd.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    status == 'disetujui' ? 'Disetujui' : status == 'ditolak' ? 'Ditolak' : 'Menunggu',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeText),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}