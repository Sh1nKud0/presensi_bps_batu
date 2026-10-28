import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { HttpError } from './errors.js';

// A non-null, deliberately invalid hash also rejects password login on older API versions.
export const GOOGLE_PASSWORD_UNSET = '!google-only';

const derive = promisify(scrypt);
const options = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

export function validatePassword(password) {
  // Password tidak di-trim: spasi dapat merupakan bagian password yang sah.
  if (typeof password !== 'string' || password.length < 8 || Buffer.byteLength(password) > 256) {
    throw new HttpError(400, 'Password minimal 8 karakter dan maksimal 256 byte.');
  }
  return password;
}

export function normalizeEmail(email) {
  if (typeof email !== 'string') throw new HttpError(400, 'Email tidak valid.');
  const value = email.trim().toLowerCase();
  if (value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new HttpError(400, 'Email tidak valid.');
  }
  return value;
}

export async function hashPassword(password) {
  validatePassword(password);
  const salt = randomBytes(16).toString('hex');
  const key = await derive(password, salt, 64, options);
  return `scrypt$32768$8$1$${salt}$${key.toString('hex')}`;
}

export async function verifyPassword(password, encoded) {
  if (typeof password !== 'string' || Buffer.byteLength(password) > 256) return false;
  const parts = encoded?.split('$') ?? [];
  if (parts.length !== 6 || parts.slice(0, 4).join('$') !== 'scrypt$32768$8$1'
      || !/^[a-f0-9]{32}$/.test(parts[4]) || !/^[a-f0-9]{128}$/.test(parts[5])) return false;
  const key = await derive(password, parts[4], 64, options);
  return timingSafeEqual(key, Buffer.from(parts[5], 'hex'));
}

export function newToken() { return randomBytes(32).toString('base64url'); }
export function tokenHash(token) { return createHash('sha256').update(token).digest('hex'); }

export function bearerToken(request) {
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/i.exec(request.headers.authorization ?? '');
  if (!match) throw new HttpError(401, 'Silakan login terlebih dahulu.');
  return match[1];
}

// Batas percobaan per alamat koneksi. Tidak mempercayai X-Forwarded-For dari klien.
// Penyimpanan sementara ini untuk satu proses; multi-instance membutuhkan limiter bersama.
export function createRateLimiter({ max = 10, windowMs = 60000, now = Date.now } = {}) {
  const attempts = new Map();
  return key => {
    const time = now();
    for (const [address, entry] of attempts) if (entry.until <= time) attempts.delete(address);
    let entry = attempts.get(key);
    if (!entry) {
      if (attempts.size >= 5000) throw new HttpError(429, 'Terlalu banyak percobaan. Coba lagi nanti.');
      entry = { count: 0, until: time + windowMs };
      attempts.set(key, entry);
    }
    if (++entry.count > max) throw new HttpError(429, 'Terlalu banyak percobaan. Coba lagi satu menit lagi.');
  };
}
