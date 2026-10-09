import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, readdir, unlink, rmdir, writeFile, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import ExcelJS from 'exceljs';
import { createApp } from '../src/app.js';
import { migrate } from '../src/migrate.js';
import { createRateLimiter } from '../src/security.js';
import { HttpError } from '../src/errors.js';
import { buildReport, reportWorkbook } from '../src/reports.js';

test('pembatalan, notifikasi, bukti privat, hari libur, dan ekspor', async t => {
  const pg = new PGlite();
  await pg.waitReady;
  const directory = await mkdtemp(join(tmpdir(), 'presensi-private-test-'));
  let fixedTime = '2026-10-08T05:30:00Z';
  const database = {
    async query(sql, values) {
      if (sql.startsWith('WITH clock AS')) return { rows: [{ instant: new Date(fixedTime), day: new Date(Date.parse(fixedTime) + 7 * 3600000).toISOString().slice(0, 10) }] };
      return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values);
    },
    async connect() { return { query: database.query, release() {} }; },
  };
  await migrate(database);
  const users = {};
  const tokens = new Map();
  for (const [index, key] of ['early', 'late', 'expired', 'changed', 'rollback', 'fileOwner', 'other', 'quota', 'fileFail', 'admin'].entries()) {
    const row = (await database.query('INSERT INTO presensi.users(email, password_hash) VALUES ($1, $2) RETURNING id, email', [`${key.toLowerCase()}@example.com`, 'unused-domain-hash'])).rows[0];
    const role = key === 'admin' ? 'admin' : 'peserta';
    await database.query('INSERT INTO presensi.profiles(id, nama_lengkap, role) VALUES ($1, $2, $3)', [row.id, key, role]);
    users[key] = { ...row, role, token: String(index).repeat(43) };
    tokens.set(users[key].token, users[key]);
  }
  const auth = { async authenticate(token) {
    if (!tokens.has(token)) throw new HttpError(401, 'Sesi tidak sah.');
    return tokens.get(token);
  } };
  const server = createApp({ database, auth, uploadDirectory: directory, rateLimit: createRateLimiter({ max: 300 }) });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise(resolve => server.close(resolve));
    await pg.close();
    // Hanya file pada direktori temporer yang dibuat oleh tes ini.
    for (const file of await readdir(directory)) await unlink(join(directory, file));
    await rmdir(directory);
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
  const cancel = (id) => ({ absensi_id: id, alasan: 'Tidak sengaja menekan absen pulang' });
  const decision = id => `/api/admin/requests/pembatalan/${id}/decision`;
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNXkAAAAASUVORK5CYII=', 'base64');
  async function upload(key, buffer = png, mime = 'image/png') {
    const response = await fetch(`${origin}/api/files`, { method: 'POST',
      headers: { Authorization: `Bearer ${users[key].token}`, 'Content-Type': mime }, body: buffer });
    return { status: response.status, body: await response.json() };
  }
  const attendance = {};
  for (const key of ['early', 'late', 'expired', 'changed', 'rollback']) {
    attendance[key] = (await database.query(`INSERT INTO presensi.absensi
      (user_id, tanggal, jam_masuk, jam_pulang, latitude_pulang, longitude_pulang, foto_pulang_url)
      VALUES ($1, '2026-10-08', '2026-10-08T00:00:00Z', $2, -7.8668, 112.5073, 'old-photo') RETURNING id`,
    [users[key].id, key === 'late' ? '2026-10-08T09:00:00Z' : '2026-10-08T05:00:00.123456Z'])).rows[0].id;
  }

  let first, retry;
  await t.test('query mobile membatasi statistik per pengguna dan daftar presensi hanya admin', async () => {
    assert.equal((await api(null, '/api/me/statistics')).status, 401);
    assert.equal((await api('early', '/api/admin/attendance')).status, 403);
    assert.equal((await api('early', '/api/admin/participants')).status, 403);
    assert.deepEqual((await api('early', '/api/me/statistics')).body, { hadir: 1, izin: 0 });
    assert.deepEqual((await api('other', '/api/me/statistics')).body, { hadir: 0, izin: 0 });
    const list = await api('admin', '/api/admin/attendance');
    assert.equal(list.status, 200);
    assert.equal(list.body.tanggal_server, '2026-10-08');
    assert.equal(list.body.attendance.length, 5);
    assert.ok(list.body.attendance.every(row => row.nama_lengkap && !row.password_hash));
    assert.equal((await api('admin', '/api/admin/attendance?from=2026-10-09&to=2026-10-08')).status, 400);
    assert.equal((await api('admin', '/api/admin/attendance?user_id=bad')).status, 400);
    const page = await api('admin', '/api/admin/participants?limit=2&offset=1');
    assert.equal(page.body.participants.length, 2);
    assert.ok(page.body.participants.every(row => row.role === 'peserta' && !row.email && !row.password_hash));
  });
  await t.test('pengajuan pembatalan hanya milik sendiri, satu pending, jam belum dihapus', async () => {
    assert.equal((await api('other', '/api/requests/pembatalan', cancel(attendance.early))).status, 404);
    assert.equal((await api('late', '/api/requests/pembatalan', cancel(attendance.late))).status, 409);
    const result = await api('early', '/api/requests/pembatalan', cancel(attendance.early));
    assert.equal(result.status, 201);
    first = result.body.request.id;
    assert.equal((await api('early', '/api/requests/pembatalan', cancel(attendance.early))).status, 409);
    assert.ok((await database.query('SELECT jam_pulang FROM presensi.absensi WHERE id = $1', [attendance.early])).rows[0].jam_pulang);
  });

  await t.test('notifikasi pengajuan hanya untuk admin dan status dibaca terikat penerima', async () => {
    const list = await api('admin', '/api/notifications');
    assert.equal(list.status, 200);
    const notice = list.body.notifications.find(row => row.request_id === first);
    assert.ok(notice);
    assert.equal(notice.status, 'menunggu');
    assert.equal((await api('early', '/api/notifications')).body.notifications.length, 0);
    const otherRead = await api('other', '/api/notifications/read', { ids: [notice.id] }, 'PATCH');
    assert.equal(otherRead.body.read_count, 0);
    assert.equal((await api('admin', '/api/notifications/read', { ids: [notice.id] }, 'PATCH')).body.read_count, 1);
    assert.equal((await api('admin', '/api/notifications?unread=true')).body.notifications.some(row => row.id === notice.id), false);
  });

  await t.test('penolakan mempertahankan jam dan peserta menerima hasil pada tanggal keputusan', async () => {
    assert.equal((await api('early', decision(first), { setujui: true })).status, 403);
    const result = await api('admin', decision(first), { setujui: false, alasan_penolakan: 'Tidak sesuai keterangan' });
    assert.equal(result.status, 200);
    assert.ok((await database.query('SELECT jam_pulang FROM presensi.absensi WHERE id = $1', [attendance.early])).rows[0].jam_pulang);
    const notices = await api('early', '/api/notifications?date=2026-10-08');
    assert.equal(notices.body.notifications.length, 1);
    assert.equal(notices.body.notifications[0].status, 'ditolak');
    assert.equal((await api('early', '/api/notifications?date=2026-10-07')).body.notifications.length, 0);
    assert.equal((await api('early', '/api/notifications/read', { date: '2026-10-08' }, 'PATCH')).body.read_count, 1);
    assert.equal((await api('early', '/api/notifications?date=2026-10-08')).body.unread_count, 0);
    retry = (await api('early', '/api/requests/pembatalan', cancel(attendance.early))).body.request.id;
    assert.ok(retry);
  });

  await t.test('persetujuan menghapus hanya data pulang dan membuka presensi pulang ulang', async () => {
    assert.equal((await api('admin', decision(retry), { setujui: true })).status, 200);
    const row = (await database.query('SELECT * FROM presensi.absensi WHERE id = $1', [attendance.early])).rows[0];
    assert.equal(row.jam_pulang, null);
    assert.equal(row.latitude_pulang, null);
    assert.equal(row.longitude_pulang, null);
    assert.equal(row.foto_pulang_url, null);
    assert.equal(new Date(row.jam_masuk).toISOString(), '2026-10-08T00:00:00.000Z');
    const checkout = await api('early', '/api/attendance/check-out', { latitude: -7.8668, longitude: 112.5073, accuracy: 5, captured_at: fixedTime });
    assert.equal(checkout.status, 200);
    assert.equal((await api('admin', decision(retry), { setujui: true })).status, 409);
    const notices = (await api('early', '/api/notifications')).body.notifications;
    assert.equal(notices.filter(row => row.request_id === retry && row.status === 'disetujui').length, 1);
  });

  await t.test('snapshot membedakan perubahan satu mikrodetik dan tanggal kedaluwarsa', async () => {
    const changed = (await api('changed', '/api/requests/pembatalan', cancel(attendance.changed))).body.request.id;
    await database.query("UPDATE presensi.absensi SET jam_pulang = '2026-10-08T05:00:00.123457Z' WHERE id = $1", [attendance.changed]);
    assert.equal((await api('admin', decision(changed), { setujui: true })).status, 409);
    const expired = (await api('expired', '/api/requests/pembatalan', cancel(attendance.expired))).body.request.id;
    fixedTime = '2026-10-09T01:00:00Z';
    assert.equal((await api('admin', decision(expired), { setujui: true })).status, 409);
    assert.equal((await api('admin', decision(expired), { setujui: false, alasan_penolakan: 'Tanggal telah lewat' })).status, 200);
    fixedTime = '2026-10-08T05:30:00Z';
  });

  await t.test('kegagalan keputusan rollback penghapusan jam dan notifikasi hasil', async () => {
    const request = (await api('rollback', '/api/requests/pembatalan', cancel(attendance.rollback))).body.request.id;
    await database.query(`CREATE FUNCTION presensi.fail_cancel() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      RAISE EXCEPTION 'simulated'; END $$;
      CREATE TRIGGER fail_cancel BEFORE UPDATE ON presensi.pembatalan_pulang FOR EACH ROW EXECUTE FUNCTION presensi.fail_cancel();`);
    assert.equal((await api('admin', decision(request), { setujui: true })).status, 503);
    assert.ok((await database.query('SELECT jam_pulang FROM presensi.absensi WHERE id = $1', [attendance.rollback])).rows[0].jam_pulang);
    assert.equal((await database.query('SELECT status_persetujuan FROM presensi.pembatalan_pulang WHERE id = $1', [request])).rows[0].status_persetujuan, 'menunggu');
    assert.equal((await api('rollback', '/api/notifications')).body.notifications.length, 0);
    await database.query('DROP TRIGGER fail_cancel ON presensi.pembatalan_pulang; DROP FUNCTION presensi.fail_cancel();');
  });

  let file;
  await t.test('unggah bukti disimpan privat, hanya pemilik dan admin boleh mengunduh', async () => {
    const result = await upload('fileOwner');
    assert.equal(result.status, 201);
    file = result.body.file;
    assert.equal(file.size_bytes, png.length);
    assert.equal(file.storage_key, undefined);
    assert.equal((await api('fileOwner', '/api/files')).body.files.length, 1);
    assert.equal((await api('other', '/api/files')).body.files.length, 0);
    assert.equal((await fetch(`${origin}${file.download_path}`)).status, 401);
    assert.equal((await fetch(`${origin}${file.download_path}`, { headers: { Authorization: `Bearer ${users.other.token}` } })).status, 404);
    for (const key of ['fileOwner', 'admin']) {
      const response = await fetch(`${origin}${file.download_path}`, { headers: { Authorization: `Bearer ${users[key].token}` } });
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-disposition'), /^attachment/);
      assert.equal(response.headers.get('cache-control'), 'private, no-store');
      assert.deepEqual(Buffer.from(await response.arrayBuffer()), png);
    }
  });

  await t.test('bukti milik peserta lain tidak dapat ditempel ke pengajuan', async () => {
    const input = { tanggal_mulai: '2026-10-08', tanggal_selesai: '2026-10-08', jenis: 'sakit', keterangan: 'Sakit dengan bukti', bukti_id: file.id };
    assert.equal((await api('other', '/api/requests/izin', input)).status, 404);
    const request = await api('fileOwner', '/api/requests/izin', input);
    assert.equal(request.status, 201);
    assert.equal(request.body.request.bukti_id, file.id);
    assert.equal((await api('admin', `/api/admin/requests/izin/${request.body.request.id}/decision`, { setujui: true })).status, 200);
    assert.equal((await api('fileOwner', '/api/notifications?date=2026-10-08')).body.notifications[0].status, 'disetujui');
  });

  await t.test('file palsu, MIME berbeda, ukuran besar dan kuota ditolak', async () => {
    assert.equal((await upload('other', Buffer.from('<html>bad</html>'))).status, 415);
    assert.equal((await upload('other', png, 'image/jpeg')).status, 415);
    assert.equal((await upload('other', Buffer.alloc(5242881))).status, 413);
    for (let index = 0; index < 20; index++) {
      const id = randomUUID();
      await database.query(`INSERT INTO presensi.files(id, user_id, mime_type, size_bytes, sha256, storage_key)
        VALUES ($1, $2, 'image/png', 5242880, $3, $4)`, [id, users.quota.id, '0'.repeat(64), `${id}.png`]);
    }
    assert.equal((await upload('quota')).status, 413);
  });

  await t.test('file yang gagal dicatat dibersihkan; integritas dan path dicek saat download', async () => {
    const before = await readdir(directory);
    await database.query(`CREATE FUNCTION presensi.fail_file() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
      RAISE EXCEPTION 'simulated'; END $$;
      CREATE TRIGGER fail_file BEFORE INSERT ON presensi.files FOR EACH ROW EXECUTE FUNCTION presensi.fail_file();`);
    assert.equal((await upload('fileFail')).status, 503);
    assert.deepEqual(await readdir(directory), before);
    await database.query('DROP TRIGGER fail_file ON presensi.files; DROP FUNCTION presensi.fail_file();');
    const key = `${file.id}.png`;
    await writeFile(join(directory, key), Buffer.from('corrupt'));
    assert.equal((await fetch(`${origin}${file.download_path}`, { headers: { Authorization: `Bearer ${users.fileOwner.token}` } })).status, 503);
    await writeFile(join(directory, key), png);
    await database.query("UPDATE presensi.files SET storage_key = '../outside.png' WHERE id = $1", [file.id]);
    assert.equal((await fetch(`${origin}${file.download_path}`, { headers: { Authorization: `Bearer ${users.fileOwner.token}` } })).status, 503);
    await database.query('UPDATE presensi.files SET storage_key = $1 WHERE id = $2', [key, file.id]);
  });

  await t.test('hari libur hanya dikelola admin dan terlihat oleh peserta', async () => {
    const input = { tanggal: '2026-10-09', keterangan: 'Libur uji' };
    assert.equal((await api('other', '/api/admin/holidays', input)).status, 403);
    const result = await api('admin', '/api/admin/holidays', input);
    assert.equal(result.status, 201);
    assert.equal((await api('admin', '/api/admin/holidays', input)).status, 409);
    assert.equal((await api('other', '/api/holidays?from=2026-10-01&to=2026-10-31')).body.holidays.length, 1);
    assert.equal((await api('admin', `/api/admin/holidays/${result.body.holiday.id}`, undefined, 'DELETE')).status, 200);
  });

  await t.test('rekap JSON dan Excel hanya untuk admin, file XLSX dapat dibuka', async () => {
    assert.equal((await api('other', '/api/admin/rekap?month=10&year=2026')).status, 403);
    assert.equal((await api('admin', '/api/admin/rekap?month=13&year=2026')).status, 400);
    const json = await api('admin', '/api/admin/rekap?month=10&year=2026');
    assert.equal(json.status, 200);
    assert.equal(json.body.participants.length, 9);
    assert.ok(json.body.participants.every(person => person.profile.id !== users.admin.id));
    const response = await fetch(`${origin}/api/admin/rekap.xlsx?month=10&year=2026`, { headers: { Authorization: `Bearer ${users.admin.token}` } });
    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-disposition'), /rekap-presensi-2026-10.xlsx/);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(Buffer.from(await response.arrayBuffer()));
    assert.deepEqual(workbook.worksheets.map(sheet => sheet.name), ['Ringkasan', 'Detail harian', 'Keterangan']);
    assert.equal(workbook.getWorksheet('Ringkasan').getCell('B4').value, 'Nama');
    assert.equal(workbook.getWorksheet('Ringkasan').views[0].ySplit, 4);
    assert.ok(workbook.getWorksheet('Detail harian').autoFilter);
  });
});

