import { HttpError } from './errors.js';
import { hashPassword, verifyPassword, normalizeEmail, validatePassword, newToken, tokenHash, GOOGLE_PASSWORD_UNSET } from './security.js';

function onlyFields(input, allowed) {
  if (Object.keys(input).some(key => !allowed.includes(key))) {
    throw new HttpError(400, 'Ada kolom yang tidak diizinkan.');
  }
}

function name(value) {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > 150) {
    throw new HttpError(400, 'Nama lengkap wajib diisi, maksimal 150 karakter.');
  }
  return value.trim();
}

function passwordConfigured(encoded) { return encoded != null && encoded !== GOOGLE_PASSWORD_UNSET; }

export function publicUser(row) {
  return {
    id: row.id, email: row.email, nama_lengkap: row.nama_lengkap,
    role: row.role, nim: row.nim ?? null, asal_instansi: row.asal_instansi ?? null,
    no_hp: row.no_hp ?? null, foto_profil_url: row.foto_profil_url ?? null,
    has_password: row.has_password ?? (row.password_hash === undefined || passwordConfigured(row.password_hash)),
  };
}

export async function transaction(database, work) {
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function insertUser(client, email, passwordHash, fullName, role) {
  const user = (await client.query(
    `INSERT INTO presensi.users(email, password_hash) VALUES ($1, $2) RETURNING id, email, (password_hash <> '!google-only') AS has_password`,
    [email, passwordHash],
  )).rows[0];
  const profile = (await client.query(`INSERT INTO presensi.profiles(id, nama_lengkap, role)
    VALUES ($1, $2, $3) RETURNING nama_lengkap, role`, [user.id, fullName, role])).rows[0];
  return publicUser({ ...user, ...profile });
}

export async function createSession(client, row) {
  const token = newToken();
  await client.query('DELETE FROM presensi.sessions WHERE user_id = $1 AND expires_at <= now()', [row.id]);
  const session = (await client.query(`INSERT INTO presensi.sessions(token_hash, user_id, expires_at)
    VALUES ($1, $2, now() + interval '7 days') RETURNING expires_at`, [tokenHash(token), row.id])).rows[0];
  return { access_token: token, token_type: 'Bearer', expires_at: session.expires_at, user: publicUser(row) };
}

export function createAuth(database) {
  // Hash dummy menghindari jalur verifikasi yang terlalu cepat untuk email tak terdaftar.
  let dummyHash;
  return {
    async register(input) {
      onlyFields(input, ['email', 'password', 'nama_lengkap']);
      const email = normalizeEmail(input.email);
      const fullName = name(input.nama_lengkap);
      const passwordHash = await hashPassword(input.password);
      try {
        const user = await transaction(database, client => insertUser(client, email, passwordHash, fullName, 'peserta'));
        return { user, message: 'Registrasi berhasil. Silakan login.' };
      } catch (error) {
        if (error.code === '23505') throw new HttpError(409, 'Email sudah terdaftar.');
        throw error;
      }
    },

    async login(input) {
      onlyFields(input, ['email', 'password']);
      const email = normalizeEmail(input.email);
      if (typeof input.password !== 'string' || Buffer.byteLength(input.password) > 256) {
        throw new HttpError(400, 'Password tidak valid.');
      }
      dummyHash ??= hashPassword('dummy-password-for-timing-only');
      const dummy = await dummyHash;
      return transaction(database, async client => {
        // Kunci user juga dipakai ganti password agar sesi baru tidak lolos pencabutan.
        const row = (await client.query(`SELECT u.id, u.email, u.password_hash, u.active, p.*
          FROM presensi.users u JOIN presensi.profiles p ON p.id = u.id
          WHERE u.email = $1 FOR UPDATE OF u`, [email])).rows[0];
        const matches = await verifyPassword(input.password, row?.password_hash ?? dummy);
        if (!row || !row.active || !passwordConfigured(row.password_hash) || !matches) throw new HttpError(401, 'Email atau password salah.');
        return createSession(client, row);
      });
    },

    async authenticate(token) {
      const row = (await database.query(`SELECT u.id, u.email, (u.password_hash <> '!google-only') AS has_password, p.*
        FROM presensi.sessions s JOIN presensi.users u ON u.id = s.user_id
        JOIN presensi.profiles p ON p.id = u.id
        WHERE s.token_hash = $1 AND s.expires_at > now() AND u.active = true`, [tokenHash(token)])).rows[0];
      if (!row) throw new HttpError(401, 'Sesi berakhir. Silakan login kembali.');
      return publicUser(row);
    },

    async logout(token) {
      await database.query('DELETE FROM presensi.sessions WHERE token_hash = $1', [tokenHash(token)]);
      return { message: 'Logout berhasil.' };
    },

    async updateProfile(user, input) {
      const allowed = ['nama_lengkap', 'nim', 'asal_instansi', 'no_hp'];
      onlyFields(input, allowed);
      const fields = Object.keys(input);
      if (!fields.length) throw new HttpError(400, 'Isi setidaknya satu kolom profil.');
      const values = fields.map(key => {
        if (key === 'nama_lengkap') return name(input[key]);
        if (input[key] === null) return null;
        if (typeof input[key] !== 'string' || input[key].length > 200) {
          throw new HttpError(400, `${key} maksimal 200 karakter.`);
        }
        return input[key].trim();
      });
      // Nama kolom berasal dari whitelist tetap, nilai selalu parameter SQL.
      const setters = fields.map((key, index) => `${key} = $${index + 1}`).join(', ');
      const row = (await database.query(`UPDATE presensi.profiles SET ${setters}
        WHERE id = $${fields.length + 1} RETURNING *`, [...values, user.id])).rows[0];
      return { user: publicUser({ ...row, email: user.email, has_password: user.has_password }) };
    },

    async changePassword(user, token, input) {
      onlyFields(input, ['current_password', 'new_password']);
      validatePassword(input.new_password);
      if ((user.has_password !== false || input.current_password != null)
          && (typeof input.current_password !== 'string' || Buffer.byteLength(input.current_password) > 256)) {
        throw new HttpError(400, 'Password saat ini tidak valid.');
      }
      const nextHash = await hashPassword(input.new_password);
      await transaction(database, async client => {
        const row = (await client.query('SELECT password_hash FROM presensi.users WHERE id = $1 FOR UPDATE', [user.id])).rows[0];
        const session = (await client.query(`SELECT (created_at > now() - interval '10 minutes') AS recent FROM presensi.sessions
          WHERE token_hash = $1 AND user_id = $2 AND expires_at > now()`, [tokenHash(token), user.id])).rows[0];
        if (!session) throw new HttpError(401, 'Sesi berakhir. Silakan login kembali.');
        if (!passwordConfigured(row?.password_hash) && !session.recent) {
          throw new HttpError(401, 'Masuk kembali dengan Google sebelum membuat kata sandi.', 'google_recent_login_required');
        }
        if (passwordConfigured(row?.password_hash) && !await verifyPassword(input.current_password, row?.password_hash)) {
          throw new HttpError(401, 'Password saat ini salah.');
        }
        await client.query('UPDATE presensi.users SET password_hash = $1 WHERE id = $2', [nextHash, user.id]);
        await client.query('DELETE FROM presensi.sessions WHERE user_id = $1', [user.id]);
      });
      return { message: 'Password diperbarui. Semua sesi dicabut; silakan login kembali.' };
    },

    async listUsers() {
      // Batas awal; pagination ditambahkan bersama manajemen peserta.
      const rows = (await database.query(`SELECT u.id, u.email, (u.password_hash <> '!google-only') AS has_password, p.* FROM presensi.users u
        JOIN presensi.profiles p ON p.id = u.id ORDER BY u.created_at DESC, u.id LIMIT 100`)).rows;
      return { users: rows.map(publicUser) };
    },
  };
}

export async function createFirstAdmin(database, input) {
  const email = normalizeEmail(input.email);
  const fullName = name(input.nama_lengkap);
  const passwordHash = await hashPassword(input.password);
  return transaction(database, async client => {
    await client.query("SELECT pg_advisory_xact_lock(hashtext('presensi:bootstrap-admin'))");
    if ((await client.query("SELECT 1 FROM presensi.profiles WHERE role = 'admin' LIMIT 1")).rows.length) {
      throw new HttpError(409, 'Admin sudah ada. Perintah ini hanya untuk membuat admin pertama.');
    }
    try {
      return await insertUser(client, email, passwordHash, fullName, 'admin');
    } catch (error) {
      if (error.code === '23505') throw new HttpError(409, 'Email sudah terdaftar. Gunakan email baru untuk admin pertama.');
      throw error;
    }
  });
}
