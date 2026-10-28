import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign } from 'node:crypto';
import { mkdtemp, copyFile, unlink, rmdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { OAuth2Client } from 'google-auth-library';
import { createApp } from '../src/app.js';
import { createAuth, createFirstAdmin } from '../src/auth.js';
import { createGoogleAuth, googleClientIds } from '../src/google.js';
import { createRateLimiter, tokenHash, hashPassword, verifyPassword, GOOGLE_PASSWORD_UNSET } from '../src/security.js';
import { migrate } from '../src/migrate.js';

const audience = '12345-web.apps.googleusercontent.com';
const key = generateKeyPairSync('rsa', { modulusLength: 2048 });
const wrongKey = generateKeyPairSync('rsa', { modulusLength: 2048 });
const client = new OAuth2Client();
client.getFederatedSignonCertsAsync = async () => ({ certs: { local: key.publicKey.export({ type: 'spki', format: 'pem' }) } });
function credential(nonce, claims = {}, signingKey = key.privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'local' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ sub: 'google-first', aud: audience, iss: 'https://accounts.google.com',
    email: 'google@example.test', email_verified: true, name: 'Google Peserta', iat: now, exp: now + 3600, nonce, ...claims })).toString('base64url');
  const body = `${header}.${payload}`;
  return `${body}.${sign('RSA-SHA256', Buffer.from(body), signingKey).toString('base64url')}`;
}

test('Google verification and shared-account lifecycle on temporary PostgreSQL', async t => {
  const pg = new PGlite(); await pg.waitReady;
  const database = {
    async query(sql, values) { return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values); },
    async connect() { return { query: database.query, release() {} }; },
  };
  await migrate(database);
  const auth = createAuth(database);
  const google = createGoogleAuth(database, { clientIds: [audience], client });
  const server = createApp({ database, googleAuth: google, rateLimit: createRateLimiter({ max: 200 }) });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => { await new Promise(resolve => server.close(resolve)); await pg.close(); });
  const origin = `http://127.0.0.1:${server.address().port}`;
  const api = async (path, body, token, method = 'POST') => {
    const response = await fetch(origin + path, { method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: method === 'GET' ? undefined : JSON.stringify(body ?? {}),
    });
    return { status: response.status, body: await response.json() };
  };
  const start = async () => {
    const result = await api('/api/auth/google/challenge', {}); assert.equal(result.status, 200); return result.body.nonce;
  };
  let first;
  await t.test('disabled configuration refuses Google without touching accounts', async () => {
    assert.deepEqual(googleClientIds(''), []);
    assert.deepEqual(googleClientIds(audience + ',' + audience), [audience]);
    assert.throws(() => googleClientIds('bad-client-id'));
    await assert.rejects(createGoogleAuth(database).challenge({}), error => error.status === 503);
    assert.equal((await api('/api/auth/google/config', undefined, undefined, 'GET')).body.enabled, true);
  });
  await t.test('invalid signature, audience, issuer, expiry, email and nonce are rejected', async () => {
    for (const [claims, signingKey] of [[{}, wrongKey.privateKey], [{ aud: 'wrong-client' }], [{ iss: 'https://attacker.example' }],
      [{ exp: Math.floor(Date.now() / 1000) - 1 }], [{ email_verified: false }], [{ nonce: 'different-nonce' }]]) {
      const nonce = await start();
      const result = await api('/api/auth/google', { nonce, credential: credential(nonce, claims, signingKey) });
      assert.equal(result.status, 401); assert.equal(result.body.code, 'google_invalid_credential');
    }
    assert.equal((await database.query('SELECT count(*)::int AS count FROM presensi.users')).rows[0].count, 0);
  });
  await t.test('first sign-in creates one participant and consumes the challenge', async () => {
    const nonce = await start();
    const jwt = credential(nonce);
    const result = await api('/api/auth/google', { nonce, credential: jwt });
    assert.equal(result.status, 200); first = result.body;
    assert.equal(first.user.role, 'peserta'); assert.equal(first.user.has_password, false);
    assert.equal((await auth.authenticate(first.access_token)).id, first.user.id);
    const stored = (await database.query('SELECT password_hash FROM presensi.users WHERE id=$1', [first.user.id])).rows[0];
    assert.equal(stored.password_hash, GOOGLE_PASSWORD_UNSET);
    // Compatibility with the deployed API's old nullable-hash timing fallback.
    const dummy = await hashPassword('dummy-password-for-timing-only');
    assert.equal(await verifyPassword('dummy-password-for-timing-only', stored.password_hash ?? dummy), false);
    const replay = await api('/api/auth/google', { nonce, credential: jwt });
    assert.equal(replay.status, 401); assert.equal(replay.body.code, 'google_challenge_expired');
    await assert.rejects(auth.login({ email: 'google@example.test', password: 'dummy-password-for-timing-only' }), error => error.status === 401);
  });
  await t.test('subject preserves user identity even when the Google email changes', async () => {
    const nonce = await start();
    const result = await api('/api/auth/google', { nonce, credential: credential(nonce, { email: 'changed@example.test' }) });
    assert.equal(result.status, 200); assert.equal(result.body.user.id, first.user.id);
    assert.equal((await database.query('SELECT count(*)::int AS count FROM presensi.users')).rows[0].count, 1);
  });
  await t.test('Google-only password setup still requires a recent session', async () => {
    await database.query("UPDATE presensi.sessions SET created_at=now()-interval '11 minutes' WHERE token_hash=$1", [tokenHash(first.access_token)]);
    const result = await api('/api/auth/password', { new_password: 'android-password' }, first.access_token);
    assert.equal(result.status, 401); assert.equal(result.body.code, 'google_recent_login_required');
    await database.query('UPDATE presensi.sessions SET created_at=now() WHERE token_hash=$1', [tokenHash(first.access_token)]);
  });
  await t.test('Google signup can set a password for Android after fresh login', async () => {
    const result = await api('/api/auth/password', { new_password: '  android-password  ' }, first.access_token);
    assert.equal(result.status, 200);
    const login = await auth.login({ email: 'google@example.test', password: '  android-password  ' });
    assert.equal(login.user.id, first.user.id); assert.equal(login.user.has_password, true);
    await assert.rejects(auth.authenticate(first.access_token), error => error.status === 401);
  });
  await t.test('existing admin cannot be silently linked by a matching Google email', async () => {
    const admin = await createFirstAdmin(database, { email: 'admin@example.test', password: '  admin-password  ', nama_lengkap: 'Existing Admin' });
    const nonce = await start(); const jwt = credential(nonce, { sub: 'google-admin', email: 'admin@example.test' });
    const request = { nonce, credential: jwt };
    const blocked = await api('/api/auth/google', request);
    assert.equal(blocked.status, 409); assert.equal(blocked.body.code, 'google_link_required');
    const wrong = await api('/api/auth/google', { ...request, existing_password: 'wrong-password' });
    assert.equal(wrong.status, 401);
    assert.equal((await database.query('SELECT count(*)::int AS count FROM presensi.google_identities WHERE user_id=$1', [admin.id])).rows[0].count, 0);
    const linked = await api('/api/auth/google', { ...request, existing_password: '  admin-password  ' });
    assert.equal(linked.status, 200); assert.equal(linked.body.user.id, admin.id); assert.equal(linked.body.user.role, 'admin');
    const next = await start();
    assert.equal((await api('/api/auth/google', { nonce: next, credential: credential(next, { sub: 'google-admin', email: 'admin@example.test' }) })).status, 200);
  });
  await t.test('inactive accounts and expired challenges cannot get sessions', async () => {
    const nonce = await start();
    await database.query('UPDATE presensi.google_challenges SET expires_at=now()-interval \'1 second\' WHERE nonce_hash=$1', [tokenHash(nonce)]);
    assert.equal((await api('/api/auth/google', { nonce, credential: credential(nonce) })).body.code, 'google_challenge_expired');
    await database.query('UPDATE presensi.users SET active=false WHERE id=$1', [first.user.id]);
    const other = await start();
    assert.equal((await api('/api/auth/google', { nonce: other, credential: credential(other) })).status, 403);
  });
});


