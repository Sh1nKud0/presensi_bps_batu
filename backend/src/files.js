import { mkdir, open, readFile, unlink } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID, createHash } from 'node:crypto';
import { HttpError } from './errors.js';
import { participantTransaction, uuid, fields, pagination } from './attendance.js';

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
export const defaultUploadDirectory = fileURLToPath(new URL('../data/private/', import.meta.url));
function imageType(buffer) {
  if (buffer.length >= 12 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff
      && buffer.at(-2) === 0xff && buffer.at(-1) === 0xd9) return ['image/jpeg', 'jpg'];
  if (buffer.length >= 33 && buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
      && buffer.subarray(12, 16).toString('ascii') === 'IHDR') return ['image/png', 'png'];
  if (buffer.length >= 20 && buffer.subarray(0, 4).toString('ascii') === 'RIFF'
      && buffer.subarray(8, 12).toString('ascii') === 'WEBP'
      && ['VP8 ', 'VP8L', 'VP8X'].includes(buffer.subarray(12, 16).toString('ascii'))) return ['image/webp', 'webp'];
  throw new HttpError(415, 'Bukti harus berupa gambar JPEG, PNG, atau WebP.');
}

export function createFiles(database, directory = defaultUploadDirectory) {
  const root = resolve(directory);
  return {
    async list(user, input) {
      fields(input, ['limit', 'offset']);
      const page = pagination(input);
      const rows = (await database.query(`SELECT id, mime_type, size_bytes, created_at FROM presensi.files
        WHERE user_id = $1 ORDER BY created_at DESC, id LIMIT $2 OFFSET $3`, [user.id, page.limit, page.offset])).rows;
      const used = (await database.query('SELECT coalesce(sum(size_bytes), 0)::bigint AS bytes FROM presensi.files WHERE user_id = $1', [user.id])).rows[0].bytes;
      return { files: rows.map(row => ({ ...row, download_path: `/api/files/${row.id}` })), used_bytes: Number(used),
        max_file_bytes: MAX_UPLOAD_BYTES, quota_bytes: 100 * 1024 * 1024, ...page };
    },
    async upload(user, buffer, contentType) {
      if (!Buffer.isBuffer(buffer) || !buffer.length || buffer.length > MAX_UPLOAD_BYTES) throw new HttpError(413, 'Bukti maksimal 5 MiB dan tidak boleh kosong.');
      const [mime, extension] = imageType(buffer);
      if (contentType !== mime) throw new HttpError(415, 'Content-Type tidak sesuai isi file.');
      const id = randomUUID();
      const key = `${id}.${extension}`;
      let written = false;
      let commitAttempted = false;
      try {
        return await participantTransaction(database, user.id, async client => {
          const total = (await client.query('SELECT coalesce(sum(size_bytes), 0)::bigint AS bytes FROM presensi.files WHERE user_id = $1', [user.id])).rows[0].bytes;
          if (Number(total) + buffer.length > 100 * 1024 * 1024) throw new HttpError(413, 'Kuota bukti akun sebesar 100 MiB telah tercapai.');
          await mkdir(root, { recursive: true, mode: 0o700 });
          // Nama selalu UUID server. Tidak menerima path/nama file dari pengguna.
          const handle = await open(join(root, key), 'wx', 0o600);
          written = true;
          try { await handle.writeFile(buffer); }
          finally { await handle.close(); }
          const row = (await client.query(`INSERT INTO presensi.files(id, user_id, mime_type, size_bytes, sha256, storage_key)
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, mime_type, size_bytes, created_at`,
          [id, user.id, mime, buffer.length, createHash('sha256').update(buffer).digest('hex'), key])).rows[0];
          commitAttempted = true;
          return { file: { ...row, download_path: `/api/files/${id}` } };
        });
      } catch (error) {
        // Jika hasil COMMIT tidak diketahui, pertahankan file agar referensi DB tidak rusak.
        // File tanpa metadata perlu dibersihkan saat pemeliharaan/backup.
        if (written && !commitAttempted) await unlink(join(root, key)).catch(() => {});
        throw error;
      }
    },
    async download(user, id) {
      id = uuid(id).toLowerCase();
      const row = (await database.query('SELECT * FROM presensi.files WHERE id = $1', [id])).rows[0];
      if (!row || (row.user_id !== user.id && user.role !== 'admin')) throw new HttpError(404, 'Bukti tidak ditemukan.');
      if (!new RegExp(`^${id}\\.(jpg|png|webp)$`).test(row.storage_key)) throw new HttpError(503, 'Metadata bukti tidak valid.');
      let buffer;
      try { buffer = await readFile(join(root, row.storage_key)); }
      catch { throw new HttpError(503, 'File bukti belum tersedia pada penyimpanan backend.'); }
      if (buffer.length !== row.size_bytes || createHash('sha256').update(buffer).digest('hex') !== row.sha256) throw new HttpError(503, 'Integritas bukti tidak sesuai.');
      return { buffer, mime: row.mime_type, filename: row.storage_key };
    },
  };
}
