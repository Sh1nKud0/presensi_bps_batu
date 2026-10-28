import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { readConfig } from '../src/config.js';
import { createDatabase } from '../src/database.js';

let database, client;
try {
  const config = readConfig();
  database = createDatabase(config.database);
  client = await database.connect();
  await client.query('BEGIN READ ONLY');
  const applied = new Map((await client.query('SELECT name, checksum FROM presensi.schema_migrations'))
    .rows.map(row => [row.name, row.checksum]));
  for (const name of ['003_google_identity.sql', '004_google_password_compatibility.sql']) {
    const sql = (await readFile(new URL('../migrations/' + name, import.meta.url), 'utf8')).replace(/\r\n/g, '\n');
    const checksum = createHash('sha256').update(sql).digest('hex');
    if (applied.get(name) !== checksum) throw new Error('Google schema is not ready.');
  }
  const schema = (await client.query(`SELECT to_regclass('presensi.google_identities') IS NOT NULL AS identities,
    to_regclass('presensi.google_challenges') IS NOT NULL AS challenges`)).rows[0];
  if (!schema.identities || !schema.challenges) throw new Error('Missing Google tables.');
  await client.query('ROLLBACK');
  console.log('Database siap: migrasi Google dan checksum sesuai. Tidak ada data yang diubah.');
  if (!config.googleClientIds.length) {
    console.error('GOOGLE_CLIENT_IDS belum diisi. Google tetap dinonaktifkan.');
    process.exitCode = 1;
  } else {
    console.log('OAuth client ID backend terkonfigurasi. Pemeriksaan ini tidak memvalidasi Google Cloud Console atau API hosting.');
  }
} catch {
  console.error('Pemeriksaan Google gagal. Periksa koneksi, konfigurasi, dan riwayat migrasi. Tidak ada migrasi yang dijalankan.');
  process.exitCode = 1;
} finally {
  if (client) { await client.query('ROLLBACK').catch(() => {}); client.release(); }
  if (database) await database.end();
}
