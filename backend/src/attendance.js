import { HttpError } from './errors.js';

const DAY = 86400000;
const office = { latitude: -7.8668, longitude: 112.5073, radius: 100 };
const kinds = { izin: 'izin', susulan: 'absen_susulan' };

function fields(input, allowed) {
  if (Object.keys(input).some(key => !allowed.includes(key))) throw new HttpError(400, 'Ada kolom yang tidak diizinkan.');
}
function date(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)
      || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) {
    throw new HttpError(400, 'Tanggal harus valid dalam format YYYY-MM-DD.');
  }
  return value;
}
function text(value, label, min = 1, max = 2000) {
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) {
    throw new HttpError(400, `${label} harus ${min}–${max} karakter.`);
  }
  return value.trim();
}
function time(value) {
  if (value == null) return null;
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value)) {
    throw new HttpError(400, 'Jam harus valid dalam format HH:mm atau HH:mm:ss.');
  }
  return value.length === 5 ? `${value}:00` : value;
}
function evidence(value) {
  if (value == null) return null;
  try {
    const url = new URL(value);
    if (typeof value !== 'string' || value.length > 2048 || url.protocol !== 'https:' || url.username || url.password) throw new Error();
    return value;
  } catch { throw new HttpError(400, 'Alamat bukti harus berupa URL HTTPS yang valid.'); }
}
function table(kind) {
  if (!Object.hasOwn(kinds, kind)) throw new HttpError(404, 'Jenis pengajuan tidak ditemukan.');
  return kinds[kind];
}
function uuid(value) {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new HttpError(400, 'ID pengajuan tidak valid.');
  }
  return value;
}
function range(start, end, maxDays = 366) {
  date(start); date(end);
  if (end < start || Date.parse(end) - Date.parse(start) >= maxDays * DAY) {
    throw new HttpError(400, `Rentang tanggal harus berurutan, maksimal ${maxDays} hari.`);
  }
}
function shift(day, offset) { return new Date(Date.parse(day) + offset * DAY).toISOString().slice(0, 10); }

export async function serverClock(client) {
  // Dibaca setelah lock untuk menghindari penggunaan jam lama saat melewati tengah malam.
  const row = (await client.query(`WITH clock AS (SELECT clock_timestamp() AS instant)
    SELECT instant, to_char(instant AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD') AS day FROM clock`)).rows[0];
  return { instant: new Date(row.instant), day: row.day };
}

