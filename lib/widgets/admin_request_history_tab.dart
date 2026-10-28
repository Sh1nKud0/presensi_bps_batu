import 'package:flutter/material.dart';

import '../services/admin_request_history.dart';
import '../services/rekap_presensi.dart';
import '../theme/app_theme.dart';
import 'evidence_image.dart';

class AdminRequestHistoryTab extends StatefulWidget {
  final AdminRequestHistorySource? repository;
  final int revision;
  const AdminRequestHistoryTab({super.key, this.repository, this.revision = 0});
  @override
  State<AdminRequestHistoryTab> createState() => _AdminRequestHistoryTabState();
}

class _AdminRequestHistoryTabState extends State<AdminRequestHistoryTab>
    with WidgetsBindingObserver {
  List<AdminRequestHistoryItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _kind;
  String? _status;
  String _name = '';
  DateTimeRange? _period;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminRequestHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final items = await (widget.repository ?? AdminRequestHistoryRepository())
          .load();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Riwayat belum dapat dimuat. Ketuk Perbarui untuk mencoba lagi.',
        );
      }
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      initialDateRange: _period,
      helpText: 'Periode tanggal izin / susulan',
    );
    if (mounted && selected != null) setState(() => _period = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visible = filterAdminRequestHistory(
      _items,
      kind: _kind,
      status: _status,
      name: _name,
      from: _period == null ? null : tanggalRekap(_period!.start),
      to: _period == null ? null : tanggalRekap(_period!.end),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat Pengajuan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Perbarui riwayat',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Cari nama peserta',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _name = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const <String, String>{
                '': 'Semua jenis',
                'izin': 'Izin',
                'sakit': 'Sakit',
                'susulan': 'Susulan',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: (_kind ?? '') == entry.key,
                  onSelected: (_) => setState(
                    () => _kind = entry.key.isEmpty ? null : entry.key,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: '',
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(labelText: 'Status pengajuan'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Semua status')),
              DropdownMenuItem(
                value: 'menunggu',
                child: Text('Menunggu persetujuan'),
              ),
              DropdownMenuItem(value: 'disetujui', child: Text('Disetujui')),
              DropdownMenuItem(value: 'ditolak', child: Text('Ditolak')),
            ],
            onChanged: (value) =>
                setState(() => _status = value == '' ? null : value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickPeriod,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _period == null
                      ? 'Semua tanggal izin / susulan'
                      : '${historyDate(tanggalRekap(_period!.start))} - ${historyDate(tanggalRekap(_period!.end))}',
                ),
              ),
              if (_period != null)
                TextButton(
                  onPressed: () => setState(() => _period = null),
                  child: const Text('Hapus periode'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.appColors.error))
          else
            Text('${visible.length} pengajuan • Waktu ditampilkan dalam WIB'),
          if (visible.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Tidak ada pengajuan sesuai filter.'),
            ),
          for (final item in visible) _HistoryCard(item: item),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AdminRequestHistoryItem item;
  const _HistoryCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final row = item.record;
    final color = item.status == 'ditolak'
        ? context.appColors.error
        : item.status == 'disetujui'
        ? context.appColors.hadirText
        : context.appColors.izinText;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(item.label),
                Text(
                  item.statusLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${item.kind == 'susulan' ? 'Tanggal susulan' : 'Tanggal izin/sakit'}: ${historyDate(item.start)}${item.start == item.end ? '' : ' - ${historyDate(item.end)}'}',
            ),
            Text('Diajukan: ${historyTime(row['created_at'])}'),
            Text('Diproses: ${historyTime(row['diproses_at'])}'),
            if (item.kind == 'susulan') ...[
              if (row['jam_masuk_diajukan'] != null)
                Text(
                  'Jam masuk diajukan: ${row['jam_masuk_diajukan'].toString().substring(0, 5)}',
                ),
              if (row['jam_pulang_diajukan'] != null)
                Text(
                  'Jam pulang diajukan: ${row['jam_pulang_diajukan'].toString().substring(0, 5)}',
                ),
            ],
            if (row['keterangan'] != null)
              Text('Keterangan: ${row['keterangan']}'),
            if (row['alasan_penolakan'] != null)
              Text('Alasan ditolak: ${row['alasan_penolakan']}'),
            if (row['bukti_url'] != null)
              TextButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('Lihat bukti'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Bukti ${item.label}'),
                    content: SizedBox(
                      width: 360,
                      child: InteractiveViewer(
                        child: EvidenceImage(
                          row['bukti_url'] as String,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
