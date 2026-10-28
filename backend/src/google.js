import { OAuth2Client } from 'google-auth-library';
import { timingSafeEqual } from 'node:crypto';
import { HttpError } from './errors.js';
import { createSession, insertUser, transaction } from './auth.js';
import { normalizeEmail, verifyPassword, newToken, tokenHash, GOOGLE_PASSWORD_UNSET } from './security.js';

export function googleClientIds(value = '') {
  const ids = [...new Set(value.split(',').map(part => part.trim()).filter(Boolean))];
  if (ids.some(id => !/^\d+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$/.test(id))) {
    throw new Error('GOOGLE_CLIENT_IDS harus berisi OAuth Client ID Google, dipisahkan koma.');
  }
  return ids;
}

export function createGoogleAuth(database, { clientIds = [], client = new OAuth2Client() } = {}) {
  function enabled() {
    if (!clientIds.length) throw new HttpError(503, 'Login Google belum diaktifkan pada layanan presensi.', 'google_unavailable');
  }
  return {
    configuration() { return { enabled: clientIds.length > 0 }; },
    async challenge(input) {
      enabled();
      if (Object.keys(input).length) throw new HttpError(400, 'Challenge tidak menerima kolom tambahan.');
      return transaction(database, async tx => {
        await tx.query('DELETE FROM presensi.google_challenges WHERE expires_at <= now()');
        const count = (await tx.query('SELECT count(*)::int AS count FROM presensi.google_challenges')).rows[0].count;
        if (count >= 5000) throw new HttpError(429, 'Terlalu banyak percobaan Google. Coba lagi nanti.');
        const nonce = newToken();
        const row = (await tx.query(`INSERT INTO presensi.google_challenges(nonce_hash, expires_at)
          VALUES ($1, now() + interval '5 minutes') RETURNING expires_at`, [tokenHash(nonce)])).rows[0];
        return { nonce, expires_at: row.expires_at };
      });
    },
    async login(input) {
      enabled();
      if (Object.keys(input).some(key => !['credential', 'nonce', 'existing_password'].includes(key))) {
        throw new HttpError(400, 'Ada kolom yang tidak diizinkan.');
      }
      if (typeof input.credential !== 'string' || input.credential.length > 12000 || input.credential.length < 20
          || typeof input.nonce !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(input.nonce)
          || (input.existing_password != null && (typeof input.existing_password !== 'string' || Buffer.byteLength(input.existing_password) > 256))) {
        throw new HttpError(400, 'Kredensial Google tidak valid.');
      }
      let payload;
      try {
        const ticket = await client.verifyIdToken({ idToken: input.credential, audience: clientIds });
        payload = ticket.getPayload();
        const now = Date.now() / 1000;
        if (!payload || typeof payload.sub !== 'string' || !payload.sub.length || payload.sub.length > 255
            || payload.email_verified !== true || typeof payload.email !== 'string'
            || !clientIds.includes(payload.aud) || !['accounts.google.com', 'https://accounts.google.com'].includes(payload.iss)
            || typeof payload.exp !== 'number' || payload.exp <= now
            || typeof payload.iat !== 'number' || payload.iat > now + 30
            || typeof payload.nonce !== 'string'
            || !timingSafeEqual(Buffer.from(tokenHash(payload.nonce)), Buffer.from(tokenHash(input.nonce)))) throw new Error();
      } catch {
        throw new HttpError(401, 'Identitas Google tidak dapat diverifikasi. Coba masuk dengan Google kembali.', 'google_invalid_credential');
      }
      const email = normalizeEmail(payload.email);
      try {
        return await transaction(database, async tx => {
          const challenge = (await tx.query(`SELECT nonce_hash FROM presensi.google_challenges
            WHERE nonce_hash = $1 AND expires_at > now() FOR UPDATE`, [tokenHash(input.nonce)])).rows[0];
          if (!challenge) throw new HttpError(401, 'Sesi Google sudah digunakan atau berakhir. Coba lagi.', 'google_challenge_expired');
          await tx.query("SELECT pg_advisory_xact_lock(hashtext('presensi:google:' || $1))", [payload.sub]);
          let row = (await tx.query(`SELECT u.id, u.email, u.password_hash, u.active, p.*
            FROM presensi.google_identities g JOIN presensi.users u ON u.id = g.user_id
            JOIN presensi.profiles p ON p.id = u.id WHERE g.subject = $1 FOR UPDATE OF u`, [payload.sub])).rows[0];
          if (!row) {
            row = (await tx.query(`SELECT u.id, u.email, u.password_hash, u.active, p.* FROM presensi.users u
              JOIN presensi.profiles p ON p.id = u.id WHERE u.email = $1 FOR UPDATE OF u`, [email])).rows[0];
            if (row) {
              if (!row.active) throw new HttpError(403, 'Akun presensi tidak aktif.');
              if (input.existing_password == null) throw new HttpError(409,
                'Email Google ini sudah memiliki akun presensi. Konfirmasikan kata sandi presensi untuk menghubungkan akun.', 'google_link_required');
              if (!row.password_hash || !await verifyPassword(input.existing_password, row.password_hash)) {
                throw new HttpError(401, 'Kata sandi presensi tidak sesuai. Akun belum dihubungkan.', 'google_password_incorrect');
              }
              if ((await tx.query('SELECT 1 FROM presensi.google_identities WHERE user_id = $1', [row.id])).rows.length) {
                throw new HttpError(409, 'Akun ini sudah terhubung ke akun Google lain. Gunakan akun Google tersebut.');
              }
            } else {
              const fullName = typeof payload.name === 'string' && payload.name.trim() ? payload.name.trim().slice(0, 150) : email.split('@')[0];
              row = await insertUser(tx, email, GOOGLE_PASSWORD_UNSET, fullName, 'peserta');
            }
            await tx.query('INSERT INTO presensi.google_identities(subject, user_id) VALUES ($1, $2)', [payload.sub, row.id]);
          }
          if (row.active === false) throw new HttpError(403, 'Akun presensi tidak aktif.');
          await tx.query('DELETE FROM presensi.google_challenges WHERE nonce_hash = $1', [tokenHash(input.nonce)]);
          return createSession(tx, row);
        });
      } catch (error) {
        if (error.code === '23505') throw new HttpError(409, 'Akun diperbarui bersamaan. Silakan coba lagi.', 'google_retry');
        throw error;
      }
    },
  };
}
