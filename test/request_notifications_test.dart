import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:presensi_bps_batu/services/request_notifications.dart';
import 'package:presensi_bps_batu/widgets/request_notifications_button.dart';

Map<String, dynamic> row(String id, String user, String status) => {
  'id': id,
  'user_id': user,
  'status_persetujuan': status,
  'jenis': 'izin',
  'tanggal_mulai': '2026-10-07',
  'tanggal_selesai': '2026-10-09',
  'tanggal': '2026-10-07',
  'created_at': '2026-10-07T01:00:00Z',
  'profiles': {'nama_lengkap': 'Peserta $user'},
};

class _FakeRepository implements RequestNotificationsSource {
  List<RequestNotification> items = [];
  @override
  Future<List<RequestNotification>> load(String userId, bool isAdmin) async =>
      items;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Admin only sees pending requests with participant name and date range',
    () {
      final items = buildRequestNotifications(
        userId: 'admin',
        isAdmin: true,
        records: {
          'izin': [
            row('1', 'a', 'menunggu'),
            row('2', 'b', 'disetujui'),
            row('3', 'c', 'ditolak'),
          ],
          'absen_susulan': [row('4', 'a', 'menunggu')],
        },
      );
      expect(items.length, 2);
      expect(items.first.title, contains('Peserta a'));
      expect(items.first.message, contains('2026-10-07 s/d 2026-10-09'));
      expect(items.last.table, 'absen_susulan');
    },
  );

  test('Participants only see their own approved and rejected requests', () {
    final items = buildRequestNotifications(
      userId: 'a',
      isAdmin: false,
      records: {
        'izin': [
          row('1', 'a', 'menunggu'),
          row('2', 'a', 'disetujui'),
          row('3', 'b', 'disetujui'),
        ],
        'absen_susulan': [row('4', 'a', 'ditolak')],
      },
    );
    expect(items.map((item) => item.id), ['2', '4']);
    expect(items.first.title, 'Pengajuan izin disetujui');
    expect(items.last.title, 'Pengajuan absen susulan ditolak');
  });

  test(
    'A changed status or different request table has its own unread identity',
    () {
      RequestNotification item(String table, String status) =>
          RequestNotification(
            id: '1',
            table: table,
            status: status,
            title: '',
            message: '',
            createdAt: DateTime.utc(2026),
          );
      expect(
        item('izin', 'menunggu').readKey,
        isNot(item('izin', 'disetujui').readKey),
      );
      expect(
        item('izin', 'disetujui').readKey,
        isNot(item('absen_susulan', 'disetujui').readKey),
      );
    },
  );

  test('Cancellation notifications reach admin and the owning participant with decision time', () {
    final pending = row('cancel-1', 'a', 'menunggu');
    final approved = {
      ...row('cancel-2', 'a', 'disetujui'),
      'diproses_at': '2026-10-08T01:00:00Z',
    };
    final records = {
      'pembatalan_pulang': [pending, approved, row('cancel-3', 'b', 'ditolak')],
    };
    final admin = buildRequestNotifications(
      userId: 'admin',
      isAdmin: true,
      records: records,
    );
    expect(admin.single.title, 'Peserta a mengajukan pembatalan absen pulang');
    final participant = buildRequestNotifications(
      userId: 'a',
      isAdmin: false,
      records: records,
    );
    expect(
      participant.single.title,
      'Pengajuan pembatalan absen pulang disetujui',
    );
    expect(
      participant.single.createdAt,
      DateTime.parse('2026-10-08T01:00:00Z'),
    );
  });

  test('Daily notification filter follows WIB at midnight and preserves all when unfiltered', () {
    RequestNotification item(String id, String time) => RequestNotification(
      id: id,
      table: 'izin',
      status: 'disetujui',
      title: id,
      message: id,
      createdAt: DateTime.parse(time),
    );
    final items = [
      item('before', '2026-10-06T16:59:59Z'),
      item('after', '2026-10-06T17:00:00Z'),
    ];
    expect(
      filterNotificationsByDay(items, DateTime(2026, 10, 7)).map((i) => i.id),
      ['after'],
    );
    expect(
      filterNotificationsByDay(items, DateTime(2026, 10, 6)).map((i) => i.id),
      ['before'],
    );
    expect(filterNotificationsByDay(items, null).length, 2);
  });

  testWidgets(
    'Date filter switches visible notifications and read-all only affects the visible date',
    (tester) async {
      final now = DateTime.now().toUtc();
      final repo = _FakeRepository();
      repo.items = [
        RequestNotification(
          id: 'today',
          table: 'izin',
          status: 'menunggu',
          title: 'Pengajuan hari ini',
          message: 'Hari ini',
          createdAt: now,
        ),
        RequestNotification(
          id: 'yesterday',
          table: 'izin',
          status: 'menunggu',
          title: 'Pengajuan kemarin',
          message: 'Kemarin',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestNotificationsButton(
              userId: 'admin',
              isAdmin: true,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hari ini'));
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan hari ini'), findsOneWidget);
      expect(find.text('Pengajuan kemarin'), findsNothing);
      await tester.tap(find.text('Tandai tanggal ini dibaca'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Kemarin'));
      await tester.pumpAndSettle();
      expect(find.text('Pengajuan kemarin'), findsOneWidget);
      expect(find.text('Pengajuan hari ini'), findsNothing);
      expect(find.text('Tandai tanggal ini dibaca'), findsOneWidget);
      Navigator.of(tester.element(find.text('Notifikasi'))).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifikasi: 1 belum dibaca'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Read state persists per account and an open list updates automatically',
    (tester) async {
      final repo = _FakeRepository();
      repo.items = buildRequestNotifications(
        userId: 'admin',
        isAdmin: true,
        records: {
          'izin': [row('1', 'a', 'menunggu')],
        },
      );
      Widget app(String user) => MaterialApp(
        home: Scaffold(
          body: RequestNotificationsButton(
            key: ValueKey(user),
            userId: user,
            isAdmin: true,
            repository: repo,
          ),
        ),
      );
      await tester.pumpWidget(app('admin'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifikasi: 1 belum dibaca'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Peserta a mengajukan izin'), findsOneWidget);
      await tester.tap(find.text('Tandai semua dibaca'));
      await tester.pumpAndSettle();
      expect(find.text('Tandai semua dibaca'), findsNothing);
      repo.items = buildRequestNotifications(
        userId: 'admin',
        isAdmin: true,
        records: {
          'izin': [row('1', 'a', 'menunggu'), row('2', 'b', 'menunggu')],
        },
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Peserta b mengajukan izin'), findsOneWidget);
      Navigator.of(tester.element(find.text('Notifikasi'))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app('admin'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifikasi: 1 belum dibaca'), findsOneWidget);
      await tester.pumpWidget(app('other-admin'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifikasi: 2 belum dibaca'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
