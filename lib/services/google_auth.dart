import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '453707057025-ih5pkesie7ac2sg07ttupig284ecaatr.apps.googleusercontent.com',
);

abstract interface class GoogleIdentitySource {
  Future<String?> authenticate({
    required String nonce,
    required String serverClientId,
  });
}

class AndroidGoogleIdentity implements GoogleIdentitySource {
  static const channel = MethodChannel('presensi/google_identity');
  @override
  Future<String?> authenticate({
    required String nonce,
    required String serverClientId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const ApiException('Login Google tersedia pada aplikasi Android.');
    }
    try {
      return await channel.invokeMethod<String>('authenticate', {
        'nonce': nonce,
        'serverClientId': serverClientId,
      });
    } on PlatformException catch (error) {
      if (error.code == 'google_canceled') return null;
      throw ApiException(switch (error.code) {
        'google_no_credential' => 'Akun Google belum tersedia. Tambahkan akun Google pada HP dan periksa konfigurasi OAuth Android.',
        'google_configuration' => 'Login Google Android belum dikonfigurasi. Periksa package name, SHA-1, dan OAuth client Android.',
        'google_busy' => 'Pemilihan akun Google masih berlangsung.',
        _ => 'Google belum dapat dihubungi. Periksa koneksi dan Google Play Services, lalu coba lagi.',
      });
    } on MissingPluginException {
      throw const ApiException(
        'Jalankan ulang aplikasi Android setelah memasang pembaruan login Google.',
      );
    }
  }
}

class GoogleAuthService {
  final ApiClient api;
  final GoogleIdentitySource identity;
  final String serverClientId;
  bool _busy = false;
  GoogleAuthService(
    this.api, {
    GoogleIdentitySource? identity,
    this.serverClientId = googleServerClientId,
  }) : identity = identity ?? AndroidGoogleIdentity();

  Future<bool> signIn({
    required Future<String?> Function(String? error) confirmPassword,
  }) async {
    if (_busy) return false;
    _busy = true;
    try {
      Map<String, dynamic> config;
      try {
        config = await api.json(
          'GET',
          '/api/auth/google/config',
          authenticated: false,
        );
      } on ApiException catch (error) {
        if (error.status == 404 || error.status == 405 || error.status == 503) {
          throw const ApiException(
            'Login Google belum tersedia pada server ini. Gunakan email dan password untuk sementara.',
          );
        }
        rethrow;
      }
      if (config['enabled'] != true) {
        throw const ApiException(
          'Login Google belum diaktifkan pada server. Gunakan email dan password untuk sementara.',
        );
      }
      final challenge = await api.json(
        'POST',
        '/api/auth/google/challenge',
        body: {},
        authenticated: false,
      );
      final nonce = challenge['nonce'];
      if (nonce is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(nonce)) {
        throw const ApiException(
          'Server mengirim sesi Google yang tidak valid. Coba lagi nanti.',
        );
      }
      final credential = await identity.authenticate(
        nonce: nonce,
        serverClientId: serverClientId,
      );
      if (credential == null) return false;
      if (credential.isEmpty || credential.length > 12000) {
        throw const ApiException(
          'Google tidak mengembalikan identitas yang valid. Coba lagi.',
        );
      }
      String? existingPassword;
      while (true) {
        try {
          await api.loginGoogle(
            credential,
            nonce,
            existingPassword: existingPassword,
          );
          return true;
        } on ApiException catch (error) {
          if (![
            'google_link_required',
            'google_password_incorrect',
          ].contains(error.code)) {
            rethrow;
          }
          existingPassword = await confirmPassword(
            error.code == 'google_password_incorrect'
                ? 'Kata sandi presensi tidak sesuai. Akun belum dihubungkan.'
                : null,
          );
          if (existingPassword == null) return false;
        }
      }
    } finally {
      _busy = false;
    }
  }
}
