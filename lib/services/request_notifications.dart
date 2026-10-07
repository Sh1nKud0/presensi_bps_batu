import 'package:supabase_flutter/supabase_flutter.dart';

import 'rekap_presensi.dart';

List<RequestNotification> filterNotificationsByDay(
  List<RequestNotification> items,
  DateTime? day,
) => day == null
    ? items
    : items
          .where(
            (item) =>
                tanggalRekap(waktuWib(item.createdAt)) == tanggalRekap(day),
          )
          .toList();

class RequestNotification {
  final String id;
  final String table;
  final String status;
  final String title;
  final String message;
  final DateTime createdAt;

  const RequestNotification({
    required this.id,
    required this.table,
    required this.status,
    required this.title,
    required this.message,
    required this.createdAt,
  });
  String get readKey => '$table/$id/$status';
}

List<RequestNotification> buildRequestNotifications({
  required String userId,
  required bool isAdmin,
  required Map<String, List<Map<String, dynamic>>> records,
}) {
  final result = <RequestNotification>[];
  records.forEach((table, rows) {
    for (final row in rows) {
      final status = row['status_persetujuan'];
      if (isAdmin
          ? status != 'menunggu'
          : row['user_id'] != userId ||
                !['disetujui', 'ditolak'].contains(status)) {
        continue;
      }
      final jenis = table == 'izin'
          ? (row['jenis'] == 'sakit' ? 'sakit' : 'izin')
          : table == 'pembatalan_pulang'
          ? 'pembatalan absen pulang'
          : 'absen susulan';
      final profile = row['profiles'] as Map<String, dynamic>?;
      final nama = profile?['nama_lengkap'] ?? 'Peserta';
      final tanggal = table == 'izin'
          ? '${row['tanggal_mulai']} s/d ${row['tanggal_selesai']}'
          : '${row['tanggal']}';
      result.add(
        RequestNotification(
          id: row['id'].toString(),
          table: table,
          status: status.toString(),
          title: isAdmin
              ? '$nama mengajukan $jenis'
              : 'Pengajuan $jenis $status',
          message: isAdmin
              ? '$tanggal. Menunggu persetujuan Anda.'
              : '$tanggal. Pengajuan Anda telah $status oleh admin.',
          createdAt: DateTime.parse(
            (!isAdmin && row['diproses_at'] != null
                    ? row['diproses_at']
                    : row['created_at'])
                .toString(),
          ),
        ),
      );
    }
  });
  result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return result;
}

abstract interface class RequestNotificationsSource {
  Future<List<RequestNotification>> load(String userId, bool isAdmin);
}

class RequestNotificationsRepository implements RequestNotificationsSource {
  final SupabaseClient client;
  const RequestNotificationsRepository(this.client);

  @override
  Future<List<RequestNotification>> load(String userId, bool isAdmin) async {
    Future<List<Map<String, dynamic>>> fetch(String table) async {
      final rows = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        var query = client
            .from(table)
            .select(
              isAdmin ? '*, profiles!${table}_user_id_fkey(nama_lengkap)' : '*',
            );
        query = isAdmin
            ? query.eq('status_persetujuan', 'menunggu')
            : query.eq('user_id', userId).inFilter('status_persetujuan', [
                'disetujui',
                'ditolak',
              ]);
        final page = await query
            .order('created_at', ascending: false)
            .order('id')
            .range(offset, offset + 499);
        rows.addAll(page);
        if (page.length < 500) return rows;
        offset += page.length;
      }
    }

    Future<List<Map<String, dynamic>>> fetchCancellation() async {
      try {
        return await fetch('pembatalan_pulang');
      } on PostgrestException catch (e) {
        // Keep existing notifications usable while the new migration is pending.
        if (e.code == '42P01' || e.code == 'PGRST205') return [];
        rethrow;
      }
    }

    final data = await Future.wait([
      fetch('izin'),
      fetch('absen_susulan'),
      fetchCancellation(),
    ]);
    return buildRequestNotifications(
      userId: userId,
      isAdmin: isAdmin,
      records: {
        'izin': data[0],
        'absen_susulan': data[1],
        'pembatalan_pulang': data[2],
      },
    );
  }
}
