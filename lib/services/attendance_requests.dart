import 'app_data.dart';

class AttendanceRequestConflict implements Exception {
  final String message;
  const AttendanceRequestConflict(this.message);
  @override
  String toString() => message;
}

/// UI preflight only. The backend rechecks conflicts inside the write transaction.
class AttendanceRequestsRepository {
  final AppData data;
  AttendanceRequestsRepository({AppData? data}) : data = data ?? appData;

  Future<void> ensureNoAttendance(
    String userId,
    String start,
    String end,
  ) async {
    final rows = await data.history(start, end);
    if (rows.isNotEmpty) {
      final date = DateTime.parse(rows.first['tanggal'] as String);
      throw AttendanceRequestConflict(
        'Presensi tanggal ${date.day}/${date.month}/${date.year} sudah tercatat. '
        'Izin/sakit atau susulan tidak dapat mengganti presensi tersebut.',
      );
    }
  }

  Future<void> ensureCanRequest(String userId, String start, String end) async {
    await ensureNoAttendance(userId, start, end);
    final requests = await Future.wait([
      data.requests('izin'),
      data.requests('susulan'),
    ]);
    for (final row in requests.expand((items) => items)) {
      final first = (row['tanggal_mulai'] ?? row['tanggal']) as String;
      final last = (row['tanggal_selesai'] ?? row['tanggal']) as String;
      if (['menunggu', 'disetujui'].contains(row['status_persetujuan']) &&
          first.compareTo(end) <= 0 &&
          last.compareTo(start) >= 0) {
        throw const AttendanceRequestConflict(
          'Tanggal ini sudah memiliki pengajuan aktif.',
        );
      }
    }
  }
}
