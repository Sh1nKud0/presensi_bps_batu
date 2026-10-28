import { readConfig } from '../src/config.js';
import { createDatabase } from '../src/database.js';
import { migrate } from '../src/migrate.js';

let database;
try {
  database = createDatabase(readConfig().database);
  const files = await migrate(database);
  console.log(files.length ? `Migrasi selesai: ${files.join(', ')}` : 'Database sudah menggunakan migrasi terbaru.');
} catch (error) {
  // Tidak mencetak detail koneksi atau query yang mungkin memuat data pribadi.
  console.error('Migrasi gagal; transaksi dibatalkan. Periksa koneksi, izin schema, dan riwayat migrasi.');
  if (error.message.startsWith('Schema presensi') || error.message.startsWith('Migrasi ')
      || error.message.startsWith('Riwayat migrasi')) console.error(error.message);
  process.exitCode = 1;
} finally {
  if (database) await database.end();
}
