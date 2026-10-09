import { fields, range, pagination, serverClock } from './attendance.js';

export function createMobileQueries(database) {
  return {
    async statistics(user) {
      const row = (await database.query(`SELECT
        (SELECT count(*)::int FROM presensi.absensi WHERE user_id = $1 AND jam_masuk IS NOT NULL) AS hadir,
        (SELECT count(*)::int FROM presensi.izin WHERE user_id = $1 AND status_persetujuan = 'disetujui') AS izin`, [user.id])).rows[0];
      return row;
    },
    async participants(input) {
      fields(input, ['limit', 'offset']);
      const page = pagination(input);
      const participants = (await database.query(`SELECT id, nama_lengkap, nim, asal_instansi, role
        FROM presensi.profiles WHERE role = 'peserta' ORDER BY nama_lengkap, id LIMIT $1 OFFSET $2`,
      [page.limit, page.offset])).rows;
      return { participants, ...page };
    },
    async attendance(input) {
      fields(input, ['from', 'to', 'limit', 'offset']);
      const clock = await serverClock(database);
      const from = input.from ?? clock.day, to = input.to ?? from;
      range(from, to);
      const page = pagination(input);
      const attendance = (await database.query(`SELECT a.*, p.nama_lengkap FROM presensi.absensi a
        JOIN presensi.profiles p ON p.id = a.user_id WHERE a.tanggal BETWEEN $1::date AND $2::date
        ORDER BY a.tanggal DESC, a.id LIMIT $3 OFFSET $4`, [from, to, page.limit, page.offset])).rows;
      return { attendance, tanggal_server: clock.day, ...page };
    },
  };
}
