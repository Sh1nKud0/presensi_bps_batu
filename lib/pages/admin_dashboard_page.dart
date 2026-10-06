import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import '../services/rekap_presensi.dart';
import '../services/rekap_excel.dart';
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
    final bulan = _bulanRekap;
    final tahun = _tahunRekap;
    setState(() => _loadingRekap = true);
    try {
      final awal = DateTime(tahun, bulan, 1).toIso8601String().substring(0, 10);
      final akhir = DateTime(
        tahun,
        bulan + 1,
        0,
      ).toIso8601String().substring(0, 10);

      // Join absensi dengan profiles untuk ambil nama peserta
      final response = await supabase
          .from('absensi')
          .select('*, profiles(nama_lengkap)')
          .gte('tanggal', awal)
          .lte('tanggal', akhir)
          .order('tanggal', ascending: false);

      if (!mounted || bulan != _bulanRekap || tahun != _tahunRekap) return;
      setState(() => _rekapSemua = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      if (mounted && bulan == _bulanRekap && tahun == _tahunRekap) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memuat rekap: $e')));
      }
    } finally {
      if (mounted && bulan == _bulanRekap && tahun == _tahunRekap) {
        setState(() => _loadingRekap = false);
      }
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
          backgroundColor: disetujui ? AppColors.tertiaryContainer : AppColors.error,
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
        const SnackBar(content: Text('Hari libur ditambahkan'), backgroundColor: AppColors.tertiaryContainer),
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
          backgroundColor: disetujui ? AppColors.tertiaryContainer : AppColors.error,
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
    return jamRekap(value);
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
                backgroundColor: sudahAbsen ? context.appColors.hadirBg : context.appColors.errorContainer,
                child: Icon(
                  sudahAbsen ? Icons.check : Icons.close,
                  color: sudahAbsen ? context.appColors.hadirText : context.appColors.error,
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

  // Pagination prevents a large monthly export from being silently truncated.
  Future<List<Map<String, dynamic>>> _ambilSemuaHalaman(
    Future<List<Map<String, dynamic>>> Function(int, int) ambil,
  ) async {
    const ukuran = 500;
    final hasil = <Map<String, dynamic>>[];
    while (true) {
      final halaman = await ambil(hasil.length, hasil.length + ukuran - 1);
      hasil.addAll(halaman);
      if (halaman.isEmpty) return hasil;
    }
  }

  Future<void> _unduhRekapXlsx() async {
    if (_sedangExport) return;
    final bulan = _bulanRekap;
    final tahun = _tahunRekap;
    final sekarang = DateTime.now();
    setState(() => _sedangExport = true);
    try {
      final awal = tanggalRekap(DateTime.utc(tahun, bulan, 1));
      final akhir = tanggalRekap(DateTime.utc(tahun, bulan + 1, 0));
      final data = await Future.wait([
        _ambilSemuaHalaman(
          (dari, sampai) async => await supabase
              .from('profiles')
              .select()
              .eq('role', 'peserta')
              .order('id')
              .range(dari, sampai),
        ),
        _ambilSemuaHalaman(
          (dari, sampai) async => await supabase
              .from('absensi')
              .select()
              .gte('tanggal', awal)
              .lte('tanggal', akhir)
              .order('id')
              .range(dari, sampai),
        ),
        _ambilSemuaHalaman(
          (dari, sampai) async => await supabase
              .from('izin')
              .select()
              .eq('status_persetujuan', 'disetujui')
              .lte('tanggal_mulai', akhir)
              .gte('tanggal_selesai', awal)
              .order('id')
              .range(dari, sampai),
        ),
        _ambilSemuaHalaman(
          (dari, sampai) async => await supabase
              .from('hari_libur')
              .select()
              .gte('tanggal', awal)
              .lte('tanggal', akhir)
              .order('id')
              .range(dari, sampai),
        ),
      ]);
      final rekap = RekapPresensi.hitung(
        bulan: bulan,
        tahun: tahun,
        profiles: data[0],
        absensi: data[1],
        izin: data[2],
        libur: data[3],
        sekarang: sekarang,
      );
      final bytes = buatExcelRekap(rekap);
      final namaFile = 'rekap_presensi_${_namaBulan(bulan)}_$tahun';

      try {
        final lokasi = await FileSaver.instance.saveAs(
          name: namaFile,
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        if (lokasi == null) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File Excel berhasil disimpan'),
              backgroundColor: AppColors.tertiaryContainer,
            ),
          );
        }
      } catch (e) {
        debugPrint('saveAs gagal, fallback ke share: $e');
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$namaFile.xlsx');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: namaFile),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal export: $e')));
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
            color: context.appColors.surfaceContainerLow,
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
                      onChanged: _sedangExport ? null : (v) {
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
                      onChanged: _sedangExport ? null : (v) {
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
                  label: const Text('Unduh Rekap & Detail'),
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

    label = statusPresensi(item).toUpperCase();
    switch (label) {
      case 'DISPENSASI':
        bg = context.appColors.dispensasiBg;
        text = context.appColors.dispensasiText;
      case 'TERLAMBAT':
        bg = context.appColors.izinBg;
        text = context.appColors.izinText;
      case 'HADIR':
        bg = context.appColors.hadirBg;
        text = context.appColors.hadirText;
      case 'IZIN':
      case 'SAKIT':
        bg = context.appColors.sakitBg;
        text = context.appColors.sakitText;
      default:
        bg = context.appColors.surfaceContainerHigh;
        text = context.appColors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
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
                  Text(item['keterangan'] ?? '-', style: TextStyle(color: context.appColors.onSurfaceVariant)),
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
                              color: context.appColors.surfaceContainerHigh,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: context.appColors.surfaceContainerHigh,
                            child: Center(child: Icon(Icons.broken_image_outlined, color: context.appColors.onSurfaceVariant)),
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
                          style: OutlinedButton.styleFrom(foregroundColor: context.appColors.error),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _prosesIzin(item['id'], true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiaryContainer, foregroundColor: Colors.white),
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
                              icon: Icon(Icons.delete_outline, color: context.appColors.error),
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
                  Text(item['keterangan'] ?? '-', style: TextStyle(color: context.appColors.onSurfaceVariant)),
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
                              color: context.appColors.surfaceContainerHigh,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: context.appColors.surfaceContainerHigh,
                            child: Center(child: Icon(Icons.broken_image_outlined, color: context.appColors.onSurfaceVariant)),
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
                          style: OutlinedButton.styleFrom(foregroundColor: context.appColors.error),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _prosesSusulan(item, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiaryContainer, foregroundColor: Colors.white),
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
