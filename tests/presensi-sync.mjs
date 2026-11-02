// Optional end-to-end check against the sibling Android backend and in-memory
// PostgreSQL. This never reads backend/.env or contacts the hosted BPS database.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { randomBytes, generateKeyPairSync, sign } from 'node:crypto';
import { mkdtemp, readdir, unlink, rmdir } from 'node:fs/promises';
import { join } from 'node:path';
import { todayWib, shiftDay } from '../public/presensi-assets/domain.js';
import { useSharedFiles } from '../scripts/lib/presensi-shared-files.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const backend = new URL('../../presensi_bps_batu/backend/', import.meta.url);
const requireBackend = createRequire(new URL('package.json', backend));
const { PGlite } = requireBackend('@electric-sql/pglite');
const { OAuth2Client } = requireBackend('google-auth-library');
const { createGoogleAuth } = await import(new URL('src/google.js', backend));
const { createApp } = await import(new URL('src/app.js', backend));
const { createFirstAdmin } = await import(new URL('src/auth.js', backend));
const { createRateLimiter } = await import(new URL('src/security.js', backend));
const { migrate } = await import(new URL('src/migrate.js', backend));
const pg = new PGlite();
await pg.waitReady;
const database = {
    async query(sql, values) { return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values); },
    async connect() { return { query: database.query, release() {} }; },
};
const uploadDirectory = await mkdtemp(join(root, 'storage', 'app', 'private', 'presensi-sync-'));
let php;
let server;
let androidServer;
const googleAudience = '12345-web.apps.googleusercontent.com';
const googleKey = generateKeyPairSync('rsa', { modulusLength: 2048 });
const googleVerifier = new OAuth2Client();
googleVerifier.getFederatedSignonCertsAsync = async () => ({ certs: { local: googleKey.publicKey.export({ type: 'spki', format: 'pem' }) } });
function googleCredential(nonce, email = 'new-google@sync.example', sub = 'google-sync-user') {
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', kid: 'local' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ aud: googleAudience, sub, email, email_verified: true, name: 'Google Sinkron',
        iss: 'https://accounts.google.com', iat: now, exp: now + 3600, nonce })).toString('base64url');
    const signed = `${header}.${payload}`;
    return `${signed}.${sign('RSA-SHA256', Buffer.from(signed), googleKey.privateKey).toString('base64url')}`;
}
try {
    await migrate(database);
    await createFirstAdmin(database, { email: 'admin@sync.example', password: 'sync-password123', nama_lengkap: 'Admin Sinkron' });
    androidServer = createApp({ database, uploadDirectory, rateLimit: createRateLimiter({ max: 200 }) });
    await new Promise(resolve => androidServer.listen(0, '127.0.0.1', resolve));
    const androidOrigin = `http://127.0.0.1:${androidServer.address().port}`;
    server = useSharedFiles(createApp({ database, uploadDirectory: join(uploadDirectory, 'web-must-not-create'), rateLimit: createRateLimiter({ max: 200 }),
        googleAuth: createGoogleAuth(database, { clientIds: [googleAudience], client: googleVerifier }) }), androidOrigin);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const apiOrigin = `http://127.0.0.1:${server.address().port}`;
    const webOrigin = 'http://127.0.0.1:8012';
    php = spawn(process.argv[2] ?? 'php', ['-S', '127.0.0.1:8012', join(root, 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php')], {
        cwd: join(root, 'public'), windowsHide: true, stdio: 'ignore',
        env: { ...process.env, PRESENSI_API_URL: apiOrigin, PRESENSI_STANDALONE: 'true', PRESENSI_GOOGLE_CLIENT_ID: googleAudience, APP_ENV: 'testing', APP_DEBUG: 'false',
            APP_KEY: `base64:${randomBytes(32).toString('base64')}`, APP_URL: webOrigin, SESSION_DRIVER: 'file',
            CACHE_STORE: 'array', DB_CONNECTION: 'sqlite', DB_DATABASE: ':memory:' },
    });
    php.on('error', error => { console.error('PHP could not start:', error.message); });
    for (let attempt = 0; attempt < 100; attempt++) {
        try { if ((await fetch(webOrigin + '/presensi')).ok) break; } catch { /* Server startup. */ }
        if (attempt === 99) throw new Error('Local PHP check server did not start.');
        await new Promise(resolve => setTimeout(resolve, 50));
    }
    async function android(path, { body, token, method = body ? 'POST' : 'GET' } = {}) {
        const response = await fetch(androidOrigin + '/api/' + path, { method, headers: {
            Accept: 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...(body ? { 'Content-Type': 'application/json' } : {}),
        }, body: body ? JSON.stringify(body) : undefined });
        const data = await response.json();
        assert.ok(response.ok, `Android API ${path}: ${response.status} ${data.error ?? ''}`);
        return data;
    }
    const cookies = new Map(); let csrf;
    function remember(response) {
        for (const cookie of response.headers.getSetCookie()) { const part = cookie.split(';')[0]; const index = part.indexOf('='); cookies.set(part.slice(0, index), part.slice(index + 1)); }
    }
    const shell = await fetch(webOrigin + '/'); remember(shell);
    const loginHtml = await shell.text();
    assert.ok(loginHtml.includes('Presensi Magang | BPS Kota Batu'));
    assert.ok(!loginHtml.includes('Masuk SIMASTA'));
    assert.equal((await fetch(webOrigin + '/admin/dashboard')).status, 404, 'Standalone deploy must not expose SIMASTA routes.');
    const registerHtml = await (await fetch(webOrigin + '/register')).text();
    assert.ok(registerHtml.includes('data-auth-mode="register"'));
    csrf = loginHtml.match(/name="csrf-token" content="([^"]+)"/)[1];
    const blocked = await fetch(webOrigin + '/presensi/api/auth/register', { method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json',
            Cookie: [...cookies].map(([key, value]) => `${key}=${value}`).join('; ') },
        body: JSON.stringify({ email: 'blocked@sync.example', password: 'sync-password123', nama_lengkap: 'Blocked' }),
    });
    assert.equal(blocked.status, 419, 'Writes without the CSRF token must be blocked.');
    async function web(path, { method = 'GET', body, bytes, mime, binary = false, status } = {}) {
        const response = await fetch(webOrigin + '/presensi/api/' + path, { method, headers: {
            Accept: 'application/json', Cookie: [...cookies].map(([key, value]) => `${key}=${value}`).join('; '),
            'X-CSRF-TOKEN': csrf, ...(!['GET', 'HEAD'].includes(method) ? { 'Content-Type': mime ?? 'application/json' } : {}),
        }, body: ['GET', 'HEAD'].includes(method) ? undefined : bytes ?? JSON.stringify(body ?? {}) });
        remember(response);
        if (status) { assert.equal(response.status, status); return response.json().catch(() => null); }
        if (binary && response.ok) return Buffer.from(await response.arrayBuffer());
        const data = await response.json();
        assert.ok(response.ok, `Laravel ${path}: ${response.status} ${data.error ?? data.message ?? ''}`);
        if (data.csrf_token) csrf = data.csrf_token;
        return data;
    }
    const credentials = { email: 'peserta@sync.example', password: '  sync-password123  ' };
    await web('auth/register', { method: 'POST', body: { ...credentials, nama_lengkap: 'Peserta Sinkron' } });
    const androidSession = await android('auth/login', { body: credentials });
    const webSession = await web('auth/login', { method: 'POST', body: credentials });
    assert.equal(webSession.user.id, androidSession.user.id);
    assert.equal(webSession.access_token, undefined);
    await web('me', { method: 'PATCH', body: { nama_lengkap: 'Diubah melalui web', nim: 'SYNC-123' } });
    assert.equal((await android('me', { token: androidSession.access_token })).user.nama_lengkap, 'Diubah melalui web');
    await android('me', { method: 'PATCH', token: androidSession.access_token, body: { asal_instansi: 'Diubah melalui Android' } });
    assert.equal((await web('me')).user.asal_instansi, 'Diubah melalui Android');
    await web('admin/participants', { status: 403 });

    const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNXkAAAAASUVORK5CYII=', 'base64');
    const { file } = await web('files', { method: 'POST', bytes: image, mime: 'image/png' });
    const proof = await fetch(`${androidOrigin}/api/files/${file.id}`, { headers: { Authorization: `Bearer ${androidSession.access_token}` } });
    assert.equal(proof.status, 200); assert.deepEqual(Buffer.from(await proof.arrayBuffer()), image);
    assert.deepEqual(await web(`files/${file.id}`, { binary: true }), image);
    const tomorrow = shiftDay(todayWib(), 1);
    const { request } = await web('requests/izin', { method: 'POST', body: { tanggal_mulai: tomorrow,
        tanggal_selesai: tomorrow, jenis: 'izin', keterangan: 'Pengujian sinkron lokal', bukti_id: file.id } });
    const admin = await android('auth/login', { body: { email: 'admin@sync.example', password: 'sync-password123' } });
    const queue = await android('admin/requests/izin', { token: admin.access_token });
    assert.ok(queue.requests.some(row => row.id === request.id));
    await android(`admin/requests/izin/${request.id}/decision`, { token: admin.access_token, body: { setujui: true } });
    assert.equal((await web('requests/izin')).requests[0].status_persetujuan, 'disetujui');
    const notifications = await web('notifications');
    assert.ok(notifications.unread_count > 0);
    await web('notifications/read', { method: 'PATCH', body: { ids: notifications.notifications.map(row => row.id) } });
    assert.equal((await android('notifications', { token: androidSession.access_token })).unread_count, 0);
    await web('auth/logout', { method: 'POST' });
    await web('me', { status: 401 });
    assert.equal((await android('me', { token: androidSession.access_token })).user.nim, 'SYNC-123');
    await web('auth/login', { method: 'POST', body: { email: 'admin@sync.example', password: 'sync-password123' } });
    assert.ok((await web('admin/participants')).participants.some(person => person.id === androidSession.user.id));
    const period = todayWib();
    const excel = await web(`admin/rekap.xlsx?month=${Number(period.slice(5, 7))}&year=${period.slice(0, 4)}`, { binary: true });
    assert.equal(excel.subarray(0, 2).toString(), 'PK');
    await web('auth/logout', { method: 'POST' });
    const challenge = await web('auth/google/challenge', { method: 'POST' });
    assert.equal(challenge.client_id, googleAudience);
    const googleUser = await web('auth/google', { method: 'POST', body: { credential: googleCredential(challenge.nonce) } });
    assert.equal(googleUser.access_token, undefined); assert.equal(googleUser.user.has_password, false);
    assert.equal(googleUser.user.role, 'peserta');
    await web('auth/password', { method: 'POST', body: { new_password: ' Google Android password ' } });
    const googleAndroid = await android('auth/login', { body: { email: 'new-google@sync.example', password: ' Google Android password ' } });
    assert.equal(googleAndroid.user.id, googleUser.user.id);
    const linkChallenge = await web('auth/google/challenge', { method: 'POST' });
    const linkCredential = googleCredential(linkChallenge.nonce, credentials.email, 'google-existing-sync');
    const linkNeeded = await web('auth/google', { method: 'POST', body: { credential: linkCredential }, status: 409 });
    assert.equal(linkNeeded.code, 'google_link_required');
    const linked = await web('auth/google', { method: 'POST', body: { credential: linkCredential, existing_password: credentials.password } });
    assert.equal(linked.user.id, androidSession.user.id);
    console.log(JSON.stringify({ status: 'passed', database: 'in-memory PostgreSQL', verified: [
        'standalone login and registration', 'SIMASTA routes excluded', 'shared account identity', 'password spaces', 'CSRF rejection and cookie rotation', 'profile web to Android', 'profile Android to web',
        'participant admin denial', 'shared private image', 'web request to Android admin', 'Android decision to web participant',
        'notification read status across clients', 'web logout preserves Android session', 'admin Excel download',
        'signed Google registration through Laravel', 'Google account password usable on Android', 'existing account linking preserves identity',
        'shared file storage between local Google API and Android hosting',
    ] }));
} finally {
    if (php && php.exitCode === null) { php.kill(); await new Promise(resolve => php.once('exit', resolve)); }
    if (server) await new Promise(resolve => server.close(resolve));
    if (androidServer) await new Promise(resolve => androidServer.close(resolve));
    await pg.close();
    // Only immediate files in the fresh directory created by this script.
    for (const file of await readdir(uploadDirectory)) await unlink(join(uploadDirectory, file));
    await rmdir(uploadDirectory);
}
