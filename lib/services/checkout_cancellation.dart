import 'daily_attendance.dart';
import 'rekap_presensi.dart';
import 'app_data.dart';

bool canCancelCheckout(
  Map<String, dynamic>? attendance, {
  DateTime? now,
  bool hasActiveRequest = false,
}) {
  if (hasActiveRequest ||
      attendance == null ||
      attendance['jam_masuk'] == null ||
      attendance['jam_pulang'] == null ||
      !['hadir', 'terlambat'].contains(attendance['status'])) {
    return false;
  }
  final checkout = DateTime.tryParse(attendance['jam_pulang'].toString());
  if (checkout == null) return false;
  return attendance['tanggal'] == tanggalPresensiHariIni(now) &&
      tanggalRekap(waktuWib(checkout)) == attendance['tanggal'] &&
      waktuWib(checkout).hour < 16;
}

class CheckoutCancellationRepository {
  final AppData data;
  CheckoutCancellationRepository({AppData? data}) : data = data ?? appData;

  Future<List<Map<String, dynamic>>> load(String userId, bool isAdmin) =>
      data.requests(
        'pembatalan',
        admin: isAdmin,
        status: isAdmin ? 'menunggu' : null,
      );
  Future<void> submit(String attendanceId, String reason) async {
    await data.api.json(
      'POST',
      '/api/requests/pembatalan',
      body: {'absensi_id': attendanceId, 'alasan': reason.trim()},
    );
  }

  Future<void> process(String requestId, bool approve) => data.decide(
    'pembatalan',
    requestId,
    approve,
    reason: approve ? null : 'Pembatalan jam pulang tidak disetujui admin.',
  );
}
