import 'package:flutter_test/flutter_test.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import 'package:presensi_bps_batu/services/rekap_presensi.dart';
import 'package:presensi_bps_batu/services/rekap_excel.dart';

void main() {
  const profil = {'id': 'p1', 'nama_lengkap': 'Peserta A', 'nim': '00123'};
  Map<String, dynamic> izin(
    String mulai,
    String selesai, {
    String jenis = 'izin',
    String status = 'disetujui',
  }) => {
    'user_id': 'p1',
    'tanggal_mulai': mulai,
    'tanggal_selesai': selesai,
    'jenis': jenis,
    'status_persetujuan': status,
  };
  Map<String, dynamic> absen(
    String tanggal,
    String? masuk, {
    String status = 'hadir',
    String? pulang,
  }) => {
    'user_id': 'p1',
    'tanggal': tanggal,
    'jam_masuk': masuk,
    'jam_pulang': pulang,
    'status': status,
  };
  RekapPresensi hitung({
    List<Map<String, dynamic>> absensi = const [],
    List<Map<String, dynamic>> izinData = const [],
    List<Map<String, dynamic>> libur = const [],
    DateTime? sekarang,
    int bulan = 10,
    int tahun = 2026,
  }) => RekapPresensi.hitung(
    bulan: bulan,
    tahun: tahun,
    profiles: [profil],
    absensi: absensi,
    izin: izinData,
    libur: libur,
    sekarang: sekarang ?? DateTime.utc(2026, 11, 1),
  );

  test(
    'Izin lintas bulan dihitung per hari kerja, termasuk tanggal selesai',
    () {
      final p = hitung(izinData: [izin('2026-09-29', '2026-10-05')])
          .peserta
          .single;
      expect(p.jumlah('Izin'), 3); // Kamis, Jumat, Senin.
      expect(p.hari[4].status, 'Izin');
      expect(p.hari[2].dihitung, isFalse); // Sabtu.
      expect(p.total, 3);
    },
  );

  test('Pengajuan bertumpuk, sakit dan presensi tidak dihitung ganda', () {
    final p = hitung(
      izinData: [
        izin('2026-10-01', '2026-10-05'),
        izin('2026-10-01', '2026-10-02', jenis: 'sakit'),
        izin('2026-10-06', '2026-10-06', status: 'menunggu'),
        izin('2026-10-07', '2026-10-07', status: 'ditolak'),
      ],
      absensi: [absen('2026-10-02', '2026-10-02T00:31:00Z')],
    ).peserta.single;
    expect(p.hadir, 1);
    expect(p.jumlah('Terlambat'), 1);
    expect(p.jumlah('Sakit'), 1);
    expect(p.jumlah('Izin'), 1);
    expect(p.total, 3);
    expect(p.hari[5].status, 'Tanpa catatan');
    expect(p.hari[6].status, 'Tanpa catatan');
  });

  test('Batas masuk WIB mempertimbangkan detik dan offset UTC', () {
    expect(
      statusPresensi(absen('2026-10-01', '2026-10-01T00:30:00Z')),
      'Hadir',
    );
    expect(
      statusPresensi(absen('2026-10-01', '2026-10-01T07:30:01+07:00')),
      'Terlambat',
    );
    expect(jamRekap('2026-09-30T23:55:00Z'), '06:55');
    expect(
      statusPresensi(
        absen('2026-10-01', '2026-10-01T01:30:00Z', status: 'dispensasi'),
      ),
      'Dispensasi',
    );
  });

  test('Libur, akhir pekan dan tanggal mendatang tidak menambah total', () {
    final p = hitung(
      sekarang: DateTime.utc(2026, 10, 6, 3),
      libur: [
        {'tanggal': '2026-10-01', 'keterangan': 'Libur kantor'},
      ],
      absensi: [
        absen('2026-10-01', '2026-10-01T00:00:00Z'),
        absen('2026-10-03', '2026-10-03T00:00:00Z'),
        absen('2026-10-07', '2026-10-07T00:00:00Z'),
      ],
    ).peserta.single;
    expect(p.total, 0);
    expect(p.hari.first.status, 'Hadir'); // Tetap dapat diperiksa pada Detail.
    expect(p.hari.first.catatan, contains('Libur kantor'));
    expect(p.hari[5].status, 'Belum tercatat');
    expect(p.hari[7].status, 'Belum berlangsung');
    expect(p.jumlah('Alpha'), 0);
  });

  test('Status eksplisit, data parsial, dan izin pada baris kosong', () {
    final p = hitung(
      absensi: [
        absen('2026-10-01', null, status: 'sakit'),
        absen('2026-10-02', null, status: 'alpha'),
        absen('2026-10-05', null, pulang: '2026-10-05T09:00:00Z'),
        absen('2026-10-06', null),
        absen('2026-10-07', '2026-10-07T00:00:00Z'),
      ],
      izinData: [izin('2026-10-06', '2026-10-06')],
    ).peserta.single;
    expect(p.jumlah('Sakit'), 1);
    expect(p.jumlah('Alpha'), 1);
    expect(p.jumlah('Tidak lengkap'), 1);
    expect(p.jumlah('Izin'), 1);
    expect(p.hari[6].catatan, contains('Belum ada jam pulang'));
    expect(p.total, 3);
  });

  test('Februari tahun kabisat memiliki semua tanggal', () {
    final p = hitung(bulan: 2, tahun: 2024).peserta.single;
    expect(p.hari.length, 29);
    expect(p.hari.last.tanggal.day, 29);
  });

  test('XLSX dapat dibaca kembali, NIM tetap teks dan angka sesuai detail', () {
    final rekap = hitung(izinData: [izin('2026-09-30', '2026-10-02')]);
    final book = xls.Excel.decodeBytes(buatExcelRekap(rekap));
    expect(book.tables.keys, containsAll(['Ringkasan', 'Detail', 'Panduan']));
    expect(
      book['Ringkasan']
          .cell(xls.CellIndex.indexByString('C5'))
          .value
          .toString(),
      '00123',
    );
    expect(
      book['Ringkasan']
          .cell(xls.CellIndex.indexByString('G5'))
          .value
          .toString(),
      '2',
    );
    expect(
      book['Ringkasan']
          .cell(xls.CellIndex.indexByString('M5'))
          .value
          .toString(),
      '2',
    );
    expect(book['Detail'].maxColumns, 95); // 2 + 31 x 3.
    expect(
      book['Detail'].cell(xls.CellIndex.indexByString('E6')).value.toString(),
      'Izin',
    );
  });

  test('Bulan kosong tetap menghasilkan workbook dengan header', () {
    final rekap = RekapPresensi.hitung(
      bulan: 10,
      tahun: 2026,
      profiles: [],
      absensi: [],
      izin: [],
      libur: [],
      sekarang: DateTime.utc(2026, 11, 1),
    );
    final book = xls.Excel.decodeBytes(buatExcelRekap(rekap));
    expect(book['Ringkasan'].maxRows, 4);
    expect(book['Detail'].maxColumns, 95);
  });
}
