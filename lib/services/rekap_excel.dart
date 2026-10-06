import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart' as xls;

import 'rekap_presensi.dart';

const namaBulanRekap = [
  '',
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

Uint8List buatExcelRekap(RekapPresensi rekap) {
  final workbook = xls.Excel.createExcel();
  workbook.rename('Sheet1', 'Ringkasan');
  final header = xls.CellStyle(
    bold: true,
    backgroundColorHex: xls.ExcelColor.fromHexString('#17365D'),
    fontColorHex: xls.ExcelColor.white,
    horizontalAlign: xls.HorizontalAlign.Center,
    verticalAlign: xls.VerticalAlign.Center,
    textWrapping: xls.TextWrapping.WrapText,
  );
  final periode = '${namaBulanRekap[rekap.bulan]} ${rekap.tahun}';

  void tulis(
    xls.Sheet sheet,
    int row,
    int col,
    Object value, {
    bool judul = false,
    String? warna,
  }) {
    final cell = sheet.cell(
      xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value is int
        ? xls.IntCellValue(value)
        : xls.TextCellValue(value.toString());
    cell.cellStyle = judul
        ? header
        : xls.CellStyle(
            fontSize: 11,
            verticalAlign: xls.VerticalAlign.Center,
            horizontalAlign: col == 1
                ? xls.HorizontalAlign.Left
                : xls.HorizontalAlign.Center,
            backgroundColorHex: xls.ExcelColor.fromHexString(
              warna ?? (row.isEven ? '#F0F4F8' : '#FFFFFF'),
            ),
            textWrapping: xls.TextWrapping.WrapText,
          );
  }

  void banner(xls.Sheet sheet, int lastCol, String judul) {
    tulis(sheet, 0, 0, 'BPS KOTA BATU — $judul', judul: true);
    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xls.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    sheet.setRowHeight(0, 30);
    tulis(
      sheet,
      1,
      0,
      'Periode: $periode | Waktu: WIB | Dibuat: ${tanggalRekap(rekap.dibuatPada)}',
    );
    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xls.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 1),
    );
    sheet.setColumnWidth(0, 7);
    sheet.setColumnWidth(1, 30);
  }

  final ringkasan = workbook['Ringkasan'];
  const headers = [
    'No',
    'Nama peserta',
    'NIM',
    'Asal instansi',
    'Hadir (termasuk terlambat)',
    'Terlambat (bagian hadir)',
    'Izin',
    'Sakit',
    'Dispensasi',
    'Alpha tercatat',
    'Tidak lengkap',
    'Tanpa catatan',
    'Total hari tercatat*',
  ];
  banner(ringkasan, headers.length - 1, 'REKAP PRESENSI');
  for (var c = 0; c < headers.length; c++) {
    tulis(ringkasan, 3, c, headers[c], judul: true);
    if (c > 1) ringkasan.setColumnWidth(c, c == 3 ? 28 : 17);
  }
  ringkasan.setRowHeight(3, 44);
  ringkasan.freezePanes(rows: 4, columns: 2);
  for (var i = 0; i < rekap.peserta.length; i++) {
    final p = rekap.peserta[i];
    final values = <Object>[
      i + 1,
      p.profil['nama_lengkap'] ?? '-',
      p.profil['nim'] ?? '-',
      p.profil['asal_instansi'] ?? '-',
      p.hadir,
      p.jumlah('Terlambat'),
      p.jumlah('Izin'),
      p.jumlah('Sakit'),
      p.jumlah('Dispensasi'),
      p.jumlah('Alpha'),
      p.jumlah('Tidak lengkap'),
      p.jumlah('Tanpa catatan'),
      p.total,
    ];
    for (var c = 0; c < values.length; c++) {
      tulis(ringkasan, i + 4, c, values[c]);
    }
    ringkasan.setRowHeight(i + 4, 30);
  }
  ringkasan.setAutoFilter(
    xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
    xls.CellIndex.indexByColumnRow(
      columnIndex: headers.length - 1,
      rowIndex: rekap.peserta.length + 3,
    ),
  );

  final detail = workbook['Detail'];
  final jumlahHari = DateTime.utc(rekap.tahun, rekap.bulan + 1, 0).day;
  banner(detail, 1 + jumlahHari * 3, 'DETAIL PRESENSI');
  tulis(detail, 4, 0, 'No', judul: true);
  tulis(detail, 4, 1, 'Nama peserta', judul: true);
  const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  for (var d = 0; d < jumlahHari; d++) {
    final t = DateTime.utc(rekap.tahun, rekap.bulan, d + 1);
    final col = 2 + d * 3;
    tulis(
      detail,
      3,
      col,
      '${hari[t.weekday - 1]}, ${d + 1}/${rekap.bulan}',
      judul: true,
    );
    detail.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3),
      xls.CellIndex.indexByColumnRow(columnIndex: col + 2, rowIndex: 3),
    );
    for (var c = 0; c < 3; c++) {
      tulis(
        detail,
        4,
        col + c,
        ['Masuk (WIB)', 'Pulang (WIB)', 'Status / catatan'][c],
        judul: true,
      );
      detail.setColumnWidth(col + c, c == 2 ? 30 : 14);
    }
  }
  detail.setRowHeight(4, 28);
  detail.freezePanes(rows: 5, columns: 2);
  for (var i = 0; i < rekap.peserta.length; i++) {
    final p = rekap.peserta[i];
    tulis(detail, i + 5, 0, i + 1);
    tulis(detail, i + 5, 1, p.profil['nama_lengkap'] ?? '-');
    detail.setRowHeight(i + 5, 60);
    for (var d = 0; d < p.hari.length; d++) {
      final h = p.hari[d];
      final warna = !h.dihitung
          ? '#E7E6E6'
          : switch (h.status) {
              'Hadir' => '#E2F0D9',
              'Terlambat' => '#FFF2CC',
              'Izin' || 'Sakit' => '#E4DFEC',
              'Dispensasi' => '#DDEBF7',
              'Alpha' || 'Tidak lengkap' => '#FCE4D6',
              _ => '#FFFFFF',
            };
      final values = [
        h.jamMasuk,
        h.jamPulang,
        [h.status, if (h.catatan.isNotEmpty) h.catatan].join('\n'),
      ];
      for (var c = 0; c < 3; c++) {
        tulis(detail, i + 5, 2 + d * 3 + c, values[c], warna: warna);
      }
    }
  }
  final aturan = workbook['Panduan'];
  aturan.setColumnWidth(0, 115);
  final catatan = [
    'PANDUAN REKAP PRESENSI — $periode',
    'Ringkasan dan Detail menggunakan status harian yang sama. Satu peserta dihitung maksimal satu kali per tanggal.',
    'Hadir mencakup peserta terlambat. Kolom Terlambat adalah bagian dari Hadir; jangan dijumlahkan lagi.',
    '* Total hari tercatat = Hadir + Izin + Sakit + Dispensasi. Alpha, data tidak lengkap, dan hari tanpa catatan tidak termasuk.',
    'Ringkasan hanya menghitung Senin–Jumat selain hari libur yang dicatat admin, sampai tanggal laporan dibuat (WIB).',
    'Detail mencakup seluruh tanggal bulan terpilih. Catatan akhir pekan, hari libur, dan tanggal mendatang tetap ditampilkan, tetapi tidak dihitung.',
    'Izin/sakit hanya dihitung jika disetujui, untuk setiap hari dalam rentang mulai–selesai, termasuk rentang lintas bulan.',
    'Presensi nyata atau status eksplisit mengungguli izin. Izin tumpang tindih dihitung sekali; sakit diprioritaskan.',
    'Waktu ditampilkan dalam WIB. Masuk setelah 07:30:00 WIB dianggap terlambat; dispensasi tidak dianggap terlambat.',
    'Baris tanpa jam masuk dan tanpa status eksplisit ditandai Tidak lengkap. Jam pulang kosong diberi catatan.',
    'Tanpa catatan bukan otomatis alpha: database belum memiliki periode mulai/selesai magang. Alpha hanya berasal dari status alpha tercatat.',
    'Tanggal hari ini tanpa data ditandai Belum tercatat. Tanggal mendatang tanpa data ditandai Belum berlangsung.',
    if (rekap.peserta.isEmpty) 'Tidak ada profil peserta untuk diekspor.',
  ];
  for (var i = 0; i < catatan.length; i++) {
    tulis(aturan, i, 0, catatan[i], judul: i == 0);
    aturan.setRowHeight(i, i == 0 ? 30 : 45);
  }
  final bytes = workbook.save();
  if (bytes == null) throw StateError('Gagal membuat file Excel');
  return Uint8List.fromList(bytes);
}
