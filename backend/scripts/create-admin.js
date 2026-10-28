import { readConfig } from '../src/config.js';
import { createDatabase } from '../src/database.js';
import { createFirstAdmin } from '../src/auth.js';
import { HttpError } from '../src/errors.js';
import { promptCredentials } from './prompt.js';

let database;
try {
  const input = await promptCredentials({ admin: true });
  database = createDatabase(readConfig().database);
  const user = await createFirstAdmin(database, input);
  console.log(`Admin pertama berhasil dibuat: ${user.email}`);
} catch (error) {
  console.error(error instanceof HttpError ? error.message : 'Gagal membuat admin. Periksa konfigurasi, koneksi, dan migrasi.');
  process.exitCode = 1;
} finally {
  if (database) await database.end();
}
