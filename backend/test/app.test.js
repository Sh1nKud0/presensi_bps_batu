import assert from 'node:assert/strict';
import test from 'node:test';
import { createApp } from '../src/app.js';
import { readConfig } from '../src/config.js';

async function run(t, query) {
  const server = createApp({ database: { query } });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('health tetap tersedia saat database terputus; ready gagal tanpa membocorkan error', async t => {
  const url = await run(t, async () => { throw new Error('password=rahasia'); });
  assert.equal((await fetch(`${url}/health`)).status, 200);
  const response = await fetch(`${url}/ready`);
  assert.equal(response.status, 503);
  assert.doesNotMatch(await response.text(), /rahasia/);
});

test('ready memeriksa koneksi dengan query baca saja', async t => {
  const url = await run(t, async sql => assert.equal(sql, 'SELECT 1'));
  const response = await fetch(`${url}/ready`);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).database, 'connected');
});

test('endpoint tidak dikenal dan metode mutasi ditolak tanpa query database', async t => {
  const url = await run(t, () => assert.fail('Tidak boleh mengakses database'));
  assert.equal((await fetch(`${url}/absensi`)).status, 404);
  const response = await fetch(`${url}/ready`, { method: 'POST' });
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'GET');
});

test('konfigurasi menolak placeholder password dan port yang tidak valid', () => {
  assert.throws(() => readConfig({}), /PGDATABASE/);
  const env = { PGDATABASE: 'test', PGUSER: 'test', PGPASSWORD: 'ISI_PASSWORD_DATABASE' };
  assert.throws(() => readConfig(env), /PGPASSWORD/);
  env.PGPASSWORD = 'test';
  assert.throws(() => readConfig({ ...env, PORT: '0' }), /PORT/);
  assert.throws(() => readConfig({ ...env, PGPORT: 'abc' }), /PGPORT/);
  assert.equal(readConfig(env).database.port, 15432);
});