export function distanceMeters(latitude, longitude) {
  const rad = Math.PI / 180;
  const a = Math.sin((latitude - office.latitude) * rad / 2) ** 2
    + Math.cos(office.latitude * rad) * Math.cos(latitude * rad)
    * Math.sin((longitude - office.longitude) * rad / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
}

function location(input, clock) {
  fields(input, ['latitude', 'longitude', 'accuracy', 'captured_at', 'is_mocked']);
  if (typeof input.latitude !== 'number' || !Number.isFinite(input.latitude) || Math.abs(input.latitude) > 90
      || typeof input.longitude !== 'number' || !Number.isFinite(input.longitude) || Math.abs(input.longitude) > 180
      || typeof input.accuracy !== 'number' || !Number.isFinite(input.accuracy) || input.accuracy <= 0) {
    throw new HttpError(400, 'Koordinat dan akurasi lokasi tidak valid.');
  }
  if (input.is_mocked != null && typeof input.is_mocked !== 'boolean') throw new HttpError(400, 'Penanda lokasi tiruan tidak valid.');
  if (input.is_mocked === true) throw new HttpError(400, 'Lokasi tiruan tidak dapat digunakan.');
  if (input.accuracy > 50) throw new HttpError(400, 'Akurasi GPS belum cukup. Ambil ulang lokasi.');
  if (typeof input.captured_at !== 'string' || !/(Z|[+-]\d{2}:\d{2})$/.test(input.captured_at)) {
    throw new HttpError(400, 'Waktu pengambilan lokasi harus menyertakan zona waktu.');
  }
  const age = clock.instant.getTime() - Date.parse(input.captured_at);
  if (!Number.isFinite(age) || age < -30000 || age > 120000) throw new HttpError(400, 'Lokasi sudah kedaluwarsa atau jam perangkat tidak sesuai. Ambil ulang lokasi.');
  const distance = distanceMeters(input.latitude, input.longitude);
  if (distance > office.radius) throw new HttpError(400, 'Anda berada di luar radius presensi kantor.');
  return { latitude: input.latitude, longitude: input.longitude, distance };
}

export async function participantTransaction(database, userId, work) {
  const client = await database.connect();
  try {
    await client.query('BEGIN');
    // Semua perubahan presensi/pengajuan user yang sama memakai kunci ini.
    // Mengunci profile yang selalu ada juga melindungi tanggal tanpa baris absensi.
    const profile = (await client.query('SELECT id FROM presensi.profiles WHERE id = $1 FOR UPDATE', [userId])).rows[0];
    if (!profile) throw new HttpError(404, 'Peserta tidak ditemukan.');
    const result = await work(client, await serverClock(client));
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    if (error.code === '23505') throw new HttpError(409, 'Data tanggal tersebut sudah tercatat.');
    throw error;
  } finally { client.release(); }
}

async function noAttendance(client, userId, start, end) {
  if ((await client.query(`SELECT 1 FROM presensi.absensi
    WHERE user_id = $1 AND tanggal BETWEEN $2::date AND $3::date LIMIT 1`, [userId, start, end])).rows.length) {
    throw new HttpError(409, 'Presensi pada tanggal yang dipilih sudah tercatat dan tidak dapat diganti izin/susulan.');
  }
}
export async function noRequests(client, userId, start, end, exclude = {}) {
  const leave = (await client.query(`SELECT 1 FROM presensi.izin WHERE user_id = $1
    AND tanggal_mulai <= $3::date AND tanggal_selesai >= $2::date
    AND status_persetujuan IN ('menunggu', 'disetujui') AND ($4::uuid IS NULL OR id <> $4::uuid) LIMIT 1`,
  [userId, start, end, exclude.kind === 'izin' ? exclude.id : null])).rows;
  const correction = (await client.query(`SELECT 1 FROM presensi.absen_susulan WHERE user_id = $1
    AND tanggal BETWEEN $2::date AND $3::date AND status_persetujuan IN ('menunggu', 'disetujui')
    AND ($4::uuid IS NULL OR id <> $4::uuid) LIMIT 1`,
  [userId, start, end, exclude.kind === 'susulan' ? exclude.id : null])).rows;
  if (leave.length || correction.length) throw new HttpError(409, 'Tanggal tersebut sudah memiliki pengajuan aktif.');
}
async function holiday(client, day) {
  const weekday = new Date(day).getUTCDay();
  if (weekday === 0 || weekday === 6) return 'Akhir pekan';
  return (await client.query('SELECT keterangan FROM presensi.hari_libur WHERE tanggal = $1', [day])).rows[0]?.keterangan ?? null;
}
function submittedInstant(day, timeOfDay) {
  return timeOfDay == null ? null : new Date(`${day}T${timeOfDay}+07:00`);
}
function attendanceStatus(instant, day, special = false) {
  return special ? 'dispensasi' : instant > submittedInstant(day, '07:30:00') ? 'terlambat' : 'hadir';
}
function pagination(input) {
  const limit = input.limit ?? '50';
  const offset = input.offset ?? '0';
  if (!/^\d+$/.test(String(limit)) || !/^\d+$/.test(String(offset))
      || Number(limit) < 1 || Number(limit) > 100 || !Number.isSafeInteger(Number(offset)) || Number(offset) > 1000000) {
    throw new HttpError(400, 'Pagination tidak valid: limit 1–100 dan offset 0–1000000.');
  }
  return { limit: Number(limit), offset: Number(offset) };
}

export function createAttendance(database) {
  return {
    async today(user) {
      const clock = await serverClock(database);
      const attendance = (await database.query('SELECT * FROM presensi.absensi WHERE user_id = $1 AND tanggal = $2', [user.id, clock.day])).rows[0] ?? null;
      const dayOff = await holiday(database, clock.day);
      let requestBlock = null;
      try { await noRequests(database, user.id, clock.day, clock.day); }
      catch (error) { if (!(error instanceof HttpError)) throw error; requestBlock = error.message; }
      const blocked = dayOff || requestBlock || (attendance?.jam_pulang ? 'Presensi hari ini sudah selesai.'
        : attendance && (!attendance.jam_masuk || !['hadir', 'terlambat'].includes(attendance.status)) ? 'Data presensi hari ini sudah tercatat.' : null);
      return { tanggal: clock.day, waktu_server: clock.instant, attendance,
        hari_libur: dayOff, block_reason: blocked, request_block_reason: requestBlock, can_check_in: !blocked && !attendance,
        can_check_out: !blocked && Boolean(attendance?.jam_masuk) };
    },

    async checkIn(user, input) {
      return participantTransaction(database, user.id, async (client, clock) => {
        const point = location(input, clock);
        if (await holiday(client, clock.day)) throw new HttpError(409, 'Hari ini libur, presensi tidak diperlukan.');
        await noAttendance(client, user.id, clock.day, clock.day);
        await noRequests(client, user.id, clock.day, clock.day);
        const row = (await client.query(`INSERT INTO presensi.absensi
          (user_id, tanggal, jam_masuk, latitude_masuk, longitude_masuk, jarak_dari_kantor_meter, status)
          VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [user.id, clock.day, clock.instant, point.latitude, point.longitude, point.distance, attendanceStatus(clock.instant, clock.day)])).rows[0];
        return { attendance: row };
      });
    },

    async checkOut(user, input) {
      return participantTransaction(database, user.id, async (client, clock) => {
        const point = location(input, clock);
        if (await holiday(client, clock.day)) throw new HttpError(409, 'Hari ini libur, presensi tidak diperlukan.');
        await noRequests(client, user.id, clock.day, clock.day);
        const existing = (await client.query('SELECT * FROM presensi.absensi WHERE user_id = $1 AND tanggal = $2 FOR UPDATE', [user.id, clock.day])).rows[0];
        if (!existing?.jam_masuk) throw new HttpError(409, 'Anda belum melakukan presensi masuk hari ini.');
        if (existing.jam_pulang) throw new HttpError(409, 'Jam pulang sudah tercatat.');
        if (!['hadir', 'terlambat'].includes(existing.status)) throw new HttpError(409, 'Data presensi hari ini tidak dapat diubah.');
        const row = (await client.query(`UPDATE presensi.absensi SET jam_pulang = $1,
          latitude_pulang = $2, longitude_pulang = $3 WHERE id = $4 RETURNING *`,
        [clock.instant, point.latitude, point.longitude, existing.id])).rows[0];
        return { attendance: row };
      });
    },

    async history(user, input) {
      fields(input, ['from', 'to', 'limit', 'offset']);
      const clock = await serverClock(database);
      const from = input.from ?? shift(clock.day, -30), to = input.to ?? clock.day;
      range(from, to);
      const page = pagination(input);
      const rows = (await database.query(`SELECT * FROM presensi.absensi WHERE user_id = $1
        AND tanggal BETWEEN $2::date AND $3::date ORDER BY tanggal DESC LIMIT $4 OFFSET $5`,
      [user.id, from, to, page.limit, page.offset])).rows;
      return { attendance: rows, ...page };
    },

    async submit(user, kind, input) {
      const target = table(kind);
      fields(input, kind === 'izin' ? ['tanggal_mulai', 'tanggal_selesai', 'jenis', 'keterangan', 'bukti_url', 'bukti_id']
        : ['tanggal', 'jam_masuk_diajukan', 'jam_pulang_diajukan', 'jenis_alasan', 'keterangan', 'bukti_url', 'bukti_id']);
      const start = date(kind === 'izin' ? input.tanggal_mulai : input.tanggal);
      const end = kind === 'izin' ? date(input.tanggal_selesai) : start;
      range(start, end, 98);
      const description = text(input.keterangan, 'Keterangan');
      const proof = evidence(input.bukti_url);
      const proofId = input.bukti_id == null ? null : uuid(input.bukti_id);
      if (proof && proofId) throw new HttpError(400, 'Gunakan bukti_id atau bukti_url, bukan keduanya.');
      if (kind === 'izin' && !['izin', 'sakit'].includes(input.jenis)) throw new HttpError(400, 'Jenis izin tidak valid.');
      if (kind === 'susulan' && !['dispensasi', 'lupa_absen', 'gps_error', 'lainnya'].includes(input.jenis_alasan)) throw new HttpError(400, 'Jenis alasan tidak valid.');
      const entry = kind === 'susulan' ? time(input.jam_masuk_diajukan) : null;
      const exit = kind === 'susulan' ? time(input.jam_pulang_diajukan) : null;
      // Tidak dapat membuat jam pulang tanpa jam masuk ketika tanggal belum punya presensi.
      if (kind === 'susulan' && !entry) throw new HttpError(400, 'Susulan wajib menyertakan jam masuk karena tanggal tersebut belum memiliki presensi.');
      if (entry && exit && exit < entry) throw new HttpError(400, 'Jam pulang tidak boleh sebelum jam masuk.');
      return participantTransaction(database, user.id, async (client, clock) => {
        if (proofId && !(await client.query('SELECT 1 FROM presensi.files WHERE id = $1 AND user_id = $2', [proofId, user.id])).rows.length) {
          throw new HttpError(404, 'Bukti milik Anda tidak ditemukan.');
        }
        if (kind === 'izin' ? start < shift(clock.day, -7) || end > shift(clock.day, 90)
          : start < shift(clock.day, -14) || start > clock.day) throw new HttpError(400, 'Tanggal pengajuan berada di luar batas yang diizinkan.');
        if (kind === 'susulan') {
          if (await holiday(client, start)) throw new HttpError(409, 'Tanggal susulan adalah hari libur.');
          if (submittedInstant(start, entry) > clock.instant || (exit && submittedInstant(start, exit) > clock.instant)) {
            throw new HttpError(400, 'Jam susulan tidak boleh berada di masa depan.');
          }
        }
        await noAttendance(client, user.id, start, end);
        await noRequests(client, user.id, start, end);
        const row = kind === 'izin'
          ? (await client.query(`INSERT INTO presensi.${target}
              (user_id, tanggal_mulai, tanggal_selesai, jenis, keterangan, bukti_url, bukti_id)
              VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`, [user.id, start, end, input.jenis, description, proof, proofId])).rows[0]
          : (await client.query(`INSERT INTO presensi.${target}
              (user_id, tanggal, jam_masuk_diajukan, jam_pulang_diajukan, jenis_alasan, keterangan, bukti_url, bukti_id)
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`, [user.id, start, entry, exit, input.jenis_alasan, description, proof, proofId])).rows[0];
        return { request: row };
      });
    },

    async requests(user, kind, input, admin = false) {
      const target = table(kind);
      fields(input, ['status', 'limit', 'offset']);
      if (admin && user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      if (input.status && !['menunggu', 'disetujui', 'ditolak'].includes(input.status)) throw new HttpError(400, 'Status tidak valid.');
      const page = pagination(input);
      const rows = (await database.query(`SELECT r.*, p.nama_lengkap FROM presensi.${target} r
        JOIN presensi.profiles p ON p.id = r.user_id
        WHERE ($1::uuid IS NULL OR r.user_id = $1) AND ($2::text IS NULL OR r.status_persetujuan = $2)
        ORDER BY r.created_at DESC, r.id LIMIT $3 OFFSET $4`, [admin ? null : user.id, input.status ?? null, page.limit, page.offset])).rows;
      return { requests: rows, ...page };
    },

    async decide(admin, kind, id, input) {
      const target = table(kind);
      uuid(id);
      if (admin.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      fields(input, ['setujui', 'alasan_penolakan']);
      if (typeof input.setujui !== 'boolean') throw new HttpError(400, 'setujui harus berupa boolean.');
      const reason = !input.setujui ? text(input.alasan_penolakan, 'Alasan penolakan', 3, 1000) : null;
      const initial = (await database.query(`SELECT user_id FROM presensi.${target} WHERE id = $1`, [id])).rows[0];
      if (!initial) throw new HttpError(404, 'Pengajuan tidak ditemukan.');
      return participantTransaction(database, initial.user_id, async (client, clock) => {
        const row = (await client.query(`SELECT *, to_char(${kind === 'izin' ? 'tanggal_mulai' : 'tanggal'}, 'YYYY-MM-DD') AS start,
          to_char(${kind === 'izin' ? 'tanggal_selesai' : 'tanggal'}, 'YYYY-MM-DD') AS finish
          FROM presensi.${target} WHERE id = $1 FOR UPDATE`, [id])).rows[0];
        if (!row || row.user_id !== initial.user_id) throw new HttpError(409, 'Pengajuan telah berubah.');
        if (row.status_persetujuan !== 'menunggu') throw new HttpError(409, 'Pengajuan sudah diproses.');
        if (input.setujui) {
          await noAttendance(client, row.user_id, row.start, row.finish);
          await noRequests(client, row.user_id, row.start, row.finish, { kind, id });
          if (kind === 'susulan') {
            if (await holiday(client, row.start)) throw new HttpError(409, 'Tanggal susulan adalah hari libur.');
            const entry = submittedInstant(row.start, row.jam_masuk_diajukan);
            const exit = submittedInstant(row.start, row.jam_pulang_diajukan);
            if (!entry || entry > clock.instant || (exit && (exit < entry || exit > clock.instant))) throw new HttpError(409, 'Jam susulan tidak valid.');
            await client.query(`INSERT INTO presensi.absensi(user_id, tanggal, jam_masuk, jam_pulang, status)
              VALUES ($1, $2, $3, $4, $5)`, [row.user_id, row.start, entry, exit,
              attendanceStatus(entry, row.start, row.jenis_alasan === 'dispensasi')]);
          }
        }
        const result = (await client.query(`UPDATE presensi.${target} SET status_persetujuan = $1,
          disetujui_oleh = $2, diproses_at = $3, alasan_penolakan = $4 WHERE id = $5 RETURNING *`,
        [input.setujui ? 'disetujui' : 'ditolak', admin.id, clock.instant, reason, id])).rows[0];
        return { request: result };
      });
    },
  };
}

export { fields, date, text, uuid, range, shift, pagination };
