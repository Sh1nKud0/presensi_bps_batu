import { HttpError } from './errors.js';
import { fields, uuid, text, pagination, participantTransaction, noRequests } from './attendance.js';

async function attendanceRow(client, id, userId, requestId = null) {
  return (await client.query(`SELECT a.*, to_char(a.tanggal, 'YYYY-MM-DD') AS day,
    (a.jam_pulang AT TIME ZONE 'Asia/Jakarta')::time < time '16:00' AS early,
    (a.jam_pulang AT TIME ZONE 'Asia/Jakarta')::date = a.tanggal AS same_day,
    EXISTS (SELECT 1 FROM presensi.pembatalan_pulang r WHERE r.id = $3::uuid
      AND r.absensi_id = a.id AND r.jam_pulang_awal = a.jam_pulang) AS unchanged
    FROM presensi.absensi a WHERE a.id = $1 AND a.user_id = $2 FOR UPDATE OF a`, [id, userId, requestId])).rows[0];
}
function eligible(row, clock) {
  return row && row.day === clock.day && row.early && row.same_day
    && row.jam_masuk && row.jam_pulang && ['hadir', 'terlambat'].includes(row.status);
}

export function createCancellation(database) {
  return {
    async submit(user, input) {
      fields(input, ['absensi_id', 'alasan']);
      const id = uuid(input.absensi_id);
      const reason = text(input.alasan, 'Alasan', 5, 1000);
      return participantTransaction(database, user.id, async (client, clock) => {
        const row = await attendanceRow(client, id, user.id);
        if (!row) throw new HttpError(404, 'Presensi milik Anda tidak ditemukan.');
        if (!eligible(row, clock)) throw new HttpError(409, 'Hanya jam pulang hari ini yang tercatat sebelum 16.00 WIB yang dapat dibatalkan.');
        await noRequests(client, user.id, clock.day, clock.day);
        if ((await client.query("SELECT 1 FROM presensi.pembatalan_pulang WHERE absensi_id = $1 AND status_persetujuan = 'menunggu'", [id])).rows.length) {
          throw new HttpError(409, 'Pengajuan pembatalan masih menunggu keputusan admin.');
        }
        // Snapshot diambil langsung oleh PostgreSQL untuk mempertahankan presisi mikrodetik.
        const request = (await client.query(`INSERT INTO presensi.pembatalan_pulang
          (absensi_id, user_id, tanggal, jam_pulang_awal, alasan)
          SELECT id, user_id, tanggal, jam_pulang, $2 FROM presensi.absensi WHERE id = $1 RETURNING *`, [id, reason])).rows[0];
        return { request };
      });
    },

    async list(user, input, admin = false) {
      fields(input, ['status', 'limit', 'offset']);
      if (admin && user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      if (input.status && !['menunggu', 'disetujui', 'ditolak'].includes(input.status)) throw new HttpError(400, 'Status tidak valid.');
      const page = pagination(input);
      const requests = (await database.query(`SELECT r.*, p.nama_lengkap FROM presensi.pembatalan_pulang r
        JOIN presensi.profiles p ON p.id = r.user_id
        WHERE ($1::uuid IS NULL OR r.user_id = $1) AND ($2::text IS NULL OR r.status_persetujuan = $2)
        ORDER BY r.created_at DESC, r.id LIMIT $3 OFFSET $4`, [admin ? null : user.id, input.status ?? null, page.limit, page.offset])).rows;
      return { requests, ...page };
    },

    async decide(admin, id, input) {
      if (admin.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      uuid(id);
      fields(input, ['setujui', 'alasan_penolakan']);
      if (typeof input.setujui !== 'boolean') throw new HttpError(400, 'setujui harus boolean.');
      const reason = input.setujui ? null : text(input.alasan_penolakan, 'Alasan penolakan', 3, 1000);
      const initial = (await database.query('SELECT user_id FROM presensi.pembatalan_pulang WHERE id = $1', [id])).rows[0];
      if (!initial) throw new HttpError(404, 'Pengajuan tidak ditemukan.');
      return participantTransaction(database, initial.user_id, async (client, clock) => {
        const request = (await client.query('SELECT * FROM presensi.pembatalan_pulang WHERE id = $1 FOR UPDATE', [id])).rows[0];
        if (!request || request.user_id !== initial.user_id) throw new HttpError(409, 'Pengajuan telah berubah.');
        if (request.status_persetujuan !== 'menunggu') throw new HttpError(409, 'Pengajuan sudah diproses.');
        if (input.setujui) {
          const row = await attendanceRow(client, request.absensi_id, request.user_id, id);
          if (!eligible(row, clock) || !row.unchanged) throw new HttpError(409, 'Presensi telah berubah atau tanggal sudah lewat. Pengajuan dapat ditolak.');
          await noRequests(client, request.user_id, clock.day, clock.day);
          await client.query(`UPDATE presensi.absensi SET jam_pulang = NULL,
            latitude_pulang = NULL, longitude_pulang = NULL, foto_pulang_url = NULL WHERE id = $1`, [row.id]);
        }
        const result = (await client.query(`UPDATE presensi.pembatalan_pulang SET status_persetujuan = $1,
          disetujui_oleh = $2, diproses_at = $3, alasan_penolakan = $4 WHERE id = $5 RETURNING *`,
        [input.setujui ? 'disetujui' : 'ditolak', admin.id, clock.instant, reason, id])).rows[0];
        return { request: result };
      });
    },
  };
}