test('rekap konsisten dengan aturan hari kerja, prioritas izin, WIB dan nilai string Excel', async () => {
  const name = '=HYPERLINK("https://example.com") ' + 'Nama panjang '.repeat(9);
  const report = buildReport({ month: 10, year: 2026, now: '2026-10-07T18:00:00Z',
    profiles: [{ id: 'one', nama_lengkap: name }],
    attendance: [
      { user_id: 'one', tanggal: '2026-10-01', jam_masuk: '2026-10-01T00:30:00Z', status: 'hadir' },
      { user_id: 'one', tanggal: '2026-10-02', jam_masuk: '2026-10-02T00:31:00Z', jam_pulang: '2026-10-02T09:00:00Z', status: 'hadir' },
      { user_id: 'one', tanggal: '2026-10-03', jam_masuk: '2026-10-03T00:00:00Z', status: 'hadir' },
      { user_id: 'one', tanggal: '2026-10-05', jam_masuk: '2026-10-05T00:00:00Z', status: 'hadir' },
      { user_id: 'one', tanggal: '2026-10-06', jam_masuk: null, status: 'hadir' },
    ],
    leaves: [
      { user_id: 'one', tanggal_mulai: '2026-10-01', tanggal_selesai: '2026-10-09', jenis: 'izin', status_persetujuan: 'disetujui' },
      { user_id: 'one', tanggal_mulai: '2026-10-06', tanggal_selesai: '2026-10-07', jenis: 'sakit', status_persetujuan: 'disetujui' },
      { user_id: 'one', tanggal_mulai: '2026-10-08', tanggal_selesai: '2026-10-08', jenis: 'sakit', status_persetujuan: 'menunggu' },
    ],
    holidays: [{ tanggal: '2026-10-05', keterangan: 'Libur' }],
  });
  const person = report.participants[0];
  assert.equal(person.days.length, 31);
  assert.equal(person.counts.hadir, 2);
  assert.equal(person.counts.terlambat, 1);
  assert.equal(person.counts.sakit, 2);
  assert.equal(person.counts.izin, 1);
  assert.equal(person.counts.total, 5);
  assert.equal(person.counts.alpha, 0);
  assert.equal(person.days[5].status, 'Sakit');
  assert.equal(person.days[8].dihitung, false);
  assert.match(person.days[0].catatan, /Belum ada jam pulang/);
  assert.equal(person.days[0].jam_masuk, '07:30');
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(await reportWorkbook(report));
  const cell = workbook.getWorksheet('Ringkasan').getCell('B5');
  assert.equal(cell.value, name);
  assert.notEqual(cell.type, ExcelJS.ValueType.Formula);
  assert.ok(workbook.getWorksheet('Ringkasan').getRow(5).height > 36);
  assert.equal(buildReport({ month: 2, year: 2028, profiles: [{ id: 'one', nama_lengkap: 'Test' }], attendance: [], leaves: [], holidays: [], now: '2028-02-29T03:00:00Z' }).participants[0].days.length, 29);
  const empty = buildReport({ month: 10, year: 2026, profiles: [], attendance: [], leaves: [], holidays: [], now: '2026-10-08T03:00:00Z' });
  const emptyBook = new ExcelJS.Workbook();
  await emptyBook.xlsx.load(await reportWorkbook(empty));
  assert.equal(emptyBook.getWorksheet('Ringkasan').rowCount, 4);
});

