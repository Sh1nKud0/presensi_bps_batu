import assert from 'node:assert/strict';
import test from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { createApp } from '../src/app.js';
import { createFirstAdmin } from '../src/auth.js';
import { migrate } from '../src/migrate.js';
import { createRateLimiter, tokenHash } from '../src/security.js';

// PGlite mengeksekusi PostgreSQL dalam memori. Adapter mendukung pool/client pg
// untuk uji serial ini; tidak menyimulasikan banyak koneksi atau lock lintas proses.
function adapter(pg) {
  const database = {
    async query(sql, values) {
      if (values !== undefined) return pg.query(sql, values);
      const results = await pg.exec(sql);
      return results.at(-1) ?? { rows: [] };
    },
    async connect() { return { query: database.query, release() {} }; },
  };
  return database;
}

test('migrasi PostgreSQL dan autentikasi API', async t => {
  const pg = new PGlite();
  await pg.waitReady;
  const database = adapter(pg);
  const server = createApp({ database, rateLimit: createRateLimiter({ max: 200 }) });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    await pg.close();
  });
  const url = `http://127.0.0.1:${server.address().port}`;
  async function api(path, { method = 'GET', body, token } = {}) {
    const response = await fetch(`${url}${path}`, {
      method,
      headers: { ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
    return { status: response.status, body: await response.json() };
  }
  const credentials = { email: ' PESERTA@EXAMPLE.COM ', password: '  password sah  ', nama_lengkap: 'Peserta Uji' };
  let user, token;

  await t.test('migrasi membuat semua tabel tanpa auth Supabase dan aman diulang', async () => {
    assert.deepEqual(await migrate(database), ['001_initial.sql', '002_notifications_files.sql']);
    assert.deepEqual(await migrate(database), []);
    const tables = (await database.query("SELECT tablename FROM pg_tables WHERE schemaname = 'presensi' ORDER BY tablename")).rows.map(row => row.tablename);
    assert.deepEqual(tables, ['absen_susulan', 'absensi', 'files', 'hari_libur', 'izin', 'notifications', 'pembatalan_pulang', 'profiles', 'schema_migrations', 'sessions', 'users']);
    assert.equal((await database.query("SELECT to_regnamespace('auth') AS name")).rows[0].name, null);
  });

  await t.test('registrasi menolak role admin dan tidak menulis user', async () => {
    const result = await api('/api/auth/register', { method: 'POST', body: { ...credentials, role: 'admin' } });
    assert.equal(result.status, 400);
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.users')).rows[0].n, 0);
  });

  await t.test('registrasi menyimpan hash dan profil peserta secara atomik', async () => {
    const result = await api('/api/auth/register', { method: 'POST', body: credentials });
    assert.equal(result.status, 201);
    user = result.body.user;
    assert.equal(user.email, 'peserta@example.com');
    assert.equal(user.role, 'peserta');
    assert.equal(user.password_hash, undefined);
    const stored = (await database.query('SELECT password_hash FROM presensi.users WHERE id = $1', [user.id])).rows[0];
    assert.match(stored.password_hash, /^scrypt\$/);
    assert.ok(!stored.password_hash.includes(credentials.password));
    const duplicate = await api('/api/auth/register', { method: 'POST', body: credentials });
    assert.equal(duplicate.status, 409);
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.profiles')).rows[0].n, 1);
  });

  await t.test('kegagalan profil membatalkan insert akun', async () => {
    await database.query(`CREATE FUNCTION presensi.test_reject_profile() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF new.nama_lengkap = 'Gagal Uji' THEN RAISE EXCEPTION 'uji'; END IF; RETURN new; END $$;
      CREATE TRIGGER test_reject BEFORE INSERT ON presensi.profiles FOR EACH ROW EXECUTE FUNCTION presensi.test_reject_profile();`);
    const result = await api('/api/auth/register', { method: 'POST', body: { ...credentials, email: 'rollback@example.com', nama_lengkap: 'Gagal Uji' } });
    assert.equal(result.status, 503);
    assert.equal((await database.query("SELECT count(*)::int AS n FROM presensi.users WHERE email = 'rollback@example.com'")).rows[0].n, 0);
    await database.query('DROP TRIGGER test_reject ON presensi.profiles; DROP FUNCTION presensi.test_reject_profile();');
  });

  await t.test('password salah dan email tidak terdaftar memakai pesan yang sama', async () => {
    const wrong = await api('/api/auth/login', { method: 'POST', body: { email: credentials.email, password: credentials.password.trim() } });
    const absent = await api('/api/auth/login', { method: 'POST', body: { email: 'absent@example.com', password: credentials.password } });
    assert.equal(wrong.status, 401);
    assert.equal(absent.status, 401);
    assert.deepEqual(wrong.body, absent.body);
  });

  await t.test('login memakai password utuh dan menyimpan hash token saja', async () => {
    const result = await api('/api/auth/login', { method: 'POST', body: { email: credentials.email, password: credentials.password } });
    assert.equal(result.status, 200);
    token = result.body.access_token;
    assert.equal(token.length, 43);
    assert.equal(result.body.user.password_hash, undefined);
    const session = (await database.query('SELECT token_hash, expires_at > now() AS valid FROM presensi.sessions')).rows[0];
    assert.equal(session.token_hash, tokenHash(token));
    assert.equal(session.valid, true);
    assert.notEqual(session.token_hash, token);
  });

  await t.test('profil membutuhkan token sah, peserta tidak boleh mengakses admin', async () => {
    assert.equal((await api('/api/me')).status, 401);
    assert.equal((await api('/api/me', { token: 'x'.repeat(43) })).status, 401);
    const me = await api('/api/me', { token });
    assert.equal(me.status, 200);
    assert.equal(me.body.user.id, user.id);
    assert.equal((await api('/api/admin/users', { token })).status, 403);
  });

  await t.test('edit profil tidak dapat mengubah role, id, atau email', async () => {
    for (const field of ['role', 'id', 'email']) {
      assert.equal((await api('/api/me', { method: 'PATCH', token, body: { [field]: 'admin' } })).status, 400);
    }
    const result = await api('/api/me', { method: 'PATCH', token, body: { nama_lengkap: 'Nama Baru', nim: "123'; DROP TABLE presensi.users; --" } });
    assert.equal(result.status, 200);
    assert.equal(result.body.user.nama_lengkap, 'Nama Baru');
    assert.equal(result.body.user.role, 'peserta');
    assert.match(result.body.user.nim, /DROP TABLE/);
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.users')).rows[0].n, 1);
  });

  await t.test('constraint menolak presensi ganda, pulang sebelum masuk, dan rentang izin terbalik', async () => {
    await database.query("INSERT INTO presensi.absensi(user_id, tanggal, jam_masuk) VALUES ($1, '2026-10-08', '2026-10-08T00:30:00Z')", [user.id]);
    await assert.rejects(database.query("INSERT INTO presensi.absensi(user_id, tanggal) VALUES ($1, '2026-10-08')", [user.id]), error => error.code === '23505');
    await assert.rejects(database.query("UPDATE presensi.absensi SET jam_pulang = '2026-10-08T00:00:00Z' WHERE user_id = $1", [user.id]), error => error.code === '23514');
    await assert.rejects(database.query("INSERT INTO presensi.izin(user_id, tanggal_mulai, tanggal_selesai, jenis) VALUES ($1, '2026-10-09', '2026-10-08', 'izin')", [user.id]), error => error.code === '23514');
  });

  await t.test('ganti password memerlukan password lama dan mencabut seluruh sesi', async () => {
    const bad = await api('/api/auth/password', { method: 'POST', token, body: { current_password: 'salah', new_password: 'password-baru' } });
    assert.equal(bad.status, 401);
    assert.equal((await api('/api/me', { token })).status, 200);
    const result = await api('/api/auth/password', { method: 'POST', token, body: { current_password: credentials.password, new_password: 'password-baru' } });
    assert.equal(result.status, 200);
    assert.equal((await api('/api/me', { token })).status, 401);
    assert.equal((await api('/api/auth/login', { method: 'POST', body: { email: credentials.email, password: credentials.password } })).status, 401);
    token = (await api('/api/auth/login', { method: 'POST', body: { email: credentials.email, password: 'password-baru' } })).body.access_token;
    assert.ok(token);
  });

  await t.test('logout mencabut token', async () => {
    assert.equal((await api('/api/auth/logout', { method: 'POST', token })).status, 200);
    assert.equal((await api('/api/me', { token })).status, 401);
  });

  await t.test('token kedaluwarsa dan akun nonaktif tidak boleh mengakses profil', async () => {
    const login = () => api('/api/auth/login', { method: 'POST', body: { email: credentials.email, password: 'password-baru' } });
    let session = (await login()).body.access_token;
    await database.query("UPDATE presensi.sessions SET created_at = now() - interval '2 days', expires_at = now() - interval '1 day'");
    assert.equal((await api('/api/me', { token: session })).status, 401);
    session = (await login()).body.access_token;
    await database.query('UPDATE presensi.users SET active = false WHERE id = $1', [user.id]);
    assert.equal((await api('/api/me', { token: session })).status, 401);
    assert.equal((await login()).status, 401);
  });

  await t.test('bootstrap admin hanya sekali dan endpoint admin tidak membocorkan hash', async () => {
    const input = { email: 'admin@example.com', nama_lengkap: 'Admin Uji', password: 'admin-password' };
    const admin = await createFirstAdmin(database, input);
    assert.equal(admin.role, 'admin');
    await assert.rejects(createFirstAdmin(database, { ...input, email: 'admin2@example.com' }), /Admin sudah ada/);
    const result = await api('/api/auth/login', { method: 'POST', body: { email: input.email, password: input.password } });
    const users = await api('/api/admin/users', { token: result.body.access_token });
    assert.equal(users.status, 200);
    assert.equal(users.body.users.length, 2);
    assert.ok(users.body.users.every(row => !Object.hasOwn(row, 'password_hash')));
  });

  await t.test('checksum migrasi berubah ditolak', async () => {
    await database.query("UPDATE presensi.schema_migrations SET checksum = 'berubah'");
    await assert.rejects(migrate(database), /berubah setelah dijalankan/);
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.users')).rows[0].n, 2);
  });
});

test('validasi HTTP dan pembatasan percobaan login', async t => {
  const database = { query() { assert.fail('Tidak boleh mengakses database'); } };
  let called = 0;
  const auth = { async login() { called++; return { ok: true }; } };
  const server = createApp({ database, auth, rateLimit: createRateLimiter({ max: 3 }) });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/api/auth/login`;
  assert.equal((await fetch(url, { method: 'POST', body: '{}' })).status, 415);
  assert.equal((await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: 'invalid' })).status, 400);
  assert.equal((await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: 'x'.repeat(20000) }) })).status, 413);
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': '1.2.3.4' }, body: '{}' });
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '60');
  assert.equal(called, 0);
});

test('limiter kembali tersedia setelah jendela waktu berlalu', () => {
  let time = 0;
  const limit = createRateLimiter({ max: 1, windowMs: 60, now: () => time });
  limit('client');
  assert.throws(() => limit('client'), error => error.status === 429);
  time = 60;
  assert.doesNotThrow(() => limit('client'));
});
