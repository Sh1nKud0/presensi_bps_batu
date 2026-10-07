import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:presensi_bps_batu/services/attendance_requests.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late AttendanceRequestsRepository repository;
  late Map<String, List<Map<String, dynamic>>> records;
  late List<Uri> queries;
  bool fail = false;

  setUp(() async {
    records = {'absensi': [], 'izin': [], 'absen_susulan': []};
    queries = [];
    fail = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      queries.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (fail) {
        request.response.statusCode = 500;
        request.response.write(jsonEncode({'message': 'Database unavailable'}));
      } else {
        request.response.write(
          jsonEncode(records[request.uri.pathSegments.last]),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    repository = AttendanceRequestsRepository(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'Recorded attendance prevents any request before checking pending requests',
    () async {
      records['absensi'] = [
        {'tanggal': '2026-10-07'},
      ];
      await expectLater(
        repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07'),
        throwsA(
          isA<AttendanceRequestConflict>().having(
            (e) => e.message,
            'message',
            contains('7/10/2026'),
          ),
        ),
      );
      expect(queries.length, 1);
      expect(queries.single.queryParameters['user_id'], 'eq.user-a');
    },
  );

  test('Leave date range checks all dates including both endpoints', () async {
    await repository.ensureCanRequest('user-a', '2026-10-01', '2026-10-09');
    final attendance = queries.singleWhere(
      (uri) => uri.path.endsWith('/absensi'),
    );
    expect(attendance.queryParametersAll['tanggal'], [
      'gte.2026-10-01',
      'lte.2026-10-09',
    ]);
    final leave = queries.singleWhere((uri) => uri.path.endsWith('/izin'));
    expect(leave.queryParameters['tanggal_mulai'], 'lte.2026-10-09');
    expect(leave.queryParameters['tanggal_selesai'], 'gte.2026-10-01');
    final correction = queries.singleWhere(
      (uri) => uri.path.endsWith('/absen_susulan'),
    );
    expect(correction.queryParametersAll['tanggal'], [
      'gte.2026-10-01',
      'lte.2026-10-09',
    ]);
    for (final request in [leave, correction]) {
      final statuses = request.queryParameters['status_persetujuan']!;
      expect(statuses, contains('menunggu'));
      expect(statuses, contains('disetujui'));
      expect(statuses, isNot(contains('ditolak')));
      expect(request.queryParameters['user_id'], 'eq.user-a');
    }
  });

  for (final table in ['izin', 'absen_susulan']) {
    test(
      'Active $table prevents overlapping requests of either kind',
      () async {
        records[table] = [
          {'id': 'existing'},
        ];
        await expectLater(
          repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07'),
          throwsA(isA<AttendanceRequestConflict>()),
        );
      },
    );
  }

  test('Approval cannot overwrite attendance even when pending requests are excluded', () async {
    records['absensi'] = [
      {'tanggal': '2026-10-07'},
    ];
    await expectLater(
      repository.ensureNoAttendance('user-a', '2026-10-07', '2026-10-07'),
      throwsA(isA<AttendanceRequestConflict>()),
    );
  });

  test('A database failure does not authorize a request', () async {
    fail = true;
    await expectLater(
      repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
