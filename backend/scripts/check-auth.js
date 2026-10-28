import { readConfig } from '../src/config.js';
import { promptCredentials } from './prompt.js';
import { HttpError } from '../src/errors.js';

let token;
let origin;
async function request(path, { body, authorized = false, method = 'GET' } = {}) {
  const response = await fetch(`${origin}${path}`, {
    method,
    headers: { ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(authorized ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(15000),
  });
  return { status: response.status, body: await response.json() };
}
try {
  const config = readConfig();
  // Backend lokal. HOST 0.0.0.0 merupakan alamat bind, bukan alamat tujuan.
  const host = ['0.0.0.0', '::'].includes(config.host) ? '127.0.0.1' : config.host;
  origin = `http://${host.includes(':') ? `[${host}]` : host}:${config.port}`;
  const input = await promptCredentials();
  const login = await request('/api/auth/login', { method: 'POST', body: input });
  if (login.status !== 200) throw new HttpError(login.status, login.body.error);
  token = login.body.access_token;
  const me = await request('/api/me', { authorized: true });
  if (me.status !== 200) throw new HttpError(me.status, me.body.error);
  console.log(`Login dan profil berhasil. Role: ${me.body.user.role}`);
  if (me.body.user.role === 'admin') {
    const users = await request('/api/admin/users', { authorized: true });
    if (users.status !== 200) throw new HttpError(users.status, users.body.error);
    console.log('Pembatasan endpoint admin berhasil diperiksa.');
  }
  if (process.argv.includes('--attendance') || process.argv.includes('--workflow')) {
    for (const path of ['/api/attendance/today', '/api/attendance/history', '/api/requests/izin', '/api/requests/susulan',
      ...(me.body.user.role === 'admin' ? ['/api/admin/requests/izin', '/api/admin/requests/susulan'] : [])]) {
      const result = await request(path, { authorized: true });
      if (result.status !== 200) throw new HttpError(result.status, result.body.error);
    }
    console.log('API status presensi, riwayat, dan daftar pengajuan berhasil diperiksa.');
    console.log('Tidak ada presensi/pengajuan/keputusan yang dibuat oleh pemeriksaan ini.');
  }
  if (process.argv.includes('--workflow')) {
    for (const path of ['/api/requests/pembatalan', '/api/notifications', '/api/files', '/api/holidays',
      ...(me.body.user.role === 'admin' ? ['/api/admin/requests/pembatalan'] : [])]) {
      const result = await request(path, { authorized: true });
      if (result.status !== 200) throw new HttpError(result.status, result.body.error);
    }
    console.log('API pembatalan, notifikasi, daftar bukti privat, dan hari libur berhasil diperiksa.');
    if (me.body.user.role === 'admin') {
      const status = await request('/api/attendance/today', { authorized: true });
      if (status.status !== 200) throw new HttpError(status.status, status.body.error);
      const [year, month] = status.body.tanggal.split('-');
      const result = await request(`/api/admin/rekap?month=${Number(month)}&year=${year}`, { authorized: true });
      if (result.status !== 200) throw new HttpError(result.status, result.body.error);
      const excel = await fetch(`${origin}/api/admin/rekap.xlsx?month=${Number(month)}&year=${year}`, {
        headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(60000),
      });
      if (!excel.ok) throw new HttpError(excel.status, 'Pengecekan ekspor Excel gagal.');
      const bytes = Buffer.from(await excel.arrayBuffer());
      if (bytes.length < 4 || bytes.subarray(0, 2).toString('ascii') !== 'PK') throw new HttpError(500, 'Format file ekspor tidak sesuai.');
      console.log('Rekap JSON dan ekspor Excel berhasil dibuat (file tidak disimpan).');
    }
    console.log('Pemeriksaan workflow hanya membaca data; tidak mengunggah bukti atau menandai notifikasi dibaca.');
  }
  const logout = await request('/api/auth/logout', { method: 'POST', authorized: true });
  if (logout.status !== 200) throw new HttpError(logout.status, logout.body.error);
  const after = await request('/api/me', { authorized: true });
  if (after.status !== 401) throw new HttpError(500, 'Token masih dapat digunakan setelah logout.');
  token = undefined;
  console.log('Logout berhasil; token tidak dapat digunakan kembali.');
} catch (error) {
  console.error(error instanceof HttpError ? error.message : 'Pengecekan gagal. Pastikan backend aktif dan konfigurasi benar.');
  process.exitCode = 1;
} finally {
  if (token) {
    try { await request('/api/auth/logout', { method: 'POST', authorized: true }); }
    catch { console.error('Sesi uji belum dapat dicabut karena backend tidak dapat dihubungi.'); }
  }
}
