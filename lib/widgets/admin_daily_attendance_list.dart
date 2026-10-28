import 'package:flutter/material.dart';

import '../services/admin_daily_attendance.dart';
import '../services/rekap_presensi.dart';
import '../theme/app_theme.dart';

class AdminDailyAttendanceList extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final Map<String, AdminDailyStatus> statuses;
  final String day;
  final Future<void> Function() onRefresh;
  const AdminDailyAttendanceList({
    super.key,
    required this.participants,
    required this.statuses,
    required this.day,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: participants.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Status tanggal $day (WIB)', style: AppText.bodyMd),
          );
        }
        final participant = participants[index - 1];
        final status = statuses[participant['id']];
        final pending = status?.pending ?? false;
        final leave = ['izin', 'sakit'].contains(status?.kind);
        final color = pending || leave
            ? context.appColors.izinText
            : status != null
            ? context.appColors.hadirText
            : context.appColors.onSurfaceVariant;
        final bg = pending || leave
            ? context.appColors.izinBg
            : status != null
            ? context.appColors.hadirBg
            : context.appColors.surfaceContainerHigh;
        final attendance = status?.attendance;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: bg,
              child: Icon(
                pending
                    ? Icons.pending_actions
                    : leave
                    ? Icons.remove
                    : status != null
                    ? Icons.check
                    : Icons.close,
                color: color,
              ),
            ),
            title: Text(participant['nama_lengkap'] ?? '-'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status?.label ?? 'Belum absen hari ini',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (attendance != null)
                  Text(
                    'Masuk: ${jamRekap(attendance['jam_masuk'])}  |  Pulang: ${jamRekap(attendance['jam_pulang'])}',
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