test('migration 004 upgrades Google-only hashes without changing existing password accounts', async t => {
  const pg = new PGlite(); await pg.waitReady;
  const directory = await mkdtemp(join(tmpdir(), 'presensi-google-upgrade-'));
  const files = ['001_initial.sql', '002_notifications_files.sql', '003_google_identity.sql'];
  t.after(async () => { await pg.close(); for (const name of files) await unlink(join(directory, name)); await rmdir(directory); });
  const database = {
    async query(sql, values) { return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values); },
    async connect() { return { query: database.query, release() {} }; },
  };
  for (const name of files) await copyFile(new URL('../migrations/' + name, import.meta.url), join(directory, name));
  await migrate(database, pathToFileURL(directory + sep));
  const regularHash = await hashPassword('existing-password');
  await database.query('INSERT INTO presensi.users(email,password_hash) VALUES ($1,$2),($3,NULL)', ['regular@example.test', regularHash, 'google-upgrade@example.test']);
  assert.deepEqual(await migrate(database), ['004_google_password_compatibility.sql']);
  const rows = (await database.query('SELECT email,password_hash FROM presensi.users ORDER BY email')).rows;
  assert.equal(rows[0].password_hash, GOOGLE_PASSWORD_UNSET);
  assert.equal(rows[1].password_hash, regularHash);
  await assert.rejects(database.query('INSERT INTO presensi.users(email,password_hash) VALUES ($1,NULL)', ['null-rejected@example.test']), error => error.code === '23502');
});
