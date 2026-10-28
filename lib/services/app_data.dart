import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'api_client.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:5010',
);
final appData = AppData();

/// Gerbang data aplikasi yang seluruhnya dilayani backend PostgreSQL.
///
/// Halaman memakai layanan ini agar detail HTTP, bentuk endpoint, dan unggahan
/// bukti tetap terpusat dan konsisten.
class AppData {
  final ApiClient api;
  AppData({ApiClient? client}) : api = client ?? ApiClient(apiBaseUrl);
  String? get userId => api.user?['id'] as String?;
  bool get loggedIn => userId != null;

  Future<void> login(String email, String password) =>
      api.login(email, password);
  Future<void> register(String email, String password, String name) async {
    await api.json(
      'POST',
      '/api/auth/register',
      authenticated: false,
      body: {
        'email': email.trim(),
        'password': password,
        'nama_lengkap': name.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> profile() async {
    final user =
        (await api.json('GET', '/api/me'))['user'] as Map<String, dynamic>;
    api.user = user;
    return user;
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    api.user =
        (await api.json('PATCH', '/api/me', body: data))['user']
            as Map<String, dynamic>;
  }

  Future<void> logout() => api.logout();
  Future<void> changePassword(String? oldPassword, String newPassword) async {
    await api.json(
      'POST',
      '/api/auth/password',
      body: {'current_password': ?oldPassword, 'new_password': newPassword},
    );
    await api.clearSession();
  }

  Future<List<Map<String, dynamic>>> history(String start, String end) =>
      api.all(
        '/api/attendance/history',
        'attendance',
        query: {'from': start, 'to': end},
      );

  List<Map<String, dynamic>> decorate(List<Map<String, dynamic>> rows) => rows
      .map(
        (row) => {
          ...row,
          if (row['nama_lengkap'] != null)
            'profiles': {'nama_lengkap': row['nama_lengkap']},
          if (row['bukti_id'] != null)
            'bukti_url': 'private:${row['bukti_id']}',
        },
      )
      .toList();
  Future<List<Map<String, dynamic>>> requests(
    String kind, {
    bool admin = false,
    String? status,
  }) async {
    final path = '/api/${admin ? 'admin/' : ''}requests/$kind';
    if (!admin || status != null) {
      return decorate(
        await api.all(path, 'requests', query: {'status': ?status}),
      );
    }
    // Endpoint admin tanpa filter hanya mengembalikan pengajuan menunggu.
    final pages = await Future.wait([
      for (final value in ['menunggu', 'disetujui', 'ditolak'])
        api.all(path, 'requests', query: {'status': value}),
    ]);
    final records = <String, Map<String, dynamic>>{};
    for (final page in pages) {
      for (final row in page) {
        records[row['id'] as String] = row;
      }
    }
    return decorate(records.values.toList());
  }

  Future<void> submitRequest(
    String kind,
    Map<String, dynamic> data,
    File? evidence,
  ) async {
    final proof = evidence == null ? null : await upload(evidence);
    await api.json(
      'POST',
      '/api/requests/$kind',
      body: {...data, 'bukti_id': ?proof},
    );
  }

  Future<String> upload(File file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const ApiException('Ukuran bukti maksimal 5 MB.');
    }
    final bytes = await file.readAsBytes();
    final mime = bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'image/jpeg'
        : bytes.length >= 8 && bytes[0] == 137 && bytes[1] == 80
        ? 'image/png'
        : bytes.length >= 12 &&
              String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
              String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP'
        ? 'image/webp'
        : null;
    if (mime == null) {
      throw const ApiException('Bukti harus berupa JPEG, PNG, atau WebP.');
    }
    final result = await api.request(
      'POST',
      '/api/files',
      bytes: bytes,
      contentType: mime,
    );
    // Reuse JSON decoding without a second upload.
    return (jsonDecode(result.body)['file']['id']) as String;
  }

  Future<Uint8List> evidenceBytes(String reference) async => (await api.request(
    'GET',
    '/api/files/${reference.substring(8)}',
  )).bodyBytes;
  Future<void> decide(
    String kind,
    String id,
    bool approve, {
    String? reason,
  }) async {
    await api.json(
      'POST',
      '/api/admin/requests/$kind/$id/decision',
      body: {'setujui': approve, if (!approve) 'alasan_penolakan': reason},
    );
  }

  Future<List<Map<String, dynamic>>> holidays({String? start, String? end}) =>
      api.all('/api/holidays', 'holidays', query: {'from': ?start, 'to': ?end});
  Future<void> addHoliday(String day, String description) async {
    await api.json(
      'POST',
      '/api/admin/holidays',
      body: {'tanggal': day, 'keterangan': description},
    );
  }

  Future<void> removeHoliday(String id) async {
    await api.json('DELETE', '/api/admin/holidays/$id');
  }
}
