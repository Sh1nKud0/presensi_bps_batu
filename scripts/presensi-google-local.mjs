// Development only: run the real Google verifier against a separate local database.
// This runner never reads backend/.env or connects to the hosted PostgreSQL server.
import { createRequire } from 'node:module';
import { spawn, spawnSync } from 'node:child_process';
import { mkdir, access } from 'node:fs/promises';
import { createServer } from 'node:net';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const backend = new URL('../../presensi_bps_batu/backend/', import.meta.url);
const directory = join(root, 'storage', 'app', 'private', 'presensi-google-local');
const args = process.argv.slice(2);
const apiOnly = args.includes('--api-only');
const phpExecutable = args.find(argument => !argument.startsWith('--')) || 'php';
const clientId = process.env.PRESENSI_GOOGLE_CLIENT_ID?.trim();
let pg;
let api;
let php;
let stopping = false;

async function stop() {
    if (stopping) return;
    stopping = true;
    php?.kill();
    if (api?.listening) await new Promise(resolve => api.close(resolve));
    await pg?.close();
}

try {
    if (!clientId || !/^\d+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$/.test(clientId)) {
        throw new Error('Isi PRESENSI_GOOGLE_CLIENT_ID di .env, lalu jalankan node --env-file=.env scripts/presensi-google-local.mjs');
    }
    if (!apiOnly && !process.env.APP_KEY) throw new Error('APP_KEY belum tersedia. Jalankan dari folder SIMASTA dengan --env-file=.env.');
    if (!apiOnly && spawnSync(phpExecutable, ['-v'], { windowsHide: true, stdio: 'ignore' }).status !== 0) {
        throw new Error('PHP belum ditemukan. Tambahkan path php.exe sebagai argumen terakhir pada perintah.');
    }
    if (!apiOnly) {
        await access(join(root, 'vendor', 'autoload.php'));
        await new Promise((resolve, reject) => {
            const probe = createServer();
            probe.once('error', () => reject(new Error('Port 8000 sedang dipakai. Gunakan --api-only jika php artisan serve sudah berjalan, atau hentikan server itu dengan Ctrl+C.')));
            probe.listen(8000, '127.0.0.1', () => probe.close(resolve));
        });
    }

    const requireBackend = createRequire(new URL('package.json', backend));
    const { PGlite } = requireBackend('@electric-sql/pglite');
    const { createApp } = await import(new URL('src/app.js', backend));
    const { migrate } = await import(new URL('src/migrate.js', backend));
    await mkdir(directory, { recursive: true });
    pg = new PGlite(join(directory, 'database'));
    await pg.waitReady;

    // Keep each BEGIN/COMMIT on the same exclusive connection while concurrent
    // dashboard requests wait; PGlite has one connection in this local runner.
    let queue = Promise.resolve();
    async function lock() {
        let release;
        const previous = queue;
        queue = new Promise(resolve => { release = resolve; });
        await previous;
        return release;
    }
    async function query(sql, values) {
        return values === undefined ? (await pg.exec(sql)).at(-1) ?? { rows: [] } : pg.query(sql, values);
    }
    const database = {
        async query(sql, values) {
            const release = await lock();
            try { return await query(sql, values); } finally { release(); }
        },
        async connect() { return { query, release: await lock() }; },
    };
    await migrate(database);
    api = createApp({ database, googleClientIds: [clientId], uploadDirectory: join(directory, 'uploads') });
    await new Promise((resolve, reject) => {
        api.once('error', () => reject(new Error('Port API lokal 5011 tidak tersedia. Hentikan runner uji sebelumnya lalu coba lagi.')));
        api.listen(5011, '127.0.0.1', resolve);
    });

    if (!apiOnly) {
        php = spawn(phpExecutable, ['-S', '127.0.0.1:8000', join(root, 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php')], {
            cwd: join(root, 'public'), windowsHide: true, stdio: ['ignore', 'inherit', 'inherit'],
            env: { ...process.env, APP_ENV: 'local', APP_DEBUG: 'false', APP_URL: 'http://localhost:8000',
                APP_CONFIG_CACHE: join(directory, 'unused-config.php'), APP_ROUTES_CACHE: join(directory, 'unused-routes.php'),
                PRESENSI_API_URL: 'http://127.0.0.1:5011', PRESENSI_STANDALONE: 'true', PRESENSI_LOCAL_TEST: 'true',
                SESSION_DRIVER: 'file', SESSION_COOKIE: 'presensi_google_local_session', SESSION_DOMAIN: 'null', SESSION_SECURE_COOKIE: 'false',
                CACHE_STORE: 'array', QUEUE_CONNECTION: 'sync', DB_CONNECTION: 'sqlite', DB_DATABASE: ':memory:' },
        });
        php.once('error', async () => { console.error('Server PHP gagal dijalankan.'); process.exitCode = 1; await stop(); });
        php.once('exit', async code => { if (!stopping) { process.exitCode = code || 0; await stop(); } });
    }
    for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => { void stop(); });
    console.log('Presensi uji Google: http://localhost:8000' + (apiOnly ? '/presensi' : ''));
    if (apiOnly) console.log('API aktif di 127.0.0.1:5011. Web yang sudah berjalan perlu PRESENSI_API_URL=http://127.0.0.1:5011 dan PRESENSI_LOCAL_TEST=true.');
    console.log('DATABASE UJI LOKAL TERPISAH. Data tidak masuk ke Android/hosting.');
    console.log('Google memakai verifikasi resmi. Tidak ada akun contoh yang dibuat.');
    console.log('Data uji tersimpan di storage/app/private/presensi-google-local. Ctrl+C untuk berhenti.');
} catch (error) {
    console.error(error.code === 'MODULE_NOT_FOUND' ? 'Dependensi backend belum terpasang. Jalankan npm ci di presensi_bps_batu/backend.' : error.message);
    process.exitCode = 1;
    await stop();
}
