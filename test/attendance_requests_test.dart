import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/app_data.dart';
import 'package:presensi_bps_batu/services/attendance_requests.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AttendanceRequestsRepository repository;
  late Map<String, List<Map<String, dynamic>>> records;
  late List<Uri> queries;
  bool fail = false;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    records = {'history': [], 'izin': [], 'susulan': []};
    queries = [];
    fail = false;
    final api = ApiClient(
      'http://localhost:5010',
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'access_token': 'test-token',
              'user': {'id': 'user-a'},
            }),
            200,
          );
        }
        expect(request.headers['Authorization'], 'Bearer test-token');
        queries.add(request.url);
        if (fail) {
          return http.Response(
            jsonEncode({'error': 'Database unavailable'}),
            503,
          );
        }
        final kind = request.url.pathSegments.last;
        return http.Response(
          jsonEncode({
            kind == 'history' ? 'attendance' : 'requests': records[kind],
          }),
          200,
        );
      }),
    );
    await api.login('test@example.com', 'password');
    repository = AttendanceRequestsRepository(data: AppData(client: api));
  });
  test(
    'Recorded attendance prevents any request before checking pending requests',
    () async {
      records['history'] = [
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
      // Identity is derived from the bearer session, never a query parameter.
      expect(queries.single.queryParameters.containsKey('user_id'), false);
    },
  );
  test(
    'Date range is sent to scoped history and overlap is inclusive',
    () async {
      records['izin'] = [
        {
          'tanggal_mulai': '2026-09-29',
          'tanggal_selesai': '2026-10-01',
          'status_persetujuan': 'disetujui',
        },
      ];
      await expectLater(
        repository.ensureCanRequest('user-a', '2026-10-01', '2026-10-09'),
        throwsA(isA<AttendanceRequestConflict>()),
      );
      expect(queries.first.queryParameters['from'], '2026-10-01');
      expect(queries.first.queryParameters['to'], '2026-10-09');
    },
  );
  for (final kind in ['izin', 'susulan']) {
    test('Active $kind prevents overlapping requests of either kind', () async {
      records[kind] = [
        {
          'tanggal': '2026-10-07',
          'tanggal_mulai': '2026-10-07',
          'tanggal_selesai': '2026-10-08',
          'status_persetujuan': 'menunggu',
        },
      ];
      await expectLater(
        repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07'),
        throwsA(isA<AttendanceRequestConflict>()),
      );
    });
  }
  test(
    'Rejected requests and dates outside the range do not block a new request',
    () async {
      records['izin'] = [
        {
          'tanggal_mulai': '2026-10-07',
          'tanggal_selesai': '2026-10-07',
          'status_persetujuan': 'ditolak',
        },
        {
          'tanggal_mulai': '2026-10-08',
          'tanggal_selesai': '2026-10-08',
          'status_persetujuan': 'menunggu',
        },
      ];
      await repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07');
    },
  );
  test('A database failure does not authorize a request', () async {
    fail = true;
    await expectLater(
      repository.ensureCanRequest('user-a', '2026-10-07', '2026-10-07'),
      throwsA(isA<ApiException>()),
    );
  });
}
