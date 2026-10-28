import { readConfig } from './config.js';
import { createDatabase } from './database.js';
import { createApp } from './app.js';

try {
  const config = readConfig();
  const database = createDatabase(config.database);
  const server = createApp({ database, uploadDirectory: config.uploadDirectory, googleClientIds: config.googleClientIds });

  server.on('error', async () => {
    console.error('Backend gagal berjalan. Periksa apakah alamat dan port tersedia.');
    await database.end();
    process.exitCode = 1;
  });
  server.listen(config.port, config.host, () => {
    console.log(`Backend aktif di http://${config.host}:${config.port}`);
  });

  let stopping = false;
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      if (stopping) return;
      stopping = true;
      const timeout = setTimeout(() => process.exit(1), 10000);
      timeout.unref();
      server.close(async () => {
        await database.end();
        clearTimeout(timeout);
      });
    });
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
