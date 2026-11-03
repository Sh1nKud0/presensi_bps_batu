import { loadEnvFile } from 'node:process';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';
import { readFile, writeFile, rename, mkdir } from 'node:fs/promises';
import { normalizeCalendar, synchronizeCalendar, CALENDAR_SOURCE } from './lib/national-holidays.mjs';

const backend = resolve(process.env.PRESENSI_BACKEND_ROOT || '/home/bps/apps/presensi-backend');
const statusPath = fileURLToPath(new URL('../public/presensi-assets/calendar-status.json', import.meta.url));
const backupDir = process.env.PRESENSI_CALENDAR_BACKUP_DIR;
try {
    loadEnvFile(join(backend, '.env'));
    const { readConfig } = await import(pathToFileURL(join(backend, 'src/config.js')));
    const { createDatabase } = await import(pathToFileURL(join(backend, 'src/database.js')));
    const database = createDatabase(readConfig().database);
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jakarta', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
    const year = Number(today.slice(0, 4));
    let previous = {};
    try { previous = JSON.parse(await readFile(statusPath, 'utf8')); } catch {}
    const years = { ...(previous.years || {}) };
    let currentSuccess = false;
    try {
        if (backupDir) {
            await mkdir(backupDir, { recursive: true, mode: 0o700 });
            const backup = (await database.query('SELECT * FROM presensi.hari_libur ORDER BY tanggal')).rows;
            await writeFile(join(backupDir, `holidays-before-${Date.now()}.json`), JSON.stringify(backup), { mode: 0o600 });
        }
        for (const targetYear of [year, year + 1]) {
            try {
                const url = `https://raw.githubusercontent.com/ahrulsyamil/indonesian-holidays/main/data/holidays/${targetYear}.json`;
                const response = await fetch(url, { signal: AbortSignal.timeout(20000), redirect: 'error' });
                if (response.status === 404 && targetYear > year) { years[targetYear] = { available: false }; continue; }
                if (!response.ok) throw new Error('Sumber kalender tidak tersedia.');
                const data = await response.json();
                const rows = normalizeCalendar(data, targetYear);
                const client = await database.connect();
                let result;
                try { result = await synchronizeCalendar(client, rows, targetYear, today); } finally { client.release(); }
                years[targetYear] = { available: true, checked_at: new Date().toISOString(), source_updated: data.last_updated, count: rows.length };
                if (targetYear === year) currentSuccess = true;
                console.log(`Kalender ${targetYear}: ${result.count} tanggal, ${result.changed} diperbarui, ${result.removed} dihapus.`);
            } catch { console.error(`Sinkronisasi kalender ${targetYear} gagal; data tersimpan dipertahankan.`); }
        }
        const status = { source: CALENDAR_SOURCE, interval: 'hourly', checked_at: new Date().toISOString(), ok: currentSuccess, years };
        await writeFile(statusPath+'.tmp', JSON.stringify(status), { mode: 0o644 });
        await rename(statusPath+'.tmp', statusPath);
        if (!currentSuccess) process.exitCode = 1;
    } finally { await database.end(); }
} catch { console.error('Sinkronisasi kalender gagal. Periksa akses sumber dan PostgreSQL.'); process.exitCode = 1; }
