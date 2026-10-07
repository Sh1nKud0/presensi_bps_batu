import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:presensi_bps_batu/services/checkout_cancellation.dart';

void main() {
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

  group('Cancellation requests use transactional database RPCs', () {
    late HttpServer server;
    late SupabaseClient client;
    late CheckoutCancellationRepository repository;
    late List<(String, Map<String, dynamic>)> calls;
    bool fail = false;
    setUp(() async {
      calls = [];
      fail = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        calls.add((request.uri.path, body));
        request.response.headers.contentType = ContentType.json;
        if (fail) {
          request.response.statusCode = 400;
          request.response.write(
            jsonEncode({'message': 'Pengajuan sudah diproses.'}),
          );
        } else {
          request.response.write('null');
        }
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      repository = CheckoutCancellationRepository(client);
    });
    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    test('Submission sends attendance ID and reason, never clears attendance directly', () async {
      await repository.submit(
        'attendance-1',
        '  Tidak sengaja menekan tombol  ',
      );
      expect(calls.single.$1, '/rest/v1/rpc/ajukan_pembatalan_pulang');
      expect(calls.single.$2, {
        'p_absensi_id': 'attendance-1',
        'p_alasan': 'Tidak sengaja menekan tombol',
      });
    });
    test(
      'Approve and reject send distinct decisions to the same atomic RPC',
      () async {
        await repository.process('request-1', true);
        await repository.process('request-2', false);
        expect(
          calls.map((c) => c.$1),
          everyElement('/rest/v1/rpc/proses_pembatalan_pulang'),
        );
        expect(calls.first.$2, {
          'p_request_id': 'request-1',
          'p_setujui': true,
        });
        expect(calls.last.$2, {
          'p_request_id': 'request-2',
          'p_setujui': false,
        });
      },
    );
    test(
      'Rejected RPC decisions propagate instead of reporting success',
      () async {
        fail = true;
        await expectLater(
          repository.process('request-1', true),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  });
}
