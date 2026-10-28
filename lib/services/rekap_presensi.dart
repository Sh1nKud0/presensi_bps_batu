/// Waktu kantor selalu WIB, terlepas dari zona waktu perangkat admin.
DateTime waktuWib(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));

/// Memformat tanggal kalender sebagai kunci ISO `YYYY-MM-DD`.
String tanggalRekap(DateTime value) => value.toIso8601String().substring(0, 10);

String jamRekap(dynamic value) {
  if (value == null) return '-';
  final jam = waktuWib(DateTime.parse(value.toString()));
  return '${jam.hour.toString().padLeft(2, '0')}:${jam.minute.toString().padLeft(2, '0')}';
}

String statusPresensi(Map<String, dynamic> data) {
  final status = data['status'];
  if (status == 'dispensasi' || status == 'dinas_luar') return 'Dispensasi';
  if (data['jam_masuk'] != null) {
    final jam = waktuWib(DateTime.parse(data['jam_masuk'].toString()));
    final batas = DateTime.utc(jam.year, jam.month, jam.day, 7, 30);
    return jam.isAfter(batas) ? 'Terlambat' : 'Hadir';
  }
  return switch (status) {
    'izin' => 'Izin',
    'sakit' => 'Sakit',
    'alpha' => 'Alpha',
    _ => 'Tidak lengkap',
  };
}

/// Status dan waktu presensi satu peserta pada satu tanggal rekap.
class HariRekap {
  final DateTime tanggal;
  final String status;
  final String jamMasuk;
  final String jamPulang;
  final bool dihitung;
  final String catatan;

  const HariRekap(
    this.tanggal,
    this.status, {
    this.jamMasuk = '-',
    this.jamPulang = '-',
    this.dihitung = false,
    this.catatan = '',
  });
}

/// Data peserta beserta status harian untuk periode rekap terpilih.
class PesertaRekap {
  final Map<String, dynamic> profil;
  final List<HariRekap> hari;

  const PesertaRekap(this.profil, this.hari);

  int jumlah(String status) =>
      hari.where((h) => h.dihitung && h.status == status).length;
  int get hadir => jumlah('Hadir') + jumlah('Terlambat');
  int get total =>
      hadir + jumlah('Izin') + jumlah('Sakit') + jumlah('Dispensasi');
}

/// Hasil rekap presensi lintas peserta yang siap ditampilkan atau diekspor.
class RekapPresensi {
  final int bulan;
  final int tahun;
  final DateTime dibuatPada;
  final List<PesertaRekap> peserta;

  const RekapPresensi(this.bulan, this.tahun, this.dibuatPada, this.peserta);

  factory RekapPresensi.hitung({
    required int bulan,
    required int tahun,
    required List<Map<String, dynamic>> profiles,
    required List<Map<String, dynamic>> absensi,
    required List<Map<String, dynamic>> izin,
    required List<Map<String, dynamic>> libur,
    DateTime? sekarang,
  }) {
    final dibuat = waktuWib(sekarang ?? DateTime.now());
    final hariIni = tanggalRekap(dibuat);
    final awal = DateTime.utc(tahun, bulan, 1);
    final akhir = DateTime.utc(tahun, bulan + 1, 0);
    final absensiMap = <String, Map<String, dynamic>>{
      for (final a in absensi) '${a['user_id']}/${a['tanggal']}': a,
    };
    final liburMap = <String, String>{
      for (final h in libur)
        h['tanggal'].toString(): h['keterangan'].toString(),
    };
    // Expand izin ke setiap hari dalam bulan. Pengajuan tumpang tindih
    // dihitung sekali; sakit diprioritaskan secara deterministik.
    final izinMap = <String, String>{};
    for (final i in izin) {
      if (i['status_persetujuan'] != 'disetujui') continue;
      final mulai = DateTime.parse('${i['tanggal_mulai']}T00:00:00Z');
      final selesai = DateTime.parse('${i['tanggal_selesai']}T00:00:00Z');
      for (
        var t = mulai.isBefore(awal) ? awal : mulai;
        !t.isAfter(selesai) && !t.isAfter(akhir);
        t = t.add(const Duration(days: 1))
      ) {
        final key = '${i['user_id']}/${tanggalRekap(t)}';
        if (izinMap[key] != 'Sakit') {
          izinMap[key] = i['jenis'] == 'sakit' ? 'Sakit' : 'Izin';
        }
      }
    }
    final sorted = List<Map<String, dynamic>>.of(profiles)
      ..sort(
        (a, b) => '${a['nama_lengkap']}'.toLowerCase().compareTo(
          '${b['nama_lengkap']}'.toLowerCase(),
        ),
      );
    final peserta = sorted.map((p) {
      final hari = <HariRekap>[];
      for (
        var t = awal;
        !t.isAfter(akhir);
        t = t.add(const Duration(days: 1))
      ) {
        final tanggal = tanggalRekap(t);
        final key = '${p['id']}/$tanggal';
        final a = absensiMap[key];
        final akhirPekan = t.weekday >= DateTime.saturday;
        final keteranganLibur = liburMap[tanggal];
        final masaDepan = tanggal.compareTo(hariIni) > 0;
        final dihitung = !akhirPekan && keteranganLibur == null && !masaDepan;
        // Presensi nyata mengungguli izin; baris kosong tidak menutupi izin.
        final status =
            a != null &&
                (a['jam_masuk'] != null ||
                    [
                      'dispensasi',
                      'dinas_luar',
                      'izin',
                      'sakit',
                      'alpha',
                    ].contains(a['status']))
            ? statusPresensi(a)
            : izinMap[key] ??
                  (a != null
                      ? 'Tidak lengkap'
                      : keteranganLibur != null || akhirPekan
                      ? 'Libur'
                      : masaDepan
                      ? 'Belum berlangsung'
                      : tanggal == hariIni
                      ? 'Belum tercatat'
                      : 'Tanpa catatan');
        final catatan = <String>[
          ?keteranganLibur,
          if (akhirPekan) 'Akhir pekan',
          if (masaDepan) 'Tanggal mendatang',
          if (!dihitung && status != 'Libur' && status != 'Belum berlangsung')
            'Tidak dihitung',
          if (a?['jam_masuk'] != null && a?['jam_pulang'] == null)
            'Belum ada jam pulang',
        ].join('; ');
        hari.add(
          HariRekap(
            t,
            status,
            jamMasuk: jamRekap(a?['jam_masuk']),
            jamPulang: jamRekap(a?['jam_pulang']),
            dihitung: dihitung,
            catatan: catatan,
          ),
        );
      }
      return PesertaRekap(p, hari);
    }).toList();
    return RekapPresensi(bulan, tahun, dibuat, peserta);
  }
}
