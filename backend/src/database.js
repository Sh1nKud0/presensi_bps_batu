import pg from 'pg';

export function createDatabase(config) {
  const pool = new pg.Pool({
    ...config,
    // Kolom DATE merupakan tanggal kalender, bukan instant zona waktu mesin Node.
    types: {
      getTypeParser(oid, format) {
        return oid === 1082 && format !== 'binary' ? value => value : pg.types.getTypeParser(oid, format);
      },
    },
  });
  // Jangan mencetak connection string, password, atau rincian error PostgreSQL.
  pool.on('error', () => console.error('Koneksi PostgreSQL idle terputus.'));
  return pool;
}
