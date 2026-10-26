import 'rekap_presensi.dart';
import 'app_data.dart';

List<RequestNotification> newAdminRequests(
  List<RequestNotification> items,
  Set<String> read,
  Set<String> announced,
) => items
    .where(
      (item) =>
          item.status == 'menunggu' &&
          !read.contains(item.readKey) &&
          !announced.contains(item.readKey),
    )
    .toList();

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
  final String? notificationId;
  final bool read;

  const RequestNotification({
    required this.id,
    required this.table,
    required this.status,
    required this.title,
    required this.message,
    required this.createdAt,
    this.notificationId,
    this.read = false,
  });
  String get readKey => notificationId ?? '$table/$id/$status';
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
  final AppData data;
  RequestNotificationsRepository({AppData? data}) : data = data ?? appData;
  @override
  Future<List<RequestNotification>> load(String userId, bool isAdmin) async {
    final rows = await data.api.all('/api/notifications', 'notifications');
    return rows
        .map(
          (row) => RequestNotification(
            id: row['request_id'] as String,
            notificationId: row['id'] as String,
            table:
                {
                  'susulan': 'absen_susulan',
                  'pembatalan': 'pembatalan_pulang',
                }[row['jenis']] ??
                'izin',
            status: row['status'] as String,
            title: row['title'] as String,
            message: row['status'] == 'menunggu'
                ? 'Menunggu persetujuan admin.'
                : 'Pengajuan Anda telah ${row['status']} oleh admin.',
            createdAt: DateTime.parse(row['created_at'] as String),
            read: row['read_at'] != null,
          ),
        )
        .toList();
  }
}
