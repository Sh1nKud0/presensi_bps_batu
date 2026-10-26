import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presensi_bps_batu/services/admin_daily_attendance.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/app_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Leave status stored on attendance without clock times is shown as approved leave', () {
    final statuses = adminDailyStatuses(
      day: '2026-10-26',
      leave: [],
      supplementary: [],
      attendance: [
        {
          'user_id': 'izin',
          'tanggal': '2026-10-26',
          'status': 'izin',
          'jam_masuk': null,
        },
        {
          'user_id': 'sakit',
          'tanggal': '2026-10-26',
          'status': 'sakit',
          'jam_masuk': null,
        },
      ],
    );
    expect(statuses['izin']!.label, 'Izin disetujui');
    expect(statuses['sakit']!.label, 'Sakit disetujui');
    expect(statuses['sakit']!.attendance, isNull);
  });
  Map<String, dynamic> leave(
    String user,
    String status, {
    String kind = 'izin',
    String start = '2026-10-26',
    String end = '2026-10-28',
  }) => {
    'user_id': user,
    'jenis': kind,
    'status_persetujuan': status,
    'tanggal_mulai': start,
    'tanggal_selesai': end,
  };

  test('Approved and pending leave differ from absence, with inclusive date ranges', () {
    final result = adminDailyStatuses(
      day: '2026-10-26',
      attendance: [],
      supplementary: [],
      leave: [
        leave('approved', 'disetujui'),
        leave(
          'sick',
          'disetujui',
          kind: 'sakit',
          start: '2026-10-25',
          end: '2026-10-26',
        ),
        leave('pending', 'menunggu'),
        leave('pending-sick', 'menunggu', kind: 'sakit'),
        leave('rejected', 'ditolak'),
        leave('future', 'disetujui', start: '2026-10-27'),
        leave('past', 'disetujui', start: '2026-10-20', end: '2026-10-25'),
      ],
    );
    expect(result['approved']!.label, 'Izin disetujui');
    expect(result['sick']!.label, 'Sakit disetujui');
    expect(result['pending']!.label, 'Izin menunggu persetujuan');
    expect(result['pending-sick']!.pending, true);
    expect(result['approved']!.pending, false);
    expect(
      result.keys,
      unorderedEquals(['approved', 'sick', 'pending', 'pending-sick']),
    );
  });

  test('Real attendance takes precedence and only today pending supplementary is shown', () {
    final actual = {
      'user_id': 'actual',
      'tanggal': '2026-10-26',
      'jam_masuk': '2026-10-26T00:30:00Z',
    };
    final result = adminDailyStatuses(
      day: '2026-10-26',
      attendance: [actual],
      leave: [leave('actual', 'disetujui'), leave('actual', 'menunggu')],
      supplementary: [
        {
          'user_id': 'supplementary',
          'tanggal': '2026-10-26',
          'status_persetujuan': 'menunggu',
        },
        {
          'user_id': 'yesterday',
          'tanggal': '2026-10-25',
          'status_persetujuan': 'menunggu',
        },
      ],
    );
    expect(result['actual']!.attendance, same(actual));
    expect(result['actual']!.pending, false);
    expect(
      result['supplementary']!.label,
      'Absen susulan menunggu persetujuan',
    );
    expect(result.containsKey('yesterday'), false);
  });

  test('Repository uses server day and loads subsequent attendance pages for that day', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final requested = <Uri>[];
    final api = ApiClient(
      'http://localhost:5010',
      transport: MockClient((request) async {
        requested.add(request.url);
        Object body;
        switch (request.url.path) {
          case '/api/auth/login':
            body = {
              'access_token': 'test',
              'user': {'id': 'admin', 'role': 'admin'},
            };
          case '/api/admin/attendance':
            final offset = request.url.queryParameters['offset'];
            body = {
              'tanggal_server': '2026-10-26',
              'attendance': offset == '0'
                  ? List.generate(
                      100,
                      (i) => {
                        'user_id': 'user-$i',
                        'tanggal': '2026-10-26',
                        'jam_masuk': '2026-10-26T00:30:00Z',
                      },
                    )
                  : [
                      {
                        'user_id': 'last',
                        'tanggal': '2026-10-26',
                        'jam_masuk': '2026-10-26T00:30:00Z',
                      },
                    ],
            };
          case '/api/admin/participants':
            body = {'participants': []};
          case '/api/admin/requests/izin':
            expect(request.url.queryParameters['status'], isNotNull);
            body = {
              'requests': request.url.queryParameters['status'] == 'disetujui'
                  ? [
                      {
                        'id': 'approved-sick',
                        ...leave('sick', 'disetujui', kind: 'sakit'),
                      },
                    ]
                  : [],
            };
          case '/api/admin/requests/susulan':
            body = {'requests': []};
          default:
            throw StateError('Unexpected path ${request.url.path}');
        }
        return http.Response(jsonEncode(body), 200);
      }),
    );
    await api.login('admin@example.com', 'password');
    final overview = await AdminDailyAttendanceRepository(
      data: AppData(client: api),
    ).load();
    expect(overview.statuses.length, 102);
    expect(overview.statuses['sick']!.label, 'Sakit disetujui');
    final second = requested.firstWhere(
      (uri) => uri.queryParameters['offset'] == '100',
    );
    expect(second.queryParameters['from'], '2026-10-26');
    expect(second.queryParameters['to'], '2026-10-26');
    api.dispose();
  });
}
