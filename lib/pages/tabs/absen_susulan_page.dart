import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/attendance_requests.dart';
import '../../widgets/evidence_picker.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';

class AbsenSusulanPage extends StatefulWidget {
  final int initialTab;
  const AbsenSusulanPage({super.key, this.initialTab = 0}) : assert(initialTab >= 0 && initialTab < 2);

  @override
  State<AbsenSusulanPage> createState() => _AbsenSusulanPageState();
}

class _AbsenSusulanPageState extends State<AbsenSusulanPage> with SingleTickerProviderStateMixin {
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
        title: const Text('Absen Susulan'),
        foregroundColor: context.appColors.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.appColors.primary,
          tabs: const [Tab(text: 'Ajukan'), Tab(text: 'Riwayat')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_FormAjukanSusulan(), _RiwayatSusulan()],
      ),
    );
  }
}

const Map<String, String> kLabelAlasan = {
  'dispensasi': 'Dispensasi',
  'lupa_absen': 'Lupa Absen',
  'gps_error': 'GPS / Lokasi Error',
  'lainnya': 'Lainnya',
};

// ============================================
// TAB 1: FORM PENGAJUAN
// ============================================
class _FormAjukanSusulan extends StatefulWidget {
  const _FormAjukanSusulan();

  @override
  State<_FormAjukanSusulan> createState() => _FormAjukanSusulanState();
}

class _FormAjukanSusulanState extends State<_FormAjukanSusulan> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();

  DateTime? _tanggal;
  TimeOfDay? _jamMasuk;
  TimeOfDay? _jamPulang;
  bool _isiMasuk = true;
  bool _isiPulang = false;
  String _jenisAlasan = 'lupa_absen';
  File? _buktiFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 14)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  Future<void> _pilihJam({required bool isMasuk}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isMasuk) {
          _jamMasuk = picked;
        } else {
          _jamPulang = picked;
        }
      });
    }
  }

  Future<void> _pilihBukti() async {
    final file = await pilihBukti(context);
    if (file != null && mounted) setState(() => _buktiFile = File(file.path));
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    if (_tanggal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal terlebih dahulu')));
      return;
    }
    if (!_isiMasuk || _jamMasuk == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jam masuk wajib diisi untuk absen susulan')));
      return;
    }
    if (_isiMasuk && _jamMasuk == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih jam masuk')));
      return;
    }
    if (_isiPulang && _jamPulang == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih jam pulang')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = appData.userId!;
      final start = _tanggal!.toIso8601String().substring(0, 10);
      final end = _tanggal!.toIso8601String().substring(0, 10);
      final requests = AttendanceRequestsRepository();
      await requests.ensureCanRequest(userId, start, end);
      if (!mounted) return;
      await appData.submitRequest('susulan', {
        'tanggal': start,
        'jam_masuk_diajukan': _isiMasuk ? _formatTimeOfDay(_jamMasuk!) : null,
        'jam_pulang_diajukan': _isiPulang ? _formatTimeOfDay(_jamPulang!) : null,
        'jenis_alasan': _jenisAlasan, 'keterangan': _keteranganController.text.trim(),
      }, _buktiFile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan terkirim! Menunggu persetujuan admin.'), backgroundColor: AppColors.tertiaryContainer),
      );

      setState(() {
        _tanggal = null;
        _jamMasuk = null;
        _jamPulang = null;
        _buktiFile = null;
        _keteranganController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengajukan: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.appColors.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.appColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gunakan untuk tanggal ketika Anda hadir/bekerja tetapi belum memiliki presensi atau pengajuan aktif. Presensi yang sudah tercatat tidak dapat diubah melalui susulan.',
                      style: AppText.bodyMd.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _pilihTanggal,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_tanggal == null ? 'Pilih Tanggal' : '${_tanggal!.day}/${_tanggal!.month}/${_tanggal!.year}'),
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              value: _isiMasuk,
              onChanged: (v) => setState(() => _isiMasuk = v!),
              title: const Text('Isi Jam Masuk'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_isiMasuk)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _pilihJam(isMasuk: true),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_jamMasuk == null ? 'Pilih Jam Masuk' : _jamMasuk!.format(context)),
                ),
              ),

            CheckboxListTile(
              value: _isiPulang,
              onChanged: (v) => setState(() => _isiPulang = v!),
              title: const Text('Isi Jam Pulang'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_isiPulang)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _pilihJam(isMasuk: false),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(_jamPulang == null ? 'Pilih Jam Pulang' : _jamPulang!.format(context)),
                ),
              ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              isExpanded: true, isDense: false, itemHeight: null,
              initialValue: _jenisAlasan,
              decoration: const InputDecoration(labelText: 'Jenis Alasan'),
              items: kLabelAlasan.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _jenisAlasan = v!),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _keteranganController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Jelaskan kronologi/alasan Anda',
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Keterangan tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pilihBukti,
              icon: const Icon(Icons.attach_file),
              label: Text(_buktiFile == null ? 'Lampirkan Bukti (opsional)' : 'Bukti terlampir ✓'),
            ),
            if (_buktiFile != null) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_buktiFile!, height: 150)),
            ],
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.primary,
                foregroundColor: context.appColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.onPrimary))
                  : const Text('Ajukan Absen Susulan'),
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
class _RiwayatSusulan extends StatefulWidget {
  const _RiwayatSusulan();

  @override
  State<_RiwayatSusulan> createState() => _RiwayatSusulanState();
}

class _RiwayatSusulanState extends State<_RiwayatSusulan> {
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
      final response = await appData.requests('susulan');
      setState(() => _riwayat = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Gagal ambil riwayat susulan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _warnaStatus(String status) {
    switch (status) {
      case 'disetujui':
        return context.appColors.tertiaryContainer;
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
              children: const [SizedBox(height: 100), Center(child: Text('Belum ada pengajuan absen susulan'))],
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
                            Text(item['tanggal'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _warnaStatus(status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(color: _warnaStatus(status), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(kLabelAlasan[item['jenis_alasan']] ?? '-', style: AppText.labelMd),
                        const SizedBox(height: 4),
                        if (item['jam_masuk_diajukan'] != null)
                          Text('Jam masuk diajukan: ${item['jam_masuk_diajukan'].toString().substring(0, 5)}', style: AppText.bodyMd),
                        if (item['jam_pulang_diajukan'] != null)
                          Text('Jam pulang diajukan: ${item['jam_pulang_diajukan'].toString().substring(0, 5)}', style: AppText.bodyMd),
                        const SizedBox(height: 4),
                        Text(item['keterangan'] ?? '-', style: AppText.bodyMd.copyWith(color: context.appColors.secondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}