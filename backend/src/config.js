function port(value, fallback, name) {
  const text = value ?? String(fallback);
  const number = Number(text);
  if (!/^\d+$/.test(text) || !Number.isInteger(number) || number < 1 || number > 65535) {
    throw new Error(`${name} harus berupa port antara 1 dan 65535.`);
  }
  return number;
}

export function readConfig(env = process.env) {
  for (const name of ['PGDATABASE', 'PGUSER', 'PGPASSWORD']) {
    if (!env[name] || env[name] === 'ISI_PASSWORD_DATABASE') {
      throw new Error(`Isi ${name} di backend/.env terlebih dahulu.`);
    }
  }
  return {
    host: env.HOST || '127.0.0.1',
    port: port(env.PORT, 5010, 'PORT'),
    uploadDirectory: env.UPLOAD_DIR || undefined,
    database: {
      host: env.PGHOST || '127.0.0.1',
      port: port(env.PGPORT, 15432, 'PGPORT'),
      database: env.PGDATABASE,
      user: env.PGUSER,
      password: env.PGPASSWORD,
      max: 5,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      statement_timeout: 5000,
      application_name: 'presensi-bps-backend',
    },
  };
}
