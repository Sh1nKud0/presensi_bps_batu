import 'package:flutter/material.dart';

import '../main.dart';
import '../services/checkout_cancellation.dart';
import '../services/daily_attendance.dart';
import '../services/rekap_presensi.dart';
import '../services/api_client.dart';

class PembatalanPulangPage extends StatelessWidget {
  final bool isAdmin;
  const PembatalanPulangPage({super.key, this.isAdmin = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pembatalan Absen Pulang')),
    body: PembatalanPulangContent(isAdmin: isAdmin),
  );
}

class PembatalanPulangContent extends StatefulWidget {
  final bool isAdmin;
  const PembatalanPulangContent({super.key, required this.isAdmin});
  @override
  State<PembatalanPulangContent> createState() =>
      _PembatalanPulangContentState();
}

class _PembatalanPulangContentState extends State<PembatalanPulangContent> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _busy = false;
  bool _fetching = false;
  String? _error;
  Map<String, dynamic>? _attendance;
  bool _hasActiveRequest = false;
  List<Map<String, dynamic>> _requests = [];
  CheckoutCancellationRepository get _repository =>
      CheckoutCancellationRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Tidak dapat terhubung. Silakan coba lagi.';

  Future<void> _load() async {
    if (_busy || _fetching) return;
    _fetching = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = appData.userId!;
      final requests = await _repository.load(userId, widget.isAdmin);
      final daily = widget.isAdmin
          ? null
          : await DailyAttendanceRepository().load(userId);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _attendance = daily?.attendance;
        _hasActiveRequest = daily?.requestBlockReason != null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _loading || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _repository.submit(_attendance!['id'] as String, _reason.text);
      _reason.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengajuan dikirim. Jam pulang tetap tercatat sampai admin menyetujui.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _process(Map<String, dynamic> request, bool approve) async {
    if (_busy || _loading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Setujui pembatalan?' : 'Tolak pembatalan?'),
        content: Text(
          approve
              ? 'Jam pulang ${jamRekap(request['jam_pulang_awal'])} akan dihapus. Jam masuk tetap tersimpan dan pengguna dapat absen pulang kembali.'
              : 'Jam pulang pengguna tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _repository.process(request['id'] as String, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Pembatalan disetujui. Jam pulang telah dikosongkan.'
                  : 'Pembatalan ditolak.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = canCancelCheckout(
      _attendance,
      hasActiveRequest: _hasActiveRequest,
    );
    final pending = _requests.any(
      (r) =>
          r['absensi_id'] == _attendance?['id'] &&
          r['status_persetujuan'] == 'menunggu',
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading || _busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: _loading || _busy ? null : _load,
              child: const Text('Coba lagi'),
            ),
          ],
          if (!widget.isAdmin) ...[
            const Text(
              'Salah menekan absen pulang?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pengajuan hanya untuk absen pulang hari ini yang tercatat sebelum 16.00 WIB. Admin harus menyetujui pada hari yang sama. Jam masuk tidak dihapus.',
            ),
            const SizedBox(height: 12),
            if (pending)
              const Text('Pengajuan masih menunggu persetujuan admin.')
            else if (eligible && !_loading && _error == null)
              Form(
                key: _form,
                child: Column(
                  children: [
                    Text(
                      'Jam pulang tercatat: ${jamRekap(_attendance!['jam_pulang'])} WIB',
                    ),
                    TextFormField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 1000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Alasan pembatalan',
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 5
                          ? 'Isi alasan minimal 5 karakter.'
                          : null,
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: const Icon(Icons.undo),
                      label: const Text('Ajukan Pembatalan'),
                    ),
                  ],
                ),
              )
            else if (!_loading && _error == null)
              const Text(
                'Tidak ada absen pulang hari ini yang memenuhi syarat pembatalan.',
              ),
            const SizedBox(height: 24),
            const Text(
              'Riwayat Pengajuan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          if (!_loading && _error == null && _requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada pengajuan pembatalan.'),
            ),
          ..._requests.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isAdmin)
                      Text(
                        r['profiles']?['nama_lengkap'] ?? 'Peserta',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    Text(
                      '${r['tanggal']} • Jam pulang ${jamRekap(r['jam_pulang_awal'])} WIB',
                    ),
                    const SizedBox(height: 6),
                    Text(r['alasan'] as String),
                    const SizedBox(height: 6),
                    Text('Status: ${r['status_persetujuan']}'),
                    if (widget.isAdmin)
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: _busy || _loading || _error != null
                                ? null
                                : () => _process(r, false),
                            child: const Text('Tolak'),
                          ),
                          FilledButton(
                            onPressed: _busy || _loading || _error != null
                                ? null
                                : () => _process(r, true),
                            child: const Text('Setujui'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
