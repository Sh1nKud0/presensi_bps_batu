import { createInterface } from 'node:readline/promises';
import { Writable } from 'node:stream';
import { HttpError } from '../src/errors.js';

export async function promptCredentials({ admin = false } = {}) {
  if (!process.stdin.isTTY) throw new HttpError(400, 'Jalankan perintah ini langsung di terminal interaktif.');
  let hidden = false;
  const output = new Writable({ write(chunk, encoding, done) {
    if (!hidden) process.stdout.write(chunk, encoding);
    done();
  } });
  const terminal = createInterface({ input: process.stdin, output, terminal: true });
  async function secret(label) {
    process.stdout.write(label);
    hidden = true;
    try { return await terminal.question(''); }
    finally { hidden = false; process.stdout.write('\n'); }
  }
  try {
    const email = await terminal.question(admin ? 'Email admin baru: ' : 'Email akun: ');
    const nama_lengkap = admin ? await terminal.question('Nama lengkap: ') : undefined;
    const password = await secret('Password aplikasi (tidak ditampilkan): ');
    if (admin && password !== await secret('Ulangi password: ')) {
      throw new HttpError(400, 'Konfirmasi password tidak sama.');
    }
    return { email, password, ...(admin ? { nama_lengkap } : {}) };
  } finally { terminal.close(); }
}
