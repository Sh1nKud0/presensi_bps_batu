import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceRequestConflict implements Exception {
  final String message;
  const AttendanceRequestConflict(this.message);
  @override
  String toString() => message;
}

/// One attendance record or active request per date. Rejected requests may retry.
class AttendanceRequestsRepository {
  final SupabaseClient client;
  const AttendanceRequestsRepository(this.client);

  Future<void> ensureNoAttendance(
    String userId,
    String start,
    String end,
  ) async {
    final rows = await client
        .from('absensi')
        .select('tanggal')
        .eq('user_id', userId)
        .gte('tanggal', start)
        .lte('tanggal', end)
        .order('tanggal')
        .limit(1);
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
    final rows = await Future.wait([
      client
          .from('izin')
          .select('id')
          .eq('user_id', userId)
          .lte('tanggal_mulai', end)
          .gte('tanggal_selesai', start)
          .inFilter('status_persetujuan', ['menunggu', 'disetujui'])
          .limit(1),
      client
          .from('absen_susulan')
          .select('id')
          .eq('user_id', userId)
          .gte('tanggal', start)
          .lte('tanggal', end)
          .inFilter('status_persetujuan', ['menunggu', 'disetujui'])
          .limit(1),
    ]);
    if (rows.any((items) => items.isNotEmpty)) {
      throw const AttendanceRequestConflict(
        'Tanggal yang dipilih sudah memiliki pengajuan izin/sakit atau susulan '
        'yang menunggu atau disetujui. Pengajuan tidak dapat ditumpuk.',
      );
    }
  }
}
