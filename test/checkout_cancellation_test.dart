import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/app_data.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_bps_batu/services/checkout_cancellation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.parse('2026-10-07T07:00:00Z');
  Map<String, dynamic> attendance(String checkout) => {
    'id': 'attendance-1',
    'tanggal': '2026-10-07',
    'status': 'hadir',
    'jam_masuk': '2026-10-07T00:00:00Z',
    'jam_pulang': checkout,
  };

  test('Accidental checkout at noon WIB permits cancellation', () {
    expect(
      canCancelCheckout(attendance('2026-10-07T05:00:00Z'), now: today),
      isTrue,
    );
  });
  test('Cutoff is exactly 16:00 WIB regardless of device timezone', () {
    expect(
      canCancelCheckout(attendance('2026-10-07T08:59:59Z'), now: today),
      isTrue,
    );
    expect(
      canCancelCheckout(attendance('2026-10-07T09:00:00Z'), now: today),
      isFalse,
    );
    expect(
      canCancelCheckout(attendance('2026-10-07T10:00:00Z'), now: today),
      isFalse,
    );
    expect(
      canCancelCheckout(attendance('2026-10-07T16:00:00+07:00'), now: today),
      isFalse,
    );
  });
  test(
    'Previous day and inconsistent checkout dates cannot request cancellation',
    () {
      expect(
        canCancelCheckout(
          attendance('2026-10-07T05:00:00Z'),
          now: DateTime.parse('2026-10-07T17:00:00Z'),
        ),
        isFalse,
      );
      expect(
        canCancelCheckout(attendance('2026-10-06T05:00:00Z'), now: today),
        isFalse,
      );
    },
  );
  test('Only recorded normal attendance without another active request is eligible', () {
    expect(canCancelCheckout(null, now: today), isFalse);
    final row = attendance('2026-10-07T05:00:00Z');
    expect(canCancelCheckout(row, now: today, hasActiveRequest: true), isFalse);
    row['jam_pulang'] = null;
    expect(canCancelCheckout(row, now: today), isFalse);
    row['jam_pulang'] = 'not-a-date';
    expect(canCancelCheckout(row, now: today), isFalse);
    row['jam_pulang'] = '2026-10-07T05:00:00Z';
    row['status'] = 'izin';
    expect(canCancelCheckout(row, now: today), isFalse);
    row['status'] = 'hadir';
    row['jam_masuk'] = null;
    expect(canCancelCheckout(row, now: today), isFalse);
  });

  group('Cancellation requests use atomic backend decisions', () {
    late CheckoutCancellationRepository repository;
    late List<(String, Map<String, dynamic>)> calls;
    bool fail = false;
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      calls = [];
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
          calls.add((
            request.url.path,
            jsonDecode(request.body) as Map<String, dynamic>,
          ));
          return http.Response(
            jsonEncode(
              fail ? {'error': 'Pengajuan sudah diproses.'} : {'request': {}},
            ),
            fail ? 409 : 200,
          );
        }),
      );
      await api.login('test@example.com', 'password');
      repository = CheckoutCancellationRepository(data: AppData(client: api));
    });
    test('Submission sends attendance ID and reason, never clears attendance directly', () async {
      await repository.submit(
        'attendance-1',
        '  Tidak sengaja menekan tombol  ',
      );
      expect(calls.single.$1, '/api/requests/pembatalan');
      expect(calls.single.$2, {
        'absensi_id': 'attendance-1',
        'alasan': 'Tidak sengaja menekan tombol',
      });
    });
    test(
      'Approve and reject use server decisions with a rejection reason',
      () async {
        await repository.process('request-1', true);
        await repository.process('request-2', false);
        expect(
          calls.first.$1,
          '/api/admin/requests/pembatalan/request-1/decision',
        );
        expect(
          calls.last.$1,
          '/api/admin/requests/pembatalan/request-2/decision',
        );
        expect(calls.first.$2, {'setujui': true});
        expect(calls.last.$2['setujui'], false);
        expect(calls.last.$2['alasan_penolakan'], isNotEmpty);
      },
    );
    test(
      'Conflicting decisions propagate instead of reporting success',
      () async {
        fail = true;
        await expectLater(
          repository.process('request-1', true),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });
}
