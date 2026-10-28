import 'dart:io';
import 'package:flutter/material.dart';
import '../services/attendance_requests.dart';
import '../theme/app_theme.dart';
import '../widgets/evidence_picker.dart';
import '../main.dart';

class IzinPage extends StatefulWidget {
  final int initialTab;
  const IzinPage({super.key, this.initialTab = 0}) : assert(initialTab >= 0 && initialTab < 2);

  @override
  State<IzinPage> createState() => _IzinPageState();
}

class _IzinPageState extends State<IzinPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izin / Sakit'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ajukan'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FormAjukanIzin(),
          _RiwayatIzin(),
        ],
      ),
    );
  }
}

// ============================================
// TAB 1: FORM PENGAJUAN
// ============================================
class _FormAjukanIzin extends StatefulWidget {
  const _FormAjukanIzin();

  @override
  State<_FormAjukanIzin> createState() => _FormAjukanIzinState();
}

class _FormAjukanIzinState extends State<_FormAjukanIzin> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();

  String _jenis = 'izin';
  DateTime? _tanggalMulai;
  DateTime? _tanggalSelesai;
  File? _buktiFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool isMulai}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() {
        if (isMulai) {
          _tanggalMulai = picked;
        } else {
          _tanggalSelesai = picked;
        }
      });
    }
  }

  Future<void> _pilihBukti() async {
    final file = await pilihBukti(context);
    if (file != null && mounted) setState(() => _buktiFile = File(file.path));
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalMulai == null || _tanggalSelesai == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan selesai')),
      );
      return;
    }
    if (_tanggalSelesai!.isBefore(_tanggalMulai!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal selesai tidak boleh sebelum tanggal mulai')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = appData.userId!;
      final start = _tanggalMulai!.toIso8601String().substring(0, 10);
      final end = _tanggalSelesai!.toIso8601String().substring(0, 10);
      final requests = AttendanceRequestsRepository();
      await requests.ensureCanRequest(userId, start, end);
      if (!mounted) return;
      await appData.submitRequest('izin', {
        'tanggal_mulai': start, 'tanggal_selesai': end,
        'jenis': _jenis, 'keterangan': _keteranganController.text.trim(),
      }, _buktiFile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengajuan berhasil dikirim! Menunggu persetujuan admin.'),
          backgroundColor: context.appColors.hadirText,
        ),
      );

      // Reset form
      setState(() {
        _tanggalMulai = null;
        _tanggalSelesai = null;
        _buktiFile = null;
        _keteranganController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengajukan izin: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTanggal(DateTime? dt) {
    if (dt == null) return 'Pilih tanggal';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AbsorbPointer(
        absorbing: _isLoading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Jenis', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Izin'),
                    value: 'izin',
                    groupValue: _jenis,
                    onChanged: (v) => setState(() => _jenis = v!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Sakit'),
                    value: 'sakit',
                    groupValue: _jenis,
                    onChanged: (v) => setState(() => _jenis = v!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihTanggal(isMulai: true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatTanggal(_tanggalMulai)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('s/d'),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pilihTanggal(isMulai: false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_formatTanggal(_tanggalSelesai)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _keteranganController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Jelaskan alasan izin/sakit Anda',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Keterangan tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pilihBukti,
              icon: const Icon(Icons.attach_file),
              label: Text(_buktiFile == null ? 'Lampirkan Bukti (opsional)' : 'Bukti terlampir ✓'),
            ),
            if (_buktiFile != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_buktiFile!, height: 150),
              ),
            ],
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// TAB 2: RIWAYAT PENGAJUAN
// ============================================
class _RiwayatIzin extends StatefulWidget {
  const _RiwayatIzin();

  @override
  State<_RiwayatIzin> createState() => _RiwayatIzinState();
}

class _RiwayatIzinState extends State<_RiwayatIzin> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _riwayat = [];

  @override
  void initState() {
    super.initState();
    _ambilRiwayat();
  }

  Future<void> _ambilRiwayat() async {
    setState(() => _isLoading = true);
    try {
      final response = await appData.requests('izin');

      setState(() => _riwayat = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Gagal ambil riwayat izin: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _warnaStatus(String status) {
    switch (status) {
      case 'disetujui':
        return context.appColors.hadirText;
      case 'ditolak':
        return context.appColors.error;
      default:
        return context.appColors.izinText;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _ambilRiwayat,
      child: _riwayat.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 100),
                Center(child: Text('Belum ada pengajuan izin')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _riwayat.length,
              itemBuilder: (context, index) {
                final item = _riwayat[index];
                final status = item['status_persetujuan'] as String? ?? 'menunggu';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              (item['jenis'] as String).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _warnaStatus(status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _warnaStatus(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${item['tanggal_mulai']} s/d ${item['tanggal_selesai']}'),
                        const SizedBox(height: 4),
                        Text(
                          item['keterangan'] ?? '-',
                          style: TextStyle(color: context.appColors.onSurfaceVariant),
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