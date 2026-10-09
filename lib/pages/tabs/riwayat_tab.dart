import '../../widgets/adaptive_tiles.dart';
import '../../widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class RiwayatTab extends StatefulWidget {
  final bool isActive;
  const RiwayatTab({super.key, this.isActive = true});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

enum _StatusHari { hadir, terlambat, izin, sakit, dinasLuar, tidakAda }

class _RiwayatTabState extends State<RiwayatTab> {
  bool _loading = true;
  int _bulan = DateTime.now().month;
  int _tahun = DateTime.now().year;
  final ScrollController _aktivitasScrollController = ScrollController();

  @override
  void dispose() {
    _aktivitasScrollController.dispose();
    super.dispose();
  }

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

  @override
  void didUpdateWidget(covariant RiwayatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _muatData();
  }

  Future<void> _muatData() async {
    setState(() => _loading = true);
    try {
      final awal = DateTime(_tahun, _bulan, 1).toIso8601String().substring(0, 10);
      final akhir = DateTime(_tahun, _bulan + 1, 0).toIso8601String().substring(0, 10);

      final absensi = await appData.history(awal, akhir);
      final izin = (await appData.requests('izin')).where((r) =>
        r['status_persetujuan'] == 'disetujui' &&
        (r['tanggal_mulai'] as String).compareTo(akhir) <= 0 &&
        (r['tanggal_selesai'] as String).compareTo(awal) >= 0).toList();
      final hariLibur = await appData.holidays(start: awal, end: akhir);

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
        var day = DateTime.parse(i['tanggal_mulai'] as String);
        final last = DateTime.parse(i['tanggal_selesai'] as String);
        while (!day.isAfter(last)) {
          if (day.year == _tahun && day.month == _bulan) mapIzin[day.day] = i;
          day = day.add(const Duration(days: 1));
        }
      }

      // Gabungkan untuk daftar aktivitas terbaru, urutkan tanggal desc
      final gabungan = <Map<String, dynamic>>[];
      mapAbsensi.forEach((tgl, data) => gabungan.add({'tipe': 'absensi', 'tanggal': tgl, 'data': data}));
      mapIzin.forEach((tgl, data) => gabungan.add({'tipe': 'izin', 'tanggal': tgl, 'data': data}));
      gabungan.sort((a, b) => (b['tanggal'] as int).compareTo(a['tanggal'] as int));

      if (!mounted) return;
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
      if (a['status'] == 'dispensasi') return _StatusHari.dinasLuar;
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
        return context.appColors.tertiaryContainer;
      case _StatusHari.terlambat:
        return context.appColors.izinText;
      case _StatusHari.izin:
      case _StatusHari.sakit:
        return context.appColors.pengajuanText;
      case _StatusHari.dinasLuar:
        return context.appColors.dispensasiText;
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
          GlassSurface(
            padding: const EdgeInsets.all(12),
            radius: 24,
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
            GlassSurface(
              padding: const EdgeInsets.all(12),
              radius: 24,
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
                              color: isWeekend ? context.appColors.error : context.appColors.onSurfaceVariant,
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 2,
                      mainAxisExtent: 38 + MediaQuery.textScalerOf(context).scale(16),
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
                            color: context.appColors.errorContainer.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                            '$tanggal',
                            style: TextStyle(color: context.appColors.error, fontWeight: FontWeight.w700, fontSize: 13),
                          )),
                        );
                      }

                      if (keteranganLibur != null) {
                        return Tooltip(
                          message: keteranganLibur,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appColors.liburBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                              '$tanggal',
                              style: TextStyle(color: context.appColors.liburText, fontWeight: FontWeight.w700, fontSize: 13),
                            )),
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: isHariIni ? context.appColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(fit: BoxFit.scaleDown, child: Text(
                              '$tanggal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHariIni ? FontWeight.w700 : FontWeight.w500,
                                color: isHariIni ? context.appColors.onPrimary : context.appColors.onSurface,
                              ),
                            )),
                            const SizedBox(height: 2),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isHariIni ? context.appColors.onPrimary.withValues(alpha: 0.7) : _warnaDot(status),
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
                      color: context.appColors.surfaceContainerLow.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        _legendaItem(context.appColors.tertiaryContainer, 'Hadir'),
                        _legendaItem(context.appColors.izinText, 'Terlambat'),
                        _legendaItem(context.appColors.pengajuanText, 'Izin/Sakit'),
                        _legendaItem(context.appColors.dispensasiText, 'Dispensasi'),
                        _legendaItem(context.appColors.liburText, 'Libur Nasional'),
                        Text('Sab/Min Libur', style: AppText.labelMd.copyWith(color: context.appColors.error, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Statistik 2x2
          AdaptiveTiles(
            minTileWidth: 152,
            children: [
              _kartuStat(Icons.check_circle, context.appColors.tertiaryContainer, 'Total Hadir', '$totalHadir', 'Hari'),
              _kartuStat(Icons.timer, context.appColors.izinText, 'Terlambat', '$totalTerlambat', 'Kali'),
              _kartuStat(Icons.assignment, context.appColors.primary, 'Izin/Sakit', '$totalIzin', 'Hari'),
              _kartuStat(Icons.weekend, context.appColors.error, 'Hari Libur', '$totalLibur', 'Hari'),
            ],
          ),
          const SizedBox(height: 24),

          // Aktivitas terbaru
          Row(
            children: [
              Expanded(child: Text('Aktivitas Presensi Terakhir', style: AppText.headlineSm.copyWith(fontSize: 16))),
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
                color: context.appColors.surfaceContainerLow.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(8),
              child: _aktivitasTerbaru.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Belum ada aktivitas di bulan ini', style: AppText.bodyMd, textAlign: TextAlign.center),
                    )
                  : Scrollbar(
                      controller: _aktivitasScrollController,
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      child: ListView.builder(
                        controller: _aktivitasScrollController,
                        shrinkWrap: true,
                        itemCount: _aktivitasTerbaru.length,
                        itemBuilder: (context, index) => _kartuAktivitas(_aktivitasTerbaru[index]),
                      ),
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
          color: context.appColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: context.appColors.onSurface),
      ),
    );
  }

  Widget _legendaItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: AppText.labelMd.copyWith(fontSize: 11))),
      ],
    );
  }

  Widget _kartuStat(IconData icon, Color color, String label, String value, String satuan) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 14,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.labelMd.copyWith(fontSize: 10)),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.appColors.onSurface)),
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
      final isDinasLuar = data['status'] == 'dispensasi';
      final belumAbsen = data['jam_pulang'] == null;
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

      return GlassSurface(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveTiles(minTileWidth: 120, children: [Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: context.appColors.surfaceContainerHigh, shape: BoxShape.circle),
                  child: Icon(Icons.badge, size: 16, color: context.appColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(namaHariPanjang[tglObj.weekday - 1], style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: context.appColors.onSurface)),
                      Text('$tanggal ${namaBulan[_bulan]} $_tahun', style: AppText.labelMd.copyWith(fontSize: 11, color: context.appColors.onSurfaceVariant)),
                    ],
                  ),
                )]), Align(alignment: Alignment.centerLeft, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: belumAbsen
                        ? context.appColors.errorContainer
                        : isDinasLuar
                            ? context.appColors.dispensasiBg
                            : terlambat
                                ? context.appColors.izinBg
                                : context.appColors.hadirBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    belumAbsen
                        ? 'Belum Absen'
                        : isDinasLuar
                            ? 'Dispensasi'
                            : terlambat
                                ? 'Terlambat'
                                : 'Tepat Waktu',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: belumAbsen
                          ? context.appColors.error
                          : isDinasLuar
                              ? context.appColors.dispensasiText
                              : terlambat
                                  ? context.appColors.izinText
                                  : context.appColors.hadirText,
                    ),
                  ),
                ))]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.appColors.surfaceContainerLow.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8,
                children: [
                  Icon(Icons.login, size: 16, color: terlambat ? context.appColors.izinText : context.appColors.tertiaryContainer),
                  const SizedBox(width: 6),
                  Text(_formatJam(data['jam_masuk']), style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: context.appColors.onSurface)),
                  const SizedBox(width: 20),
                  Icon(Icons.logout, size: 16, color: context.appColors.secondary),
                  const SizedBox(width: 6),
                  Text(_formatJam(data['jam_pulang']), style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: context.appColors.onSurface)),
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
        badgeBg = context.appColors.secondaryContainer;
        badgeText = context.appColors.primary;
      } else if (status == 'ditolak') {
        badgeBg = context.appColors.errorContainer;
        badgeText = context.appColors.onErrorContainer;
      } else {
        badgeBg = context.appColors.izinBg;
        badgeText = context.appColors.izinText;
      }

      return GlassSurface(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveTiles(minTileWidth: 120, children: [Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: context.appColors.surfaceContainerHigh, shape: BoxShape.circle),
                  child: Icon(Icons.event_note, size: 16, color: context.appColors.pengajuanText),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(labelTanggal, style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: context.appColors.onSurface)),
                      Text(
                        data['keterangan'] ?? (data['jenis'] == 'sakit' ? 'Sakit' : 'Izin'),
                        style: AppText.labelMd.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                )]), Align(alignment: Alignment.centerLeft, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    status == 'disetujui' ? 'Disetujui' : status == 'ditolak' ? 'Ditolak' : 'Menunggu',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeText),
                  ),
                ))]),
          ],
        ),
      );
    }
  }
}
