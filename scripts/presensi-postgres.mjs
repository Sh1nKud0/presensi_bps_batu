// Local development against the SAME PostgreSQL schema used by Android.
// Credentials stay in the Android backend's ignored .env, outside Laravel.
import { readFile, readdir } from 'node:fs/promises';
import { parseEnv } from 'node:util';
import { createHash } from 'node:crypto';
import { useSharedFiles } from './lib/presensi-shared-files.mjs';

const backend = new URL('../../presensi_bps_batu/backend/', import.meta.url);
const args = new Set(process.argv.slice(2));
let database;
let server;
let stopping = false;

async function stop() {
    if (stopping) return;
    stopping = true;
    if (server?.listening) await new Promise(resolve => server.close(resolve));
    await database?.end();
}

try {
    if ([...args].some(arg => !['--check', '--migrate'].includes(arg))) throw new Error('Gunakan --check untuk pemeriksaan atau --migrate untuk menerapkan migrasi Google.');
    const backendEnv = parseEnv(await readFile(new URL('.env', backend), 'utf8'));
    const { readConfig } = await import(new URL('src/config.js', backend));
    const { createDatabase } = await import(new URL('src/database.js', backend));
    const { createApp } = await import(new URL('src/app.js', backend));
    const { migrate } = await import(new URL('src/migrate.js', backend));
    const clientIds = [...new Set([backendEnv.GOOGLE_CLIENT_IDS, process.env.PRESENSI_GOOGLE_CLIENT_ID].filter(Boolean).join(',').split(',').map(id => id.trim()).filter(Boolean))];
    if (!clientIds.length) throw new Error('Isi PRESENSI_GOOGLE_CLIENT_ID pada .env SIMASTA terlebih dahulu.');
    const config = readConfig({ ...backendEnv, GOOGLE_CLIENT_IDS: clientIds.join(',') });
    database = createDatabase({ ...config.database, application_name: 'presensi-web-google' });
    const info = (await database.query(`SELECT current_database() AS name,
        to_regclass('presensi.schema_migrations') IS NOT NULL AS has_migrations`)).rows[0];
    if (info.name !== config.database.database || !info.has_migrations) {
        throw new Error('Database harus memakai schema presensi dan riwayat migrasi backend Android yang sudah ada.');
    }
    const directory = new URL('migrations/', backend);
    const files = (await readdir(directory)).filter(name => /^\d+_[a-z_]+\.sql$/.test(name)).sort();
    const applied = new Map((await database.query('SELECT name, checksum FROM presensi.schema_migrations')).rows.map(row => [row.name, row.checksum]));
    if ([...applied.keys()].some(name => !files.includes(name))) throw new Error('Riwayat migrasi database tidak cocok dengan source backend.');
    const pending = [];
    for (const name of files) {
        const sql = (await readFile(new URL(name, directory), 'utf8')).replace(/\r\n/g, '\n');
        if (!applied.has(name)) pending.push(name);
        else if (applied.get(name) !== createHash('sha256').update(sql).digest('hex')) throw new Error(`Checksum migrasi ${name} tidak cocok; pemeriksaan dihentikan.`);
    }
    if (pending.some(name => !['003_google_identity.sql', '004_google_password_compatibility.sql'].includes(name))) throw new Error('Migrasi dasar backend belum lengkap. Periksa database yang dipilih sebelum melanjutkan.');
    if (args.has('--migrate')) {
        const changed = await migrate(database);
        console.log(changed.length ? `Migrasi selesai: ${changed.join(', ')}` : 'Migrasi Google sudah diterapkan.');
    } else if (pending.length) {
        throw new Error('Migrasi Google belum diterapkan. Jalankan node --env-file=.env scripts/presensi-postgres.mjs --migrate --check');
    }
    console.log(`PostgreSQL ${info.name}, schema presensi: terhubung.`);
    if (args.has('--check')) {
        await stop();
    } else {
        server = useSharedFiles(createApp({ database, googleClientIds: config.googleClientIds }),
            process.env.PRESENSI_SHARED_FILES_API_URL || 'https://apipresensi.bpskotabatu.com');
        await new Promise((resolve, reject) => {
            server.once('error', () => reject(new Error(`Port ${config.port} tidak tersedia. Hentikan backend lokal sebelumnya di terminalnya.`)));
            server.listen(config.port, '127.0.0.1', resolve);
        });
        for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => { void stop(); });
        console.log(`API Google + PostgreSQL bersama: http://127.0.0.1:${config.port}`);
        console.log('Akun, presensi, profil, dan sesi memakai database Android. Bukti memakai penyimpanan API hosting.');
        console.log('Biarkan tunnel SSH dan proses ini aktif. Buka http://localhost:8000/presensi.');
    }
} catch (error) {
    const connectionErrors = ['ECONNREFUSED', 'ETIMEDOUT', 'ENOTFOUND', '28P01', '28000'];
    console.error(connectionErrors.includes(error.code) ? 'PostgreSQL belum dapat dihubungi. Periksa tunnel SSH dan backend/.env.' : error.code === 'ENOENT' ? 'Source/backend .env Android belum ditemukan di direktori sebelah SIMASTA.' : error.message);
    process.exitCode = 1;
    await stop();
}
