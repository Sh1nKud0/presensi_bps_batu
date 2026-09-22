import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _izinMenunggu = [];
  List<Map<String, dynamic>> _daftarHariLibur = [];

  bool _loadingSusulan = true;
  List<Map<String, dynamic>> _susulanMenunggu = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _ambilDataHariIni();
    _ambilRekapSemua();
    _ambilIzinMenunggu();
    _ambilHariLibur();
    _ambilSusulanMenunggu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      // Join absensi dengan profiles untuk ambil nama peserta
      final response = await supabase
          .from('absensi')
          .select('*, profiles(nama_lengkap)')
          .order('tanggal', ascending: false)
          .limit(100);

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
          .gte('tanggal', DateTime.now().toIso8601String().substring(0, 10))
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
          if (jenisAlasan == 'dinas_luar') {
            statusBaru = 'dinas_luar';
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
          tabs: const [
            Tab(text: 'Hari Ini'),
            Tab(text: 'Rekap Semua'),
            Tab(text: 'Izin'),
            Tab(text: 'Hari Libur'),
            Tab(text: 'Susulan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabHariIni(),
          _buildTabRekap(),
          _buildTabIzin(),
          _buildTabHariLibur(),
          _buildTabSusulan(),
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

  Widget _buildTabRekap() {
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
              trailing: Text(
                (item['status'] as String? ?? '-').toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
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
            'dinas_luar': 'Dinas Luar',
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