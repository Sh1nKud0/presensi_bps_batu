import { HttpError } from './errors.js';
import { fields, date, uuid, pagination } from './attendance.js';

export function createNotifications(database) {
  return {
    async list(user, input) {
      fields(input, ['date', 'unread', 'limit', 'offset']);
      const day = input.date == null ? null : date(input.date);
      if (input.unread != null && !['true', 'false'].includes(input.unread)) throw new HttpError(400, 'unread harus true atau false.');
      const page = pagination(input);
      const notifications = (await database.query(`SELECT n.id, n.jenis, n.request_id, n.status,
        n.created_at, n.read_at, p.nama_lengkap FROM presensi.notifications n
        JOIN presensi.profiles p ON p.id = n.pengaju_id WHERE n.recipient_id = $1
        AND ($2::date IS NULL OR (n.created_at AT TIME ZONE 'Asia/Jakarta')::date = $2::date)
        AND ($3::boolean = false OR n.read_at IS NULL)
        ORDER BY n.created_at DESC, n.id LIMIT $4 OFFSET $5`, [user.id, day, input.unread === 'true', page.limit, page.offset])).rows.map(row => {
        const kind = { izin: 'izin/sakit', susulan: 'absen susulan', pembatalan: 'pembatalan pulang' }[row.jenis];
        return { ...row, title: row.status === 'menunggu' ? `${row.nama_lengkap} mengajukan ${kind}` : `Pengajuan ${kind} ${row.status}` };
      });
      const unread = (await database.query(`SELECT count(*)::int AS count FROM presensi.notifications
        WHERE recipient_id = $1 AND read_at IS NULL
        AND ($2::date IS NULL OR (created_at AT TIME ZONE 'Asia/Jakarta')::date = $2::date)`, [user.id, day])).rows[0].count;
      return { notifications, unread_count: unread, ...page };
    },
    async read(user, input) {
      fields(input, ['ids', 'date']);
      if ((input.ids != null) === (input.date != null)) throw new HttpError(400, 'Pilih ids atau date untuk menandai notifikasi.');
      if (input.ids != null && (!Array.isArray(input.ids) || !input.ids.length || input.ids.length > 100)) throw new HttpError(400, 'ids harus memuat 1–100 ID.');
      const ids = input.ids == null ? null : input.ids.map(uuid);
      const day = input.date == null ? null : date(input.date);
      const result = await database.query(`UPDATE presensi.notifications SET read_at = clock_timestamp()
        WHERE recipient_id = $1 AND read_at IS NULL
        AND ($2::uuid[] IS NULL OR id = ANY($2::uuid[]))
        AND ($3::date IS NULL OR (created_at AT TIME ZONE 'Asia/Jakarta')::date = $3::date) RETURNING id`, [user.id, ids, day]);
      return { read_count: result.rows.length };
    },
  };
}
