import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:excel_plus/excel_plus.dart' as xls;
import '../main.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loadingHariIni = true;
  bool _loadingRekap = true;
  bool _loadingIzin = true;
  bool _loadingLibur = true;
  List<Map<String, dynamic>> _semuaPeserta = [];
  Map<String, Map<String, dynamic>> _absensiHariIniMap = {};
  List<Map<String, dynamic>> _rekapSemua = [];
  int _bulanRekap = DateTime.now().month;
  int _tahunRekap = DateTime.now().year;
  bool _sedangExport = false;
  List<Map<String, dynamic>> _izinMenunggu = [];
  List<Map<String, dynamic>> _daftarHariLibur = [];
  int _tabIndexTerakhir = 0;

  bool _loadingSusulan = true;
  List<Map<String, dynamic>> _susulanMenunggu = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_saatTabBerubah);
    _ambilDataHariIni();
    _ambilRekapSemua();
    _ambilIzinMenunggu();
    _ambilHariLibur();
    _ambilSusulanMenunggu();
  }

  @override
  void dispose() {
    _tabController.removeListener(_saatTabBerubah);
    _tabController.dispose();
    super.dispose();
  }

  void _saatTabBerubah() {
    final index = _tabController.index;
    if (index == _tabIndexTerakhir) return;
    _tabIndexTerakhir = index;
    if (index == 4) _ambilHariLibur();
  }

  Future<void> _ambilDataHariIni() async {
    setState(() => _loadingHariIni = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final peserta = await supabase
          .from('profiles')
          .select()
          .eq('role', 'peserta')
          .order('nama_lengkap');

      final absensiHariIni = await supabase
          .from('absensi')
          .select()
          .eq('tanggal', today);

      final map = <String, Map<String, dynamic>>{};
      for (final a in absensiHariIni) {
        map[a['user_id'] as String] = a;
      }

      setState(() {
        _semuaPeserta = List<Map<String, dynamic>>.from(peserta);
        _absensiHariIniMap = map;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data hari ini: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHariIni = false);
    }
  }

  Future<void> _ambilRekapSemua() async {
    setState(() => _loadingRekap = true);
    try {
      final awal = DateTime(_tahunRekap, _bulanRekap, 1).toIso8601String().substring(0, 10);
      final akhir = DateTime(_tahunRekap, _bulanRekap + 1, 0).toIso8601String().substring(0, 10);

      // Join absensi dengan profiles untuk ambil nama peserta
      final response = await supabase
          .from('absensi')
          .select('*, profiles(nama_lengkap)')
          .gte('tanggal', awal)
          .lte('tanggal', akhir)
          .order('tanggal', ascending: false);

      setState(() => _rekapSemua = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat rekap: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingRekap = false);
    }
  }

  Future<void> _ambilIzinMenunggu() async {
    setState(() => _loadingIzin = true);
    try {
      final response = await supabase
          .from('izin')
          .select('*, profiles!izin_user_id_fkey(nama_lengkap)')
          .eq('status_persetujuan', 'menunggu')
          .order('created_at', ascending: false);

      setState(() => _izinMenunggu = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat pengajuan izin: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIzin = false);
    }
  }

  Future<void> _prosesIzin(String izinId, bool disetujui) async {
    try {
      await supabase.from('izin').update({
        'status_persetujuan': disetujui ? 'disetujui' : 'ditolak',
        'disetujui_oleh': supabase.auth.currentUser!.id,
      }).eq('id', izinId);

      await _ambilIzinMenunggu();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disetujui ? 'Izin disetujui' : 'Izin ditolak'),
          backgroundColor: disetujui ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses izin: $e')),
      );
    }
  }

  Future<void> _ambilHariLibur() async {
    setState(() => _loadingLibur = true);
    try {
      final response = await supabase
          .from('hari_libur')
          .select()
          .order('tanggal');

      setState(() => _daftarHariLibur = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat hari libur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLibur = false);
    }
  }

  Future<void> _tambahHariLibur(DateTime tanggal, String keterangan) async {
    try {
      await supabase.from('hari_libur').insert({
        'tanggal': tanggal.toIso8601String().substring(0, 10),
        'keterangan': keterangan,
        'dibuat_oleh': supabase.auth.currentUser!.id,
      });
      await _ambilHariLibur();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hari libur ditambahkan'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambah: $e')),
      );
    }
  }

  Future<void> _hapusHariLibur(String id) async {
    try {
      await supabase.from('hari_libur').delete().eq('id', id);
      await _ambilHariLibur();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  Future<void> _dialogTambahLibur() async {
    DateTime? tanggalDipilih;
    final keteranganController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Hari Libur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  tanggalDipilih == null
                      ? 'Pilih Tanggal'
                      : '${tanggalDipilih!.day}/${tanggalDipilih!.month}/${tanggalDipilih!.year}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => tanggalDipilih = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keteranganController,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'misal: Hari Kemerdekaan RI',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (tanggalDipilih != null && keteranganController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _tambahHariLibur(tanggalDipilih!, keteranganController.text.trim());
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ambilSusulanMenunggu() async {
    setState(() => _loadingSusulan = true);
    try {
      final response = await supabase
          .from('absen_susulan')
          .select('*, profiles!absen_susulan_user_id_fkey(nama_lengkap)')
          .eq('status_persetujuan', 'menunggu')
          .order('created_at', ascending: false);
      setState(() => _susulanMenunggu = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat absen susulan: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingSusulan = false);
    }
  }

  // Konversi tanggal + jam (string "HH:mm:ss") jadi DateTime UTC, mengikuti
  // konvensi aplikasi: waktu presensi selalu disimpan dalam UTC.
  DateTime _gabungTanggalJam(String tanggal, String jam) {
    final t = DateTime.parse(tanggal);
    final parts = jam.split(':');
    final local = DateTime(t.year, t.month, t.day, int.parse(parts[0]), int.parse(parts[1]));
    return local.toUtc();
  }

  Future<void> _prosesSusulan(Map<String, dynamic> item, bool disetujui) async {
    try {
      if (disetujui) {
        final userId = item['user_id'] as String;
        final tanggal = item['tanggal'].toString();
        final jamMasukStr = item['jam_masuk_diajukan'] as String?;
        final jamPulangStr = item['jam_pulang_diajukan'] as String?;
        final jenisAlasan = item['jenis_alasan'] as String;

        DateTime? jamMasukUtc = jamMasukStr != null ? _gabungTanggalJam(tanggal, jamMasukStr) : null;
        DateTime? jamPulangUtc = jamPulangStr != null ? _gabungTanggalJam(tanggal, jamPulangStr) : null;

        // Tentukan status: dinas luar override status apapun, selain itu
        // hitung terlambat/hadir dari jam masuk yang diajukan (cutoff 07:30 lokal)
        String? statusBaru;
        if (jamMasukUtc != null) {
          if (jenisAlasan == 'dispensasi') {
            statusBaru = 'dispensasi';
          } else {
            final localMasuk = jamMasukUtc.toLocal();
            final cutoff = DateTime(localMasuk.year, localMasuk.month, localMasuk.day, 7, 30);
            statusBaru = localMasuk.isAfter(cutoff) ? 'terlambat' : 'hadir';
          }
        }

        // Cek apakah sudah ada baris absensi hari itu (misal presensi GPS normal sudah tercatat)
        final existing = await supabase
            .from('absensi')
            .select()
            .eq('user_id', userId)
            .eq('tanggal', tanggal)
            .maybeSingle();

        if (existing == null) {
          await supabase.from('absensi').insert({
            'user_id': userId,
            'tanggal': tanggal,
            if (jamMasukUtc != null) 'jam_masuk': jamMasukUtc.toIso8601String(),
            if (jamPulangUtc != null) 'jam_pulang': jamPulangUtc.toIso8601String(),
            'status': statusBaru ?? 'hadir',
          });
        } else {
          await supabase.from('absensi').update({
            if (jamMasukUtc != null) 'jam_masuk': jamMasukUtc.toIso8601String(),
            if (jamPulangUtc != null) 'jam_pulang': jamPulangUtc.toIso8601String(),
            if (statusBaru != null) 'status': statusBaru,
          }).eq('id', existing['id']);
        }
      }

      await supabase.from('absen_susulan').update({
        'status_persetujuan': disetujui ? 'disetujui' : 'ditolak',
        'disetujui_oleh': supabase.auth.currentUser!.id,
      }).eq('id', item['id']);

      await _ambilSusulanMenunggu();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(disetujui ? 'Absen susulan disetujui & data presensi diperbarui' : 'Absen susulan ditolak'),
          backgroundColor: disetujui ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memproses: $e')));
    }
  }

  void _lihatGambarPenuh(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJam(dynamic value) {
    if (value == null) return '-';
    final dt = DateTime.parse(value.toString()).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Hari Ini'),
            Tab(text: 'Rekap'),
            Tab(text: 'Approval Izin'),
            Tab(text: 'Approval Susulan'),
            Tab(text: 'Hari Libur'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabHariIni(),
          _buildTabRekap(),
          _buildTabIzin(),
          _buildTabSusulan(),
          _buildTabHariLibur(),
        ],
      ),
    );
  }

  Widget _buildTabHariIni() {
    if (_loadingHariIni) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _ambilDataHariIni,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _semuaPeserta.length,
        itemBuilder: (context, index) {
          final peserta = _semuaPeserta[index];
          final absensi = _absensiHariIniMap[peserta['id']];
          final sudahAbsen = absensi != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: sudahAbsen ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(
                  sudahAbsen ? Icons.check : Icons.close,
                  color: sudahAbsen ? Colors.green : Colors.red,
                ),
              ),
              title: Text(peserta['nama_lengkap'] ?? '-'),
              subtitle: Text(
                sudahAbsen
                    ? 'Masuk: ${_formatJam(absensi['jam_masuk'])}  |  Pulang: ${_formatJam(absensi['jam_pulang'])}'
                    : 'Belum absen hari ini',
              ),
            ),
          );
        },
      ),
    );
  }

  String _namaBulan(int b) => const [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
      ][b];

  // Helper pencarian manual - menghindari masalah tipe data null pada firstWhere()
  Map<String, dynamic>? _cariBaris(List list, bool Function(Map<String, dynamic>) test) {
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      if (test(map)) return map;
    }
    return null;
  }

  // Export rekap sebagai 1 file Excel (XLSX) dengan 2 sheet:
  // Sheet "Ringkasan" = jumlah hadir/terlambat/izin per peserta
  // Sheet "Detail"    = rincian harian per peserta, header tanggal di-merge asli (bukan CSV)
  Future<void> _unduhRekapXlsx() async {
    setState(() => _sedangExport = true);
    try {
      final semuaPeserta = await supabase.from('profiles').select().eq('role', 'peserta').order('nama_lengkap');

      final awal = DateTime(_tahunRekap, _bulanRekap, 1).toIso8601String().substring(0, 10);
      final akhir = DateTime(_tahunRekap, _bulanRekap + 1, 0).toIso8601String().substring(0, 10);

      final absensiBulan = await supabase.from('absensi').select().gte('tanggal', awal).lte('tanggal', akhir);
      final izinBulan = await supabase
          .from('izin')
          .select()
          .eq('status_persetujuan', 'disetujui')
          .gte('tanggal_mulai', awal)
          .lte('tanggal_mulai', akhir);

      final workbook = xls.Excel.createExcel();
      workbook.rename('Sheet1', 'Ringkasan');

      // ===== SHEET 1: RINGKASAN =====
      final ringkasan = workbook['Ringkasan'];
      const headerRingkasan = ['nama', 'hadir', 'terlambat', 'izin', 'dispensasi', 'total'];
      for (int c = 0; c < headerRingkasan.length; c++) {
        final cell = ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = xls.TextCellValue(headerRingkasan[c]);
        cell.cellStyle = xls.CellStyle(bold: true);
      }

      int rowIdx = 1;
      for (final peserta in semuaPeserta) {
        final userId = peserta['id'];
        final absensiUser = (absensiBulan as List).where((a) => a['user_id'] == userId);
        final izinUser = (izinBulan as List).where((i) => i['user_id'] == userId).length;

        int hadir = 0, terlambat = 0, dispensasi = 0;
        for (final a in absensiUser) {
          if (a['status'] == 'dispensasi') {
            dispensasi++;
          } else if (a['jam_masuk'] != null) {
            hadir++;
            final jm = DateTime.parse(a['jam_masuk'].toString()).toLocal();
            if (jm.hour > 7 || (jm.hour == 7 && jm.minute > 30)) terlambat++;
          }
        }
        final total = hadir + izinUser + dispensasi;

        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value =
            xls.TextCellValue(peserta['nama_lengkap'] ?? '-');
        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value = xls.IntCellValue(hadir);
        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value = xls.IntCellValue(terlambat);
        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value = xls.IntCellValue(izinUser);
        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value = xls.IntCellValue(dispensasi);
        ringkasan.cell(xls.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value = xls.IntCellValue(total);
        rowIdx++;
      }

      // ===== SHEET 2: DETAIL (header tanggal di-merge beneran, bukan diulang seperti CSV) =====
      final detail = workbook['Detail'];

      final Set<String> tanggalSet = {};
      for (final a in (absensiBulan)) {
        tanggalSet.add(a['tanggal'].toString());
      }
      for (final i in (izinBulan)) {
        tanggalSet.add(i['tanggal_mulai'].toString());
      }
      final daftarTanggal = tanggalSet.toList()..sort();

      if (daftarTanggal.isNotEmpty) {
        for (int i = 0; i < daftarTanggal.length; i++) {
          final startCol = 2 + (i * 3);
          final cell = detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 0));
          cell.value = xls.TextCellValue(daftarTanggal[i]);
          cell.cellStyle = xls.CellStyle(bold: true, horizontalAlign: xls.HorizontalAlign.Center);
          detail.merge(
            xls.CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 0),
            xls.CellIndex.indexByColumnRow(columnIndex: startCol + 2, rowIndex: 0),
          );
        }

        final headerBaris2 = <String>['no', 'nama'];
        for (int i = 0; i < daftarTanggal.length; i++) {
          headerBaris2.addAll(['jam masuk', 'jam pulang', 'keterangan']);
        }
        for (int c = 0; c < headerBaris2.length; c++) {
          final cell = detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1));
          cell.value = xls.TextCellValue(headerBaris2[c]);
          cell.cellStyle = xls.CellStyle(bold: true);
        }

        int no = 1;
        int baris = 2;
        for (final peserta in semuaPeserta) {
          final userId = peserta['id'];
          detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: baris)).value = xls.IntCellValue(no);
          detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: baris)).value =
              xls.TextCellValue(peserta['nama_lengkap'] ?? '-');

          for (int i = 0; i < daftarTanggal.length; i++) {
            final tgl = daftarTanggal[i];
            final col = 2 + (i * 3);

            final absensiHari = _cariBaris(absensiBulan, (a) => a['user_id'] == userId && a['tanggal'].toString() == tgl);
            final izinHari = _cariBaris(izinBulan, (i2) => i2['user_id'] == userId && i2['tanggal_mulai'].toString() == tgl);

            String jm = '-', jp = '-', ket = '-';
            if (absensiHari != null) {
              jm = _formatJam(absensiHari['jam_masuk']);
              jp = _formatJam(absensiHari['jam_pulang']);
              ket = 'Hadir';
              if (absensiHari['status'] == 'dispensasi') {
                ket = 'Dispensasi';
              } else if (absensiHari['jam_masuk'] != null) {
                final jamMasukDt = DateTime.parse(absensiHari['jam_masuk'].toString()).toLocal();
                if (jamMasukDt.hour > 7 || (jamMasukDt.hour == 7 && jamMasukDt.minute > 30)) ket = 'Terlambat';
              }
            } else if (izinHari != null) {
              ket = izinHari['jenis'] == 'sakit' ? 'Sakit' : 'Izin';
            }

            detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: baris)).value = xls.TextCellValue(jm);
            detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: col + 1, rowIndex: baris)).value = xls.TextCellValue(jp);
            detail.cell(xls.CellIndex.indexByColumnRow(columnIndex: col + 2, rowIndex: baris)).value = xls.TextCellValue(ket);
          }

          no++;
          baris++;
        }
      }

      final fileBytes = workbook.save();
      if (fileBytes == null) throw Exception('Gagal membuat file Excel');

      final namaFile = 'rekap_presensi_${_namaBulan(_bulanRekap)}_$_tahunRekap';
      final bytes = Uint8List.fromList(fileBytes);

      try {
        await FileSaver.instance.saveAs(
          name: namaFile,
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File Excel berhasil disimpan'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        debugPrint('saveAs gagal, fallback ke share: $e');
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$namaFile.xlsx');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: namaFile));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    } finally {
      if (mounted) setState(() => _sedangExport = false);
    }
  }

  Widget _buildTabRekap() {
    return Column(
      children: [
        // Filter bulan + tombol export
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _bulanRekap,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, labelText: 'Bulan'),
                      items: List.generate(12, (i) => i + 1)
                          .map((b) => DropdownMenuItem(value: b, child: Text(_namaBulan(b))))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _bulanRekap = v!);
                        _ambilRekapSemua();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _tahunRekap,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none, labelText: 'Tahun'),
                      items: List.generate(
                        DateTime.now().year - 2024 + 2, // 2024 s/d (tahun sekarang + 1), otomatis nambah tiap tahun
                        (i) => 2024 + i,
                      )
                          .map((t) => DropdownMenuItem(value: t, child: Text('$t')))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _tahunRekap = v!);
                        _ambilRekapSemua();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sedangExport ? null : _unduhRekapXlsx,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Unduh Ringkasan & Detail'),
                ),
              ),
              if (_sedangExport) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        Expanded(child: _buildRekapList()),
      ],
    );
  }

  // Skema warna sama dengan kalender di tab Riwayat peserta
  Widget _badgeStatusRekap(Map<String, dynamic> item) {
    String label;
    Color bg, text;

    if (item['status'] == 'dispensasi') {
      label = 'DISPENSASI';
      bg = const Color(0xFFCFFAFE);
      text = const Color(0xFF0891B2);
    } else if (item['jam_masuk'] != null) {
      final jm = DateTime.parse(item['jam_masuk'].toString()).toLocal();
      final terlambat = jm.hour > 7 || (jm.hour == 7 && jm.minute > 30);
      if (terlambat) {
        label = 'TERLAMBAT';
        bg = const Color(0xFFFCEFD8);
        text = const Color(0xFFB06000);
      } else {
        label = 'HADIR';
        bg = const Color(0xFFE6F4EA);
        text = const Color(0xFF137333);
      }
    } else {
      label = '-';
      bg = Colors.grey.shade200;
      text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }

  Widget _buildRekapList() {
    if (_loadingRekap) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rekapSemua.isEmpty) {
      return const Center(child: Text('Belum ada data presensi'));
    }

    return RefreshIndicator(
      onRefresh: _ambilRekapSemua,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rekapSemua.length,
        itemBuilder: (context, index) {
          final item = _rekapSemua[index];
          final namaPeserta = item['profiles']?['nama_lengkap'] ?? 'Tidak diketahui';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(namaPeserta),
              subtitle: Text(
                '${item['tanggal']}  |  Masuk: ${_formatJam(item['jam_masuk'])}  |  Pulang: ${_formatJam(item['jam_pulang'])}',
              ),
              trailing: _badgeStatusRekap(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabIzin() {
    if (_loadingIzin) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_izinMenunggu.isEmpty) {
      return const Center(child: Text('Tidak ada pengajuan izin yang menunggu'));
    }

    return RefreshIndicator(
      onRefresh: _ambilIzinMenunggu,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _izinMenunggu.length,
        itemBuilder: (context, index) {
          final item = _izinMenunggu[index];
          final namaPeserta = item['profiles']?['nama_lengkap'] ?? 'Tidak diketahui';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(namaPeserta, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${(item['jenis'] as String).toUpperCase()} — ${item['tanggal_mulai']} s/d ${item['tanggal_selesai']}'),
                  const SizedBox(height: 4),
                  Text(item['keterangan'] ?? '-', style: const TextStyle(color: Colors.grey)),
                  if (item['bukti_url'] != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _lihatGambarPenuh(context, item['bukti_url']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item['bukti_url'],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 140,
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _prosesIzin(item['id'], false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _prosesIzin(item['id'], true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabHariLibur() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _dialogTambahLibur,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: _loadingLibur
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _ambilHariLibur,
              child: _daftarHariLibur.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 48),
                        Center(child: Text('Belum ada hari libur terjadwal')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _daftarHariLibur.length,
                      itemBuilder: (context, index) {
                        final item = _daftarHariLibur[index];
                        final tanggal = DateTime.parse(item['tanggal'].toString());
                        const namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                        const namaBulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.event_busy)),
                            title: Text(item['keterangan'] ?? '-'),
                            subtitle: Text(
                              '${namaHari[tanggal.weekday - 1]}, ${tanggal.day} ${namaBulan[tanggal.month]} ${tanggal.year}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _hapusHariLibur(item['id']),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildTabSusulan() {
    if (_loadingSusulan) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_susulanMenunggu.isEmpty) {
      return const Center(child: Text('Tidak ada pengajuan absen susulan yang menunggu'));
    }

    return RefreshIndicator(
      onRefresh: _ambilSusulanMenunggu,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _susulanMenunggu.length,
        itemBuilder: (context, index) {
          final item = _susulanMenunggu[index];
          final namaPeserta = item['profiles']?['nama_lengkap'] ?? 'Tidak diketahui';
          const labelAlasan = {
            'dispensasi': 'Dispensasi',
            'lupa_absen': 'Lupa Absen',
            'gps_error': 'GPS / Lokasi Error',
            'lainnya': 'Lainnya',
          };

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(namaPeserta, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${item['tanggal']} • ${labelAlasan[item['jenis_alasan']] ?? '-'}'),
                  const SizedBox(height: 4),
                  if (item['jam_masuk_diajukan'] != null)
                    Text('Jam masuk diajukan: ${item['jam_masuk_diajukan'].toString().substring(0, 5)}'),
                  if (item['jam_pulang_diajukan'] != null)
                    Text('Jam pulang diajukan: ${item['jam_pulang_diajukan'].toString().substring(0, 5)}'),
                  const SizedBox(height: 4),
                  Text(item['keterangan'] ?? '-', style: const TextStyle(color: Colors.grey)),
                  if (item['bukti_url'] != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _lihatGambarPenuh(context, item['bukti_url']),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item['bukti_url'],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 140,
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _prosesSusulan(item, false),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _prosesSusulan(item, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
