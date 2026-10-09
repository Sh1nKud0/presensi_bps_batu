import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/app_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const origin = 'http://127.0.0.1:5010';
  const token = 'test-session-token';
  const user = {
    'id': 'participant',
    'role': 'peserta',
    'nama_lengkap': 'Peserta',
  };
  const storage = FlutterSecureStorage();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  http.Response json(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('login retains exact password, stores session securely, restores profile, and revokes on logout', () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      if (request.url.path.endsWith('/login')) {
        expect(request.headers.containsKey('Authorization'), false);
        expect(jsonDecode(request.body)['password'], ' password with spaces ');
        return json({'access_token': token, 'user': user});
      }
      expect(request.headers['Authorization'], 'Bearer $token');
      return json(
        request.url.path == '/api/me' ? {'user': user} : {'message': 'ok'},
      );
    });
    final api = ApiClient(origin, transport: client);
    await api.login(' test@example.com ', ' password with spaces ');
    expect(api.user, user);
    expect(await storage.read(key: 'presensi_api_session_$origin'), token);
    final restored = ApiClient(origin, transport: client);
    await restored.restore();
    expect(restored.user, user);
    await restored.logout();
    expect(restored.user, isNull);
    expect(await storage.read(key: 'presensi_api_session_$origin'), isNull);
    expect(calls.map((r) => r.url.path), [
      '/api/auth/login',
      '/api/me',
      '/api/auth/logout',
    ]);
  });

  test('401 removes stale session and signals UI; 409 preserves session and is never retried', () async {
    var status = 200;
    var mutations = 0;
    final api = ApiClient(
      origin,
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return json({'access_token': token, 'user': user});
        }
        mutations++;
        return json({
          'error': status == 409
              ? 'Presensi sudah tercatat.'
              : 'Sesi berakhir.',
        }, status);
      }),
    );
    await api.login('test@example.com', 'password');
    status = 409;
    await expectLater(
      api.json('POST', '/api/attendance/check-in', body: {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Presensi sudah tercatat.',
        ),
      ),
    );
    expect(mutations, 1);
    expect(api.user, user);
    var changes = 0;
    api.addListener(() => changes++);
    status = 401;
    await expectLater(api.json('GET', '/api/me'), throwsA(isA<ApiException>()));
    expect(api.user, isNull);
    expect(changes, 1);
    expect(await storage.read(key: 'presensi_api_session_$origin'), isNull);
  });

  test(
    'server outage does not destroy stored session during startup',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'presensi_api_session_$origin': token,
      });
      final api = ApiClient(
        origin,
        transport: MockClient((_) async => json({'error': 'Belum siap'}, 503)),
      );
      await expectLater(api.restore(), throwsA(isA<ApiException>()));
      expect(await storage.read(key: 'presensi_api_session_$origin'), token);
    },
  );

  test('API session is isolated per origin; requests cannot leak token to another host or redirect', () async {
    FlutterSecureStorage.setMockInitialValues({
      'presensi_api_session_$origin': token,
    });
    var calls = 0;
    final api = ApiClient(
      'http://localhost:5010',
      transport: MockClient((_) async {
        calls++;
        return json({});
      }),
    );
    await api.restore();
    expect(calls, 0);
    await api.login('test@example.com', 'password').catchError((_) {});
    final authenticated = ApiClient(
      origin,
      transport: MockClient((r) async {
        expect(r.followRedirects, false);
        if (r.url.path.endsWith('/login')) {
          return json({'access_token': token, 'user': user});
        }
        return http.Response(
          '',
          302,
          headers: {'location': 'https://other.example/api/me'},
        );
      }),
    );
    await authenticated.login('test@example.com', 'password');
    await expectLater(
      authenticated.json('GET', 'https://other.example/api/me'),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      authenticated.json('GET', '/api/me'),
      throwsA(isA<ApiException>()),
    );
  });

  test('pagination loads all rows and preserves query filters', () async {
    final api = ApiClient(
      origin,
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return json({'access_token': token, 'user': user});
        }
        expect(request.url.queryParameters['status'], 'menunggu');
        final offset = int.parse(request.url.queryParameters['offset']!);
        return json({
          'requests': List.generate(
            offset == 0 ? 100 : 1,
            (i) => {'id': '${offset + i}'},
          ),
        });
      }),
    );
    await api.login('test@example.com', 'password');
    expect(
      (await api.all(
        '/api/requests/izin',
        'requests',
        query: {'status': 'menunggu'},
      )).length,
      101,
    );
  });

  test('evidence upload uses raw MIME bytes and private ID; decision never writes attendance from mobile', () async {
    final calls = <http.Request>[];
    final api = ApiClient(
      origin,
      transport: MockClient((request) async {
        calls.add(request);
        if (request.url.path.endsWith('/login')) {
          return json({'access_token': token, 'user': user});
        }
        if (request.url.path == '/api/files') {
          expect(request.headers['content-type'], 'image/png');
          expect(request.bodyBytes.first, 137);
          return json({
            'file': {'id': 'proof-id'},
          }, 201);
        }
        if (request.url.path == '/api/requests/izin') {
          final body = jsonDecode(request.body) as Map;
          expect(body['bukti_id'], 'proof-id');
          expect(body.containsKey('user_id'), false);
          expect(body.containsKey('status_persetujuan'), false);
        }
        return json({
          'request': {'id': 'request-id'},
        });
      }),
    );
    await api.login('test@example.com', 'password');
    final data = AppData(client: api);
    final directory = await Directory.systemTemp.createTemp(
      'presensi-api-test-',
    );
    final file = File('${directory.path}/proof.png');
    try {
      await file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNXkAAAAASUVORK5CYII=',
        ),
      );
      await data.submitRequest('izin', {
        'tanggal_mulai': '2026-10-08',
        'tanggal_selesai': '2026-10-08',
        'jenis': 'izin',
      }, file);
      await data.decide(
        'susulan',
        'request-id',
        false,
        reason: 'Bukti tidak sesuai',
      );
      expect(
        calls.last.url.path,
        '/api/admin/requests/susulan/request-id/decision',
      );
      expect(jsonDecode(calls.last.body), {
        'setujui': false,
        'alasan_penolakan': 'Bukti tidak sesuai',
      });
      expect(calls.any((r) => r.url.path.contains('/attendance/')), false);
      expect(
        data.decorate([
          {'bukti_id': 'proof-id', 'nama_lengkap': 'Peserta'},
        ]).single['bukti_url'],
        'private:proof-id',
      );
    } finally {
      await file.delete();
      await directory.delete();
    }
  });

  test(
    'invalid server URL and malformed response are reported clearly',
    () async {
      for (final url in [
        'file:///tmp',
        '$origin/api',
        'http://name:pass@localhost',
        '$origin?secret=yes',
      ]) {
        expect(() => ApiClient(url), throwsA(isA<ApiException>()));
      }
      final api = ApiClient(
        origin,
        transport: MockClient(
          (_) async => http.Response('<html>proxy error</html>', 200),
        ),
      );
      await expectLater(
        api.json('POST', '/api/auth/login', authenticated: false),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
