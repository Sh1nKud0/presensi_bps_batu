import 'package:supabase_flutter/supabase_flutter.dart';

import 'rekap_presensi.dart';

String tanggalPresensiHariIni([DateTime? now]) =>
    tanggalRekap(waktuWib(now ?? DateTime.now()));

class DailyAttendance {
  final Map<String, dynamic>? attendance;
  final bool hasLeave;
  final bool hasCorrection;
  final bool holiday;
  final String? holidayDescription;

  const DailyAttendance({
    this.attendance,
    this.hasLeave = false,
    this.hasCorrection = false,
    this.holiday = false,
    this.holidayDescription,
  });

  bool get checkedIn => attendance?['jam_masuk'] != null;
  bool get checkedOut => attendance?['jam_pulang'] != null;

  String? get requestBlockReason {
    if (hasLeave) return 'Anda sudah mengajukan izin/sakit untuk hari ini.';
    if (hasCorrection) {
      return 'Anda sudah mengajukan absen susulan untuk hari ini.';
    }
    return null;
  }

  String? get blockReason {
    if (holiday) return 'Hari ini libur, presensi tidak diperlukan.';
    if (requestBlockReason != null) return requestBlockReason;
    if (checkedOut) return 'Presensi hari ini sudah selesai.';
    if (attendance != null &&
        (!checkedIn ||
            !['hadir', 'terlambat'].contains(attendance!['status']))) {
      return 'Data presensi hari ini sudah tercatat. Periksa riwayat Anda.';
    }
    return null;
  }
}

class DailyAttendanceRepository {
  final SupabaseClient client;
  const DailyAttendanceRepository(this.client);

  Future<DailyAttendance> load(String userId, {String? date}) async {
    final day = date ?? tanggalPresensiHariIni();
    final rows = await Future.wait([
      client.from('absensi').select().eq('user_id', userId).eq('tanggal', day),
      client
          .from('izin')
          .select('id')
          .eq('user_id', userId)
          .lte('tanggal_mulai', day)
          .gte('tanggal_selesai', day)
          .inFilter('status_persetujuan', ['menunggu', 'disetujui'])
          .limit(1),
      client
          .from('absen_susulan')
          .select('id')
          .eq('user_id', userId)
          .eq('tanggal', day)
          .inFilter('status_persetujuan', ['menunggu', 'disetujui'])
          .limit(1),
      client
          .from('hari_libur')
          .select('id, keterangan')
          .eq('tanggal', day)
          .limit(1),
    ]);
    final weekday = DateTime.parse(day).weekday;
    return DailyAttendance(
      attendance: rows[0].isEmpty ? null : rows[0].single,
      hasLeave: rows[1].isNotEmpty,
      hasCorrection: rows[2].isNotEmpty,
      holiday: weekday >= DateTime.saturday || rows[3].isNotEmpty,
      holidayDescription: rows[3].isNotEmpty
          ? rows[3].first['keterangan'] as String?
          : null,
    );
  }
}
