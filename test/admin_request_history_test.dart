import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/app_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/services/admin_daily_attendance.dart';
import 'package:presensi_bps_batu/services/admin_request_history.dart';
import 'package:presensi_bps_batu/widgets/admin_daily_attendance_list.dart';
import 'package:presensi_bps_batu/widgets/admin_request_history_tab.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';

AdminRequestHistoryItem entry(
  String kind,
  String status,
  String name, {
  String start = '2026-10-26',
  String end = '2026-10-28',
}) => AdminRequestHistoryItem(kind, {
  'id': '$kind-$status',
  'nama_lengkap': name,
  'status_persetujuan': status,
  'tanggal_mulai': start,
  'tanggal_selesai': end,
  'created_at': '2026-10-25T17:30:00Z',
  'diproses_at': status == 'menunggu' ? null : '2026-10-26T01:45:00Z',
  if (status == 'ditolak') 'alasan_penolakan': 'Tanggal perlu diperbaiki',
});

class FakeHistory implements AdminRequestHistorySource {
  List<AdminRequestHistoryItem> items = [];
  int loads = 0;
  @override
  Future<List<AdminRequestHistoryItem>> load() async {
    loads++;
    return items;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('History contains approved and rejected database records even when no pending requests exist', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient(
      'http://localhost:5010',
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'token',
              'user': {'id': 'admin', 'role': 'admin'},
            }),
            200,
          );
        }
        final status = request.url.queryParameters['status'] ?? 'menunggu';
        final kind = request.url.path.endsWith('/izin') ? 'izin' : 'susulan';
        final rows = status == 'menunggu'
            ? []
            : [
                {
                  'id': '$kind-$status',
                  'jenis': 'izin',
                  'nama_lengkap': 'Peserta',
                  'tanggal_mulai': '2026-10-26',
                  'tanggal_selesai': '2026-10-26',
                  'tanggal': '2026-10-26',
                  'status_persetujuan': status,
                  'created_at': '2026-10-26T00:00:00Z',
                },
              ];
        return http.Response(jsonEncode({'requests': rows}), 200);
      }),
    );
    await api.login('admin@example.com', 'password');
    final items = await AdminRequestHistoryRepository(
      data: AppData(client: api),
    ).load();
    expect(items.length, 4);
    expect(items.where((item) => item.kind == 'izin').length, 2);
    expect(items.where((item) => item.kind == 'susulan').length, 2);
    expect(items.where((item) => item.status == 'menunggu'), isEmpty);
    api.dispose();
  });
  test('History retains decisions, searches names and matches overlapping requested dates', () {
    final items = [
      entry('izin', 'disetujui', 'Ayu'),
      entry('sakit', 'menunggu', 'Budi'),
      entry(
        'susulan',
        'ditolak',
        'Citra',
        start: '2026-10-19',
        end: '2026-10-19',
      ),
    ];
    expect(filterAdminRequestHistory(items).length, 3);
    expect(
      filterAdminRequestHistory(items, status: 'ditolak').single.name,
      'Citra',
    );
    expect(
      filterAdminRequestHistory(
        items,
        kind: 'sakit',
        name: ' BUD ',
      ).single.name,
      'Budi',
    );
    expect(
      filterAdminRequestHistory(
        items,
        from: '2026-10-28',
        to: '2026-10-28',
      ).length,
      2,
    );
    expect(filterAdminRequestHistory(items, from: '2026-10-29').isEmpty, true);
    expect(historyTime('2026-10-25T17:30:00Z'), '26/10/2026 00:30 WIB');
    expect(historyTime(null), 'Belum diproses');
  });

  testWidgets(
    'Today shows approved leave with minus, then updates after a decision',
    (tester) async {
      final participants = [
        {'id': 'leave', 'nama_lengkap': 'Ayu'},
      ];
      Widget page(AdminDailyStatus status) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AdminDailyAttendanceList(
            participants: participants,
            statuses: {'leave': status},
            day: '2026-10-26',
            onRefresh: () async {},
          ),
        ),
      );
      await tester.pumpWidget(
        page(
          const AdminDailyStatus(
            'Izin menunggu persetujuan',
            pending: true,
            kind: 'izin',
          ),
        ),
      );
      expect(find.text('Izin menunggu persetujuan'), findsOneWidget);
      await tester.pumpWidget(
        page(const AdminDailyStatus('Izin disetujui', kind: 'izin')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin disetujui'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Belum absen hari ini'), findsNothing);
      expect(find.text('Status tanggal 2026-10-26 (WIB)'), findsOneWidget);
    },
  );

  testWidgets(
    'History shows WIB timestamps and filters entries while refreshing from storage',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeHistory()
        ..items = [
          entry('izin', 'disetujui', 'Ayu'),
          entry('sakit', 'menunggu', 'Budi'),
        ];
      Widget page(int revision) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AdminRequestHistoryTab(repository: repo, revision: revision),
        ),
      );
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(find.text('Diajukan: 26/10/2026 00:30 WIB'), findsNWidgets(2));
      expect(find.text('Diproses: 26/10/2026 08:45 WIB'), findsOneWidget);
      expect(find.text('Diproses: Belum diproses'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sakit'));
      await tester.pumpAndSettle();
      expect(find.text('Ayu'), findsNothing);
      expect(find.text('Budi'), findsOneWidget);
      repo.items = [entry('sakit', 'disetujui', 'Budi')];
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('Diproses: Belum diproses'), findsNothing);
    },
  );

  testWidgets('History and status fit a narrow screen at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeHistory()
      ..items = [
        entry('susulan', 'ditolak', 'Peserta dengan nama yang sangat panjang'),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: AdminRequestHistoryTab(repository: repo)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
