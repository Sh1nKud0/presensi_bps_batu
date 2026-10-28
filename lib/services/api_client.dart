import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  const ApiException(this.message, [this.status, this.code]);
  @override
  String toString() => message;
}

/// Tokens are scoped to the API origin and kept in platform secure storage.
class ApiClient extends ChangeNotifier {
  final Uri base;
  final http.Client transport;
  final FlutterSecureStorage storage;
  String? _token;
  Map<String, dynamic>? user;
  String get _key => 'presensi_api_session_${base.origin}';

  ApiClient(String url, {http.Client? transport, FlutterSecureStorage? storage})
    : base = Uri.parse(url),
      transport = transport ?? http.Client(),
      storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          ) {
    if (!base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const ApiException(
        'API_BASE_URL harus berupa alamat server tanpa path.',
      );
    }
    if (kReleaseMode && base.scheme != 'https') {
      throw const ApiException('Versi rilis memerlukan API HTTPS.');
    }
  }

  Future<void> restore() async {
    _token = await storage.read(key: _key);
    if (_token == null) return;
    try {
      user = (await json('GET', '/api/me'))['user'] as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.status != 401) rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final result = await json(
      'POST',
      '/api/auth/login',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    await _acceptSession(result);
  }

  Future<void> loginGoogle(
    String credential,
    String nonce, {
    String? existingPassword,
  }) async {
    final result = await json(
      'POST',
      '/api/auth/google',
      authenticated: false,
      body: {
        'credential': credential,
        'nonce': nonce,
        'existing_password': ?existingPassword,
      },
    );
    await _acceptSession(result);
  }

  Future<void> _acceptSession(Map<String, dynamic> result) async {
    final token = result['access_token'] as String;
    try {
      await storage.write(key: _key, value: token);
    } catch (_) {
      // Revoke a newly issued session if this device cannot retain it safely.
      await transport
          .post(
            base.resolve('/api/auth/logout'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      throw const ApiException(
        'Sesi tidak dapat disimpan. Coba login kembali.',
      );
    }
    _token = token;
    user = result['user'] as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    user = null;
    notifyListeners();
    await storage.delete(key: _key);
  }

  Future<void> logout() async {
    await json('POST', '/api/auth/logout');
    await clearSession();
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Uint8List? bytes,
    String? contentType,
    bool authenticated = true,
  }) async {
    if (authenticated && _token == null) {
      throw const ApiException('Silakan login kembali.', 401);
    }
    final uri = base.resolve(path).replace(queryParameters: query);
    // Never send a session to a URL supplied by a record or another server.
    if (uri.origin != base.origin || !path.startsWith('/api/')) {
      throw const ApiException('Alamat API tidak valid.');
    }
    final request = http.Request(method, uri);
    request.followRedirects = false;
    final requestToken = _token;
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer $requestToken';
    }
    if (bytes != null) {
      request.headers['Content-Type'] = contentType!;
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    late http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await transport.send(request),
      ))().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const ApiException(
        'Server belum merespons. Periksa status sebelum mengirim ulang.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat menghubungi server. Periksa koneksi dan alamat API.',
      );
    }
    if (response.statusCode >= 300) {
      if (response.statusCode == 401 &&
          authenticated &&
          _token == requestToken) {
        await clearSession();
      }
      String message = 'Permintaan gagal (${response.statusCode}).';
      String? code;
      try {
        final error = jsonDecode(response.body) as Map;
        message = error['error'] as String? ?? message;
        code = error['code'] is String ? error['code'] as String : null;
      } catch (_) {
        /* Proxy errors may not be JSON. */
      }
      throw ApiException(message, response.statusCode, code);
    }
    return response;
  }

  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await request(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
    );
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Format respons server tidak valid.');
    }
  }

  Future<List<Map<String, dynamic>>> all(
    String path,
    String key, {
    Map<String, String> query = const {},
  }) async {
    final result = <Map<String, dynamic>>[];
    while (true) {
      final data = await json(
        'GET',
        path,
        query: {...query, 'limit': '100', 'offset': '${result.length}'},
      );
      final page = List<Map<String, dynamic>>.from(data[key] as List);
      result.addAll(page);
      if (page.length < 100) return result;
    }
  }
}
