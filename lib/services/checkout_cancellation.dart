import 'package:supabase_flutter/supabase_flutter.dart';

import 'daily_attendance.dart';
import 'rekap_presensi.dart';

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
  final SupabaseClient client;
  const CheckoutCancellationRepository(this.client);

  Future<List<Map<String, dynamic>>> load(String userId, bool isAdmin) async {
    var query = client
        .from('pembatalan_pulang')
        .select(
          isAdmin
              ? '*, profiles!pembatalan_pulang_user_id_fkey(nama_lengkap)'
              : '*',
        );
    query = isAdmin
        ? query.eq('status_persetujuan', 'menunggu')
        : query.eq('user_id', userId);
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await query
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      result.addAll(page);
      if (page.length < 200) return result;
      offset += page.length;
    }
  }

  Future<void> submit(String attendanceId, String reason) async {
    await client.rpc(
      'ajukan_pembatalan_pulang',
      params: {'p_absensi_id': attendanceId, 'p_alasan': reason.trim()},
    );
  }

  Future<void> process(String requestId, bool approve) async {
    await client.rpc(
      'proses_pembatalan_pulang',
      params: {'p_request_id': requestId, 'p_setujui': approve},
    );
  }
}
