import assert from 'node:assert/strict';
import test from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { createApp } from '../src/app.js';
import { migrate } from '../src/migrate.js';
import { createRateLimiter } from '../src/security.js';
import { distanceMeters, serverClock } from '../src/attendance.js';
import { HttpError } from '../src/errors.js';

test('API presensi, pengajuan, dan keputusan admin pada PostgreSQL', async t => {
  const pg = new PGlite();
  await pg.waitReady;
  let fixedTime = null;
  const locks = [];
  const database = {
    async query(sql, values) {
      if (sql.includes('FROM presensi.profiles WHERE id = $1 FOR UPDATE')) locks.push(values[0]);
      if (fixedTime && sql.startsWith('WITH clock AS')) {
        return { rows: [{ instant: new Date(fixedTime), day: new Date(Date.parse(fixedTime) + 7 * 3600000).toISOString().slice(0, 10) }] };
      }
      return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values);
    },
    async connect() { return { query: database.query, release() {} }; },
  };
  await migrate(database);
  // Uji query jam asli tanpa mengganti jam proses atau server BPS.
  const realClock = await serverClock(database);
  assert.equal(realClock.day, new Date(realClock.instant.getTime() + 7 * 3600000).toISOString().slice(0, 10));
  fixedTime = '2026-10-08T00:30:00Z';
  const users = {};
  const tokens = new Map();
  for (const [index, key] of ['regular', 'late', 'leave', 'approvedLeave', 'correction', 'rollback', 'conflict', 'holiday', 'admin'].entries()) {
    const row = (await database.query('INSERT INTO presensi.users(email, password_hash) VALUES ($1, $2) RETURNING id, email', [`${key.toLowerCase()}@example.com`, 'unused-in-domain-tests'])).rows[0];
    const role = key === 'admin' ? 'admin' : 'peserta';
    await database.query('INSERT INTO presensi.profiles(id, nama_lengkap, role) VALUES ($1, $2, $3)', [row.id, key, role]);
    users[key] = { ...row, role };
    users[key].token = String(index).repeat(43);
    tokens.set(users[key].token, users[key]);
  }
  // Autentikasi asli diuji di auth.integration.test.js. Di sini fokus otorisasi
  // route dan transaksi domain menggunakan identitas akun fixture tetap.
  const auth = { async authenticate(token) {
    if (!tokens.has(token)) throw new HttpError(401, 'Sesi tidak sah.');
    return tokens.get(token);
  } };
  const server = createApp({ database, auth, rateLimit: createRateLimiter({ max: 300 }) });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    await pg.close();
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  async function api(key, path, body, method) {
    const response = await fetch(`${origin}${path}`, {
      method: method ?? (body ? 'POST' : 'GET'),
      headers: { ...(key ? { Authorization: `Bearer ${users[key].token}` } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    return { status: response.status, body: await response.json() };
  }
  const point = () => ({ latitude: -7.8668, longitude: 112.5073, accuracy: 10, captured_at: fixedTime });
  const leave = (start = '2026-10-08', end = start) => ({ tanggal_mulai: start, tanggal_selesai: end, jenis: 'izin', keterangan: 'Keperluan keluarga' });
  const correction = (day = '2026-10-07') => ({ tanggal: day, jam_masuk_diajukan: '08:00', jam_pulang_diajukan: '15:00', jenis_alasan: 'lupa_absen', keterangan: 'Lupa melakukan presensi' });
  const decide = (kind, id) => `/api/admin/requests/${kind}/${id}/decision`;

  await t.test('validasi GPS menolak radius, akurasi, lokasi lama, dan payload jam buatan', async () => {
    assert.equal(distanceMeters(-7.8668, 112.5073), 0);
    for (const change of [{ latitude: -7 }, { accuracy: 100 }, { is_mocked: true },
      { captured_at: '2026-10-07T23:00:00Z' }, { captured_at: '2026-10-08T01:00:00Z' },
      { latitude: 'NaN' }, { jam_masuk: '2000-01-01T00:00:00Z' }, { user_id: users.admin.id }]) {
      assert.equal((await api('regular', '/api/attendance/check-in', { ...point(), ...change })).status, 400);
    }
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.absensi')).rows[0].n, 0);
  });

  await t.test('jam masuk memakai waktu server; tepat 07:30 hadir, sesudahnya terlambat', async () => {
    const first = await api('regular', '/api/attendance/check-in', point());
    assert.equal(first.status, 200);
    assert.equal(first.body.attendance.status, 'hadir');
    assert.equal(first.body.attendance.jam_masuk, new Date(fixedTime).toISOString());
    fixedTime = '2026-10-08T00:30:01Z';
    const late = await api('late', '/api/attendance/check-in', point());
    assert.equal(late.status, 200);
    assert.equal(late.body.attendance.status, 'terlambat');
    assert.ok(locks.includes(users.regular.id));
    const today = await api('regular', '/api/attendance/today');
    assert.equal(today.body.can_check_in, false);
    assert.equal(today.body.can_check_out, true);
  });

  await t.test('presensi sekali; setelah masuk tidak boleh diganti izin/susulan', async () => {
    assert.equal((await api('regular', '/api/attendance/check-in', point())).status, 409);
    assert.equal((await api('regular', '/api/requests/izin', leave())).status, 409);
    assert.equal((await api('regular', '/api/requests/susulan', { ...correction('2026-10-08'), jam_masuk_diajukan: '07:00', jam_pulang_diajukan: null })).status, 409);
    fixedTime = '2026-10-08T05:00:00Z'; // pulang awal tetap boleh sesuai alur aplikasi.
    assert.equal((await api('regular', '/api/attendance/check-out', point())).status, 200);
    assert.equal((await api('regular', '/api/attendance/check-out', point())).status, 409);
    assert.equal((await api('regular', '/api/attendance/today')).body.can_check_out, false);
  });

  let pendingLeave;
  await t.test('izin aktif memblokir presensi dan pengajuan tumpang tindih', async () => {
    const request = await api('leave', '/api/requests/izin', leave('2026-10-08', '2026-10-10'));
    assert.equal(request.status, 201);
    pendingLeave = request.body.request.id;
    assert.equal((await api('leave', '/api/attendance/check-in', point())).status, 409);
    assert.equal((await api('leave', '/api/requests/izin', leave('2026-10-09'))).status, 409);
    assert.equal((await api('leave', '/api/requests/susulan', { ...correction('2026-10-08'), jam_pulang_diajukan: null })).status, 409);
    assert.equal((await api('leave', '/api/attendance/today')).body.can_check_in, false);
  });

  await t.test('hanya admin boleh memutuskan, alasan penolakan wajib, keputusan tidak boleh diulang', async () => {
    assert.equal((await api('leave', decide('izin', pendingLeave), { setujui: true })).status, 403);
    assert.equal((await api('admin', decide('izin', pendingLeave), { setujui: false })).status, 400);
    const rejected = await api('admin', decide('izin', pendingLeave), { setujui: false, alasan_penolakan: 'Tanggal tidak sesuai' });
    assert.equal(rejected.status, 200);
    assert.equal(rejected.body.request.status_persetujuan, 'ditolak');
    assert.ok(rejected.body.request.diproses_at);
    assert.equal((await api('admin', decide('izin', pendingLeave), { setujui: true })).status, 409);
    assert.equal((await api('leave', '/api/attendance/check-in', point())).status, 200);
  });

  await t.test('izin disetujui tetap memblokir presensi pada tanggal terkait', async () => {
    const request = await api('approvedLeave', '/api/requests/izin', leave());
    assert.equal(request.status, 201);
    const approved = await api('admin', decide('izin', request.body.request.id), { setujui: true });
    assert.equal(approved.status, 200);
    assert.equal(approved.body.request.disetujui_oleh, users.admin.id);
    assert.equal((await api('approvedLeave', '/api/attendance/check-in', point())).status, 409);
    assert.equal((await api('approvedLeave', '/api/attendance/today')).body.can_check_in, false);
  });

  await t.test('susulan disetujui membuat jam WIB yang benar walau zona database berbeda', async () => {
    await database.query("SET TIME ZONE 'Pacific/Honolulu'");
    const request = await api('correction', '/api/requests/susulan', correction());
    assert.equal(request.status, 201);
    const result = await api('admin', decide('susulan', request.body.request.id), { setujui: true });
    assert.equal(result.status, 200);
    const row = (await database.query('SELECT * FROM presensi.absensi WHERE user_id = $1', [users.correction.id])).rows[0];
    assert.equal(new Date(row.jam_masuk).toISOString(), '2026-10-07T01:00:00.000Z');
    assert.equal(new Date(row.jam_pulang).toISOString(), '2026-10-07T08:00:00.000Z');
    assert.equal(row.status, 'terlambat');
    assert.equal((await api('admin', decide('susulan', request.body.request.id), { setujui: true })).status, 409);
    await database.query("SET TIME ZONE 'UTC'");
  });

  await t.test('susulan hari ini memblokir presensi dan susulan lain, termasuk setelah disetujui', async () => {
    const request = await api('correction', '/api/requests/susulan', { ...correction('2026-10-08'), jam_pulang_diajukan: null });
    assert.equal(request.status, 201);
    assert.equal((await api('correction', '/api/attendance/check-in', point())).status, 409);
    assert.equal((await api('correction', '/api/requests/susulan', { ...correction('2026-10-08'), jam_pulang_diajukan: null })).status, 409);
    assert.equal((await api('admin', decide('susulan', request.body.request.id), { setujui: true })).status, 200);
    assert.equal((await api('correction', '/api/attendance/check-out', point())).status, 409);
  });

  await t.test('approval susulan rollback seluruhnya jika penyimpanan status gagal', async () => {
    const request = await api('rollback', '/api/requests/susulan', correction());
    assert.equal(request.status, 201);
    await database.query(`CREATE FUNCTION presensi.test_fail_decision() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF new.user_id = '${users.rollback.id}'::uuid THEN RAISE EXCEPTION 'simulated'; END IF; RETURN new; END $$;
      CREATE TRIGGER test_fail_decision BEFORE UPDATE ON presensi.absen_susulan FOR EACH ROW EXECUTE FUNCTION presensi.test_fail_decision();`);
    const result = await api('admin', decide('susulan', request.body.request.id), { setujui: true });
    assert.equal(result.status, 503);
    assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.absensi WHERE user_id = $1', [users.rollback.id])).rows[0].n, 0);
    assert.equal((await database.query('SELECT status_persetujuan FROM presensi.absen_susulan WHERE id = $1', [request.body.request.id])).rows[0].status_persetujuan, 'menunggu');
    await database.query('DROP TRIGGER test_fail_decision ON presensi.absen_susulan; DROP FUNCTION presensi.test_fail_decision();');
    assert.equal((await api('admin', decide('susulan', request.body.request.id), { setujui: true })).status, 200);
  });

  await t.test('approval memeriksa ulang konflik dan tidak menimpa presensi yang muncul kemudian', async () => {
    const request = await api('conflict', '/api/requests/susulan', correction());
    assert.equal(request.status, 201);
    await database.query("INSERT INTO presensi.absensi(user_id, tanggal, jam_masuk) VALUES ($1, '2026-10-07', '2026-10-07T00:00:00Z')", [users.conflict.id]);
    assert.equal((await api('admin', decide('susulan', request.body.request.id), { setujui: true })).status, 409);
    const row = (await database.query('SELECT jam_masuk FROM presensi.absensi WHERE user_id = $1', [users.conflict.id])).rows[0];
    assert.equal(new Date(row.jam_masuk).toISOString(), '2026-10-07T00:00:00.000Z');
  });

  await t.test('hari libur dan akhir pekan memblokir presensi', async () => {
    await database.query("INSERT INTO presensi.hari_libur(tanggal, keterangan) VALUES ('2026-10-08', 'Libur uji')");
    assert.equal((await api('holiday', '/api/attendance/check-in', point())).status, 409);
    assert.equal((await api('holiday', '/api/attendance/today')).body.hari_libur, 'Libur uji');
    await database.query("DELETE FROM presensi.hari_libur WHERE tanggal = '2026-10-08'");
    fixedTime = '2026-10-10T01:00:00Z';
    assert.equal((await api('holiday', '/api/attendance/check-in', point())).status, 409);
    fixedTime = '2026-10-08T05:00:00Z';
  });

  await t.test('validasi tanggal, urutan jam, pengajuan masa depan, dan bukti', async () => {
    for (const input of [{ ...correction(), tanggal: '2026-02-30' }, { ...correction(), tanggal: '2026-10-09' },
      { ...correction(), tanggal: '2026-10-04' }, { ...correction(), tanggal: '2026-09-01' },
      { ...correction(), jam_masuk_diajukan: null }, { ...correction(), jam_pulang_diajukan: '07:00' },
      { ...correction(), jam_masuk_diajukan: '25:00' }, { ...correction(), bukti_url: 'http://example.com/bukti.jpg' }]) {
      const result = await api('holiday', '/api/requests/susulan', input);
      assert.ok([400, 409].includes(result.status), JSON.stringify(result));
    }
    assert.equal((await api('holiday', '/api/requests/izin', leave('2026-10-09', '2026-10-08'))).status, 400);
    assert.equal((await api('holiday', '/api/requests/izin', { ...leave(), status_persetujuan: 'disetujui' })).status, 400);
  });

  await t.test('history dan daftar pengajuan hanya milik sendiri, admin melihat antrean', async () => {
    const history = await api('regular', '/api/attendance/history?from=2026-10-01&to=2026-10-08');
    assert.equal(history.status, 200);
    assert.ok(history.body.attendance.every(row => row.user_id === users.regular.id));
    assert.equal(history.body.attendance.length, 1);
    const requests = await api('approvedLeave', '/api/requests/izin');
    assert.equal(requests.status, 200);
    assert.ok(requests.body.requests.every(row => row.user_id === users.approvedLeave.id));
    assert.equal((await api('regular', '/api/attendance/history?user_id=' + users.admin.id)).status, 400);
    assert.equal((await api('regular', '/api/attendance/history?limit=101')).status, 400);
    assert.equal((await api(null, '/api/attendance/today')).status, 401);
    assert.equal((await api('regular', '/api/admin/requests/izin')).status, 403);
    const queue = await api('admin', '/api/admin/requests/susulan');
    assert.equal(queue.status, 200);
    assert.ok(queue.body.requests.every(row => row.status_persetujuan === 'menunggu'));
    assert.equal((await api('admin', decide('izin', 'invalid'), { setujui: true })).status, 400);
  });
});
