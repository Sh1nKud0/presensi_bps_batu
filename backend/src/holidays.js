import { HttpError } from './errors.js';
import { fields, date, text, uuid, range, shift, pagination, serverClock } from './attendance.js';

export function createHolidays(database) {
  return {
    async list(input) {
      fields(input, ['from', 'to', 'limit', 'offset']);
      const clock = await serverClock(database);
      const from = input.from ?? clock.day, to = input.to ?? shift(from, 365);
      range(from, to);
      const page = pagination(input);
      const holidays = (await database.query(`SELECT * FROM presensi.hari_libur WHERE tanggal BETWEEN $1::date AND $2::date
        ORDER BY tanggal LIMIT $3 OFFSET $4`, [from, to, page.limit, page.offset])).rows;
      return { holidays, ...page };
    },
    async add(user, input) {
      if (user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      fields(input, ['tanggal', 'keterangan']);
      const day = date(input.tanggal), description = text(input.keterangan, 'Keterangan', 1, 200);
      try {
        return { holiday: (await database.query(`INSERT INTO presensi.hari_libur(tanggal, keterangan, dibuat_oleh)
          VALUES ($1, $2, $3) RETURNING *`, [day, description, user.id])).rows[0] };
      } catch (error) {
        if (error.code === '23505') throw new HttpError(409, 'Hari libur tanggal tersebut sudah ada.');
        throw error;
      }
    },
    async remove(user, id) {
      if (user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      uuid(id);
      const rows = (await database.query('DELETE FROM presensi.hari_libur WHERE id = $1 RETURNING id', [id])).rows;
      if (!rows.length) throw new HttpError(404, 'Hari libur tidak ditemukan.');
      return { message: 'Hari libur dihapus.' };
    },
  };
}