test('upgrade migrasi mempertahankan akun dan mengisi notifikasi pengajuan lama', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'presensi-migrations-test-'));
  const pg = new PGlite();
  await pg.waitReady;
  const database = {
    async query(sql, values) { return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values); },
    async connect() { return { query: database.query, release() {} }; },
  };
  t.after(async () => { await pg.close(); await unlink(join(directory, '001_initial.sql')); await rmdir(directory); });
  await writeFile(join(directory, '001_initial.sql'), await readFile(new URL('../migrations/001_initial.sql', import.meta.url)));
  await migrate(database, pathToFileURL(directory + sep));
  const create = async role => {
    const id = randomUUID();
    await database.query('INSERT INTO presensi.users(id, email, password_hash) VALUES ($1, $2, $3)', [id, `${id}@example.com`, 'test-hash']);
    await database.query('INSERT INTO presensi.profiles(id, nama_lengkap, role) VALUES ($1, $2, $3)', [id, role, role]);
    return id;
  };
  const admin = await create('admin');
  const user = await create('peserta');
  const pending = (await database.query(`INSERT INTO presensi.izin(user_id, tanggal_mulai, tanggal_selesai, jenis)
    VALUES ($1, '2026-10-08', '2026-10-08', 'izin') RETURNING id`, [user])).rows[0].id;
  await database.query(`INSERT INTO presensi.izin(user_id, tanggal_mulai, tanggal_selesai, jenis,
    status_persetujuan, disetujui_oleh, diproses_at) VALUES ($1, '2026-10-09', '2026-10-09', 'sakit',
    'disetujui', $2, '2026-10-08T05:00:00Z')`, [user, admin]);
  assert.deepEqual(await migrate(database), ['002_notifications_files.sql']);
  assert.deepEqual(await migrate(database), []);
  assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.users')).rows[0].n, 2);
  assert.equal((await database.query('SELECT count(*)::int AS n FROM presensi.notifications WHERE recipient_id = $1', [admin])).rows[0].n, 1);
  const result = (await database.query('SELECT * FROM presensi.notifications WHERE recipient_id = $1', [user])).rows[0];
  assert.equal(result.status, 'disetujui');
  assert.equal(new Date(result.created_at).toISOString(), '2026-10-08T05:00:00.000Z');
  const newAdmin = await create('admin');
  const notice = (await database.query('SELECT request_id FROM presensi.notifications WHERE recipient_id = $1', [newAdmin])).rows[0];
  assert.equal(notice.request_id, pending);
});
