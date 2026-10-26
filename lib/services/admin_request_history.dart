import 'app_data.dart';
import 'rekap_presensi.dart';

class AdminRequestHistoryItem {
  final String kind;
  final Map<String, dynamic> record;
  const AdminRequestHistoryItem(this.kind, this.record);
  String get name =>
      record['profiles']?['nama_lengkap'] ??
      record['nama_lengkap'] ??
      'Peserta';
  String get label =>
      {'izin': 'Izin', 'sakit': 'Sakit', 'susulan': 'Absen Susulan'}[kind]!;
  String get status => record['status_persetujuan'] as String;
  String get statusLabel =>
      {
        'menunggu': 'Menunggu persetujuan',
        'disetujui': 'Disetujui',
        'ditolak': 'Ditolak',
      }[status] ??
      status;
  String get start => (record['tanggal_mulai'] ?? record['tanggal'])
      .toString()
      .substring(0, 10);
  String get end => (record['tanggal_selesai'] ?? record['tanggal'])
      .toString()
      .substring(0, 10);
  DateTime get created => DateTime.parse(record['created_at'] as String);
}

String historyDate(String value) {
  final day = DateTime.parse(value);
  return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
}

String historyTime(dynamic value) {
  if (value == null) return 'Belum diproses';
  final day = waktuWib(DateTime.parse(value.toString()));
  return '${historyDate(tanggalRekap(day))} ${day.hour.toString().padLeft(2, '0')}:${day.minute.toString().padLeft(2, '0')} WIB';
}

List<AdminRequestHistoryItem> filterAdminRequestHistory(
  List<AdminRequestHistoryItem> items, {
  String? kind,
  String? status,
  String name = '',
  String? from,
  String? to,
}) => items
    .where(
      (item) =>
          (kind == null || item.kind == kind) &&
          (status == null || item.status == status) &&
          item.name.toLowerCase().contains(name.trim().toLowerCase()) &&
          (from == null || item.end.compareTo(from) >= 0) &&
          (to == null || item.start.compareTo(to) <= 0),
    )
    .toList();

abstract interface class AdminRequestHistorySource {
  Future<List<AdminRequestHistoryItem>> load();
}

class AdminRequestHistoryRepository implements AdminRequestHistorySource {
  final AppData data;
  AdminRequestHistoryRepository({AppData? data}) : data = data ?? appData;

  @override
  Future<List<AdminRequestHistoryItem>> load() async {
    final results = await Future.wait([
      data.requests('izin', admin: true),
      data.requests('susulan', admin: true),
    ]);
    return [
      for (final row in results[0])
        AdminRequestHistoryItem(
          row['jenis'] == 'sakit' ? 'sakit' : 'izin',
          row,
        ),
      for (final row in results[1]) AdminRequestHistoryItem('susulan', row),
    ]..sort((a, b) {
      final order = b.created.compareTo(a.created);
      return order != 0
          ? order
          : '${a.kind}/${a.record['id']}'.compareTo(
              '${b.kind}/${b.record['id']}',
            );
    });
  }
}
