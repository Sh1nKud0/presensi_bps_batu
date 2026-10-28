import 'app_data.dart';

class AdminDailyStatus {
  final String label;
  final bool pending;
  final Map<String, dynamic>? attendance;
  final String? kind;

  const AdminDailyStatus(
    this.label, {
    this.pending = false,
    this.attendance,
    this.kind,
  });
}

Map<String, AdminDailyStatus> adminDailyStatuses({
  required String day,
  required List<Map<String, dynamic>> attendance,
  required List<Map<String, dynamic>> leave,
  required List<Map<String, dynamic>> supplementary,
}) {
  final result = <String, AdminDailyStatus>{};
  for (final row in supplementary) {
    if (row['tanggal'] == day && row['status_persetujuan'] == 'menunggu') {
      result[row['user_id'] as String] = const AdminDailyStatus(
        'Absen susulan menunggu persetujuan',
        pending: true,
        kind: 'susulan',
      );
    }
  }
  for (final approved in [false, true]) {
    for (final row in leave) {
      final status = row['status_persetujuan'];
      if (status != (approved ? 'disetujui' : 'menunggu')) continue;
      final start = row['tanggal_mulai'].toString().substring(0, 10);
      final end = row['tanggal_selesai'].toString().substring(0, 10);
      if (day.compareTo(start) < 0 || day.compareTo(end) > 0) continue;
      final kind = row['jenis'] == 'sakit' ? 'Sakit' : 'Izin';
      result[row['user_id'] as String] = AdminDailyStatus(
        approved ? '$kind disetujui' : '$kind menunggu persetujuan',
        pending: !approved,
        kind: row['jenis'] == 'sakit' ? 'sakit' : 'izin',
      );
    }
  }
  for (final row in attendance) {
    if (row['tanggal'].toString().substring(0, 10) != day) continue;
    final kind = row['status'];
    if (row['jam_masuk'] == null && ['izin', 'sakit'].contains(kind)) {
      result[row['user_id'] as String] = AdminDailyStatus(
        kind == 'sakit' ? 'Sakit disetujui' : 'Izin disetujui',
        kind: kind as String,
      );
      continue;
    }
    if (row['jam_masuk'] == null && result.containsKey(row['user_id'])) {
      continue;
    }
    result[row['user_id'] as String] = AdminDailyStatus(
      row['jam_masuk'] != null ? 'Sudah presensi' : 'Presensi tercatat',
      attendance: row,
    );
  }
  return result;
}

class AdminDailyOverview {
  final List<Map<String, dynamic>> participants;
  final Map<String, AdminDailyStatus> statuses;
  final String day;
  const AdminDailyOverview(this.participants, this.statuses, this.day);
}

class AdminDailyAttendanceRepository {
  final AppData data;
  AdminDailyAttendanceRepository({AppData? data}) : data = data ?? appData;

  Future<AdminDailyOverview> load() async {
    final first = await data.api.json(
      'GET',
      '/api/admin/attendance',
      query: {'limit': '100', 'offset': '0'},
    );
    final day = first['tanggal_server'] as String;
    final rows = List<Map<String, dynamic>>.from(first['attendance'] as List);
    while (rows.length % 100 == 0 && rows.isNotEmpty) {
      final next = await data.api.json(
        'GET',
        '/api/admin/attendance',
        query: {
          'from': day,
          'to': day,
          'limit': '100',
          'offset': '${rows.length}',
        },
      );
      final page = List<Map<String, dynamic>>.from(next['attendance'] as List);
      rows.addAll(page);
      if (page.length < 100) break;
    }
    final results = await Future.wait([
      data.api.all('/api/admin/participants', 'participants'),
      data.requests('izin', admin: true),
      data.requests('susulan', admin: true, status: 'menunggu'),
    ]);
    return AdminDailyOverview(
      results[0],
      adminDailyStatuses(
        day: day,
        attendance: rows,
        leave: results[1],
        supplementary: results[2],
      ),
      day,
    );
  }
}
