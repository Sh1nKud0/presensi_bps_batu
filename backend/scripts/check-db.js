import { readConfig } from '../src/config.js';
import { createDatabase } from '../src/database.js';

let database;
try {
  database = createDatabase(readConfig().database);
  const result = await database.query(`
    SELECT current_database() AS database, current_user AS pengguna,
           to_char(now() AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD HH24:MI:SS') AS waktu_wib
  `);
  console.table(result.rows);
  console.log('Koneksi berhasil. Tidak ada tabel atau data yang diubah.');
} catch (error) {
  console.error('Pemeriksaan gagal. Periksa backend/.env dan pastikan tunnel SSH aktif.');
  if (error instanceof Error) console.error(`Detail: ${error.message}`);
  process.exitCode = 1;
} finally {
  if (database) await database.end();
}
