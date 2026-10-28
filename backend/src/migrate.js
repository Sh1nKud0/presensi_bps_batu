import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';

export async function migrate(database, directory = new URL('../migrations/', import.meta.url)) {
  const files = (await readdir(directory)).filter(name => /^\d+_[a-z_]+\.sql$/.test(name)).sort();
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT pg_advisory_xact_lock(hashtext('presensi:migrations'))");
    const state = (await client.query(`SELECT to_regnamespace('presensi') AS schema,
      to_regclass('presensi.schema_migrations') AS migrations`)).rows[0];
    if (state.schema && !state.migrations) {
      throw new Error('Schema presensi sudah ada tanpa riwayat migrasi. Periksa sebelum melanjutkan.');
    }
    await client.query('CREATE SCHEMA IF NOT EXISTS presensi');
    await client.query('REVOKE ALL ON SCHEMA presensi FROM PUBLIC');
    await client.query(`CREATE TABLE IF NOT EXISTS presensi.schema_migrations (
      name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now()
    )`);
    const applied = new Map((await client.query('SELECT name, checksum FROM presensi.schema_migrations'))
      .rows.map(row => [row.name, row.checksum]));
    if ([...applied.keys()].some(name => !files.includes(name))) {
      throw new Error('Riwayat migrasi database tidak cocok dengan file lokal.');
    }
    const changed = [];
    for (const name of files) {
      // Checksum tetap sama saat file dipindah antara Windows CRLF dan Linux LF.
      const sql = (await readFile(new URL(name, directory), 'utf8')).replace(/\r\n/g, '\n');
      const checksum = createHash('sha256').update(sql).digest('hex');
      if (applied.has(name)) {
        if (applied.get(name) !== checksum) throw new Error(`Migrasi ${name} berubah setelah dijalankan.`);
        continue;
      }
      await client.query(sql);
      await client.query('INSERT INTO presensi.schema_migrations(name, checksum) VALUES ($1, $2)', [name, checksum]);
      changed.push(name);
    }
    await client.query('COMMIT');
    return changed;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
