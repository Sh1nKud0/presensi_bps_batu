import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:presensi_bps_batu/services/api_client.dart';
import 'package:presensi_bps_batu/services/google_auth.dart';
import 'package:presensi_bps_batu/widgets/google_sign_in_button.dart';
import 'package:presensi_bps_batu/theme/app_theme.dart';

class FakeIdentity implements GoogleIdentitySource {
  String? token = 'google-id-token-for-test';
  final nonces = <String>[];
  @override
  Future<String?> authenticate({
    required String nonce,
    required String serverClientId,
  }) async {
    expect(serverClientId, googleServerClientId);
    nonces.add(nonce);
    return token;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nonce = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const origin = 'http://localhost:5010';
  const user = {
    'id': 'shared-web-user',
    'email': 'test@example.test',
    'role': 'peserta',
    'has_password': false,
  };
  http.Response json(Object body, [int code = 200]) =>
      http.Response(jsonEncode(body), code);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Google session preserves shared user ID and only persists the presensi session', () async {
    final identity = FakeIdentity();
    final api = ApiClient(
      origin,
      transport: MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/google/config':
            return json({'enabled': true});
          case '/api/auth/google/challenge':
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {});
            return json({'nonce': nonce});
          case '/api/auth/google':
            expect(request.headers['Authorization'], isNull);
            expect(jsonDecode(request.body), {
              'credential': identity.token,
              'nonce': nonce,
            });
            return json({'access_token': 'presensi-session', 'user': user});
          case '/api/me':
            expect(request.headers['Authorization'], 'Bearer presensi-session');
            return json({'user': user});
          default:
            throw StateError('Unexpected request');
        }
      }),
    );
    var notifications = 0;
    api.addListener(() => notifications++);
    final service = GoogleAuthService(api, identity: identity);
    expect(
      await service.signIn(
        confirmPassword: (_) async => fail('No linking required'),
      ),
      true,
    );
    expect(api.user?['id'], 'shared-web-user');
    expect(notifications, 1);
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.values, ['presensi-session']);
    expect(identity.nonces, [nonce]);
    await api.restore();
    expect(api.user?['id'], 'shared-web-user');
    api.dispose();
  });

  test('Existing account requires password confirmation; wrong password never creates a session', () async {
    final identity = FakeIdentity();
    final attempts = <Map<String, dynamic>>[];
    final api = ApiClient(
      origin,
      transport: MockClient((r) async {
        if (r.url.path.endsWith('/config')) return json({'enabled': true});
        if (r.url.path.endsWith('/challenge')) return json({'nonce': nonce});
        final input = jsonDecode(r.body) as Map<String, dynamic>;
        attempts.add(input);
        if (input['existing_password'] == null) {
          return json({
            'error': 'Confirm account',
            'code': 'google_link_required',
          }, 409);
        }
        if (input['existing_password'] != '  correct-password  ') {
          return json({
            'error': 'Incorrect password',
            'code': 'google_password_incorrect',
          }, 401);
        }
        return json({
          'access_token': 'linked-session',
          'user': {...user, 'role': 'admin'},
        });
      }),
    );
    final prompts = <String?>[];
    final result = await GoogleAuthService(api, identity: identity).signIn(
      confirmPassword: (error) async {
        expect(api.user, isNull);
        prompts.add(error);
        return prompts.length == 1 ? 'wrong' : '  correct-password  ';
      },
    );
    expect(result, true);
    expect(prompts.length, 2);
    expect(prompts[1], isNotNull);
    expect(identity.nonces.length, 1);
    expect(
      attempts.every(
        (input) =>
            input['nonce'] == nonce &&
            !input.containsKey('email') &&
            !input.containsKey('role'),
      ),
      true,
    );
    expect(api.user?['id'], user['id']);
    expect(api.user?['role'], 'admin');
    api.dispose();
  });

  test('Canceling account linking leaves the existing account and session unchanged', () async {
    final identity = FakeIdentity();
    var submits = 0;
    final api = ApiClient(
      origin,
      transport: MockClient((r) async {
        if (r.url.path.endsWith('/config')) return json({'enabled': true});
        if (r.url.path.endsWith('/challenge')) return json({'nonce': nonce});
        submits++;
        return json({
          'error': 'Confirm password',
          'code': 'google_link_required',
        }, 409);
      }),
    );
    expect(
      await GoogleAuthService(
        api,
        identity: identity,
      ).signIn(confirmPassword: (_) async => null),
      false,
    );
    expect(submits, 1);
    expect(api.user, isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    api.dispose();
  });

  test('Canceled selection never submits an ID token; each retry obtains a fresh nonce', () async {
    final identity = FakeIdentity()..token = null;
    var challenges = 0;
    final api = ApiClient(
      origin,
      transport: MockClient((r) async {
        if (r.url.path.endsWith('/config')) return json({'enabled': true});
        if (r.url.path.endsWith('/challenge')) {
          return json({'nonce': (++challenges == 1 ? 'a' : 'b') * 43});
        }
        fail('Canceled selection must not submit token');
      }),
    );
    final service = GoogleAuthService(api, identity: identity);
    for (var i = 0; i < 2; i++) {
      expect(await service.signIn(confirmPassword: (_) async => null), false);
    }
    expect(identity.nonces.toSet().length, 2);
    api.dispose();
  });

  test('Hosting without Google endpoint fails before account picker or challenge mutation', () async {
    final identity = FakeIdentity();
    final api = ApiClient(
      origin,
      transport: MockClient((r) async {
        expect(r.url.path, '/api/auth/google/config');
        expect(r.method, 'GET');
        return json({'error': 'Endpoint not found'}, 404);
      }),
    );
    await expectLater(
      GoogleAuthService(
        api,
        identity: identity,
      ).signIn(confirmPassword: (_) async => null),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('belum tersedia'),
        ),
      ),
    );
    expect(identity.nonces, isEmpty);
    api.dispose();
  });

  test(
    'Invalid credentials and expired challenge are not retried or stored',
    () async {
      final identity = FakeIdentity();
      var submits = 0;
      final api = ApiClient(
        origin,
        transport: MockClient((r) async {
          if (r.url.path.endsWith('/config')) return json({'enabled': true});
          if (r.url.path.endsWith('/challenge')) return json({'nonce': nonce});
          submits++;
          return json({
            'error': 'Expired',
            'code': 'google_challenge_expired',
          }, 401);
        }),
      );
      await expectLater(
        GoogleAuthService(
          api,
          identity: identity,
        ).signIn(confirmPassword: (_) async => fail('Do not link')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'google_challenge_expired',
          ),
        ),
      );
      expect(submits, 1);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      api.dispose();
    },
  );

  test(
    'Android bridge passes a per-attempt nonce and sanitizes platform errors',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(AndroidGoogleIdentity.channel, (
        call,
      ) async {
        calls.add(call);
        if (calls.length == 1) return 'id-token-test';
        throw PlatformException(
          code: 'google_canceled',
          message: 'Do not expose native details',
        );
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          AndroidGoogleIdentity.channel,
          null,
        ),
      );
      final source = AndroidGoogleIdentity();
      expect(
        await source.authenticate(
          nonce: nonce,
          serverClientId: googleServerClientId,
        ),
        'id-token-test',
      );
      expect(
        await source.authenticate(
          nonce: 'b' * 43,
          serverClientId: googleServerClientId,
        ),
        isNull,
      );
      expect(calls[0].arguments['nonce'], nonce);
      expect(calls[1].arguments['nonce'], 'b' * 43);
    },
  );

  testWidgets(
    'Link confirmation is explicit, cancelable, and readable on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final identity = FakeIdentity();
      final api = ApiClient(
        origin,
        transport: MockClient((r) async {
          if (r.url.path.endsWith('/config')) return json({'enabled': true});
          if (r.url.path.endsWith('/challenge')) return json({'nonce': nonce});
          return json({
            'error': 'Confirm',
            'code': 'google_link_required',
          }, 409);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: GoogleSignInButton(
                service: GoogleAuthService(api, identity: identity),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lanjutkan dengan Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Hubungkan akun presensi'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(api.user, isNull);
      api.dispose();
    },
  );
}
