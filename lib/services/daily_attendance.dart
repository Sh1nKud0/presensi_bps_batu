import 'rekap_presensi.dart';
import 'app_data.dart';

/// Menghasilkan kunci tanggal presensi hari ini dalam zona waktu kantor (WIB).
String tanggalPresensiHariIni([DateTime? now]) =>
    tanggalRekap(waktuWib(now ?? DateTime.now()));

/// Ringkasan presensi harian yang dipakai oleh beranda dan alur presensi.
class DailyAttendance {
  final Map<String, dynamic>? attendance;
  final bool hasLeave;
  final bool hasCorrection;
  final bool holiday;
  final String? holidayDescription;
  final String? serverBlockReason;
  final String? serverRequestBlockReason;

  const DailyAttendance({
    this.attendance,
    this.hasLeave = false,
    this.hasCorrection = false,
    this.holiday = false,
    this.holidayDescription,
    this.serverBlockReason,
    this.serverRequestBlockReason,
  });

  bool get checkedIn => attendance?['jam_masuk'] != null;
  bool get checkedOut => attendance?['jam_pulang'] != null;

  String? get requestBlockReason {
    if (serverRequestBlockReason != null) return serverRequestBlockReason;
    if (hasLeave) return 'Anda sudah mengajukan izin/sakit untuk hari ini.';
    if (hasCorrection) {
      return 'Anda sudah mengajukan absen susulan untuk hari ini.';
    }
    return null;
  }

  String? get blockReason {
    if (serverBlockReason != null) return serverBlockReason;
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

/// Mengambil dan mengirim perubahan presensi melalui backend aplikasi.
class DailyAttendanceRepository {
  final AppData data;
  DailyAttendanceRepository({AppData? data}) : data = data ?? appData;

  Future<DailyAttendance> load(String userId) async {
    final result = await data.api.json('GET', '/api/attendance/today');
    return DailyAttendance(
      attendance: result['attendance'] as Map<String, dynamic>?,
      holiday: result['hari_libur'] != null,
      holidayDescription: result['hari_libur'] as String?,
      serverBlockReason: result['block_reason'] as String?,
      serverRequestBlockReason: result['request_block_reason'] as String?,
    );
  }
}
