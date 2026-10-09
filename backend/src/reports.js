import ExcelJS from 'exceljs';
import { HttpError } from './errors.js';
import { fields, serverClock, shift } from './attendance.js';

function period(input) {
  fields(input, ['month', 'year']);
  if (!/^\d{1,2}$/.test(String(input.month)) || !/^\d{4}$/.test(String(input.year))
      || Number(input.month) < 1 || Number(input.month) > 12 || Number(input.year) < 2000 || Number(input.year) > 2100) {
    throw new HttpError(400, 'Isi month 1–12 dan year 2000–2100.');
  }
  const year = Number(input.year), month = Number(input.month);
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const end = new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10);
  return { year, month, start, end };
}
function wib(instant) { return new Date(new Date(instant).getTime() + 7 * 3600000); }
function hour(instant) { return instant == null ? '-' : wib(instant).toISOString().slice(11, 16); }
function status(row) {
  if (['dispensasi', 'dinas_luar'].includes(row.status)) return 'Dispensasi';
  if (row.jam_masuk != null) {
    const local = wib(row.jam_masuk);
    const cutoff = Date.parse(`${local.toISOString().slice(0, 10)}T07:30:00Z`);
    return local.getTime() > cutoff ? 'Terlambat' : 'Hadir';
  }
  return { izin: 'Izin', sakit: 'Sakit', alpha: 'Alpha' }[row.status] ?? 'Tidak lengkap';
}

// Menyamakan aturan dengan RekapPresensi.hitung di Flutter: catatan kosong
// bukan otomatis alpha; akhir pekan/libur/masa depan tidak masuk total.
export function buildReport({ month, year, profiles, attendance, leaves, holidays, now }) {
  const { start, end } = period({ month, year });
  const today = wib(now).toISOString().slice(0, 10);
  const attendanceMap = new Map(attendance.map(row => [`${row.user_id}/${row.tanggal}`, row]));
  const holidayMap = new Map(holidays.map(row => [row.tanggal, row.keterangan]));
  const leaveMap = new Map();
  for (const row of leaves) {
    if (row.status_persetujuan !== 'disetujui') continue;
    for (let day = row.tanggal_mulai > start ? row.tanggal_mulai : start;
      day <= row.tanggal_selesai && day <= end; day = shift(day, 1)) {
      const key = `${row.user_id}/${day}`;
      if (leaveMap.get(key) !== 'Sakit') leaveMap.set(key, row.jenis === 'sakit' ? 'Sakit' : 'Izin');
    }
  }
  const participants = [...profiles].sort((a, b) => a.nama_lengkap.localeCompare(b.nama_lengkap, 'id') || a.id.localeCompare(b.id)).map(profile => {
    const days = [];
    for (let day = start; day <= end; day = shift(day, 1)) {
      const row = attendanceMap.get(`${profile.id}/${day}`);
      const weekend = [0, 6].includes(new Date(day).getUTCDay());
      const holiday = holidayMap.get(day);
      const future = day > today;
      const counted = !weekend && holiday === undefined && !future;
      const meaningful = row && (row.jam_masuk != null || ['dispensasi', 'dinas_luar', 'izin', 'sakit', 'alpha'].includes(row.status));
      const label = meaningful ? status(row) : leaveMap.get(`${profile.id}/${day}`)
        ?? (row ? 'Tidak lengkap' : weekend || holiday !== undefined ? 'Libur'
          : future ? 'Belum berlangsung' : day === today ? 'Belum tercatat' : 'Tanpa catatan');
      const notes = [holiday, weekend ? 'Akhir pekan' : null, future ? 'Tanggal mendatang' : null,
        !counted && !['Libur', 'Belum berlangsung'].includes(label) ? 'Tidak dihitung' : null,
        row?.jam_masuk && !row.jam_pulang ? 'Belum ada jam pulang' : null].filter(Boolean).join('; ');
      days.push({ tanggal: day, status: label, jam_masuk: hour(row?.jam_masuk), jam_pulang: hour(row?.jam_pulang), dihitung: counted, catatan: notes });
    }
    const count = label => days.filter(day => day.dihitung && day.status === label).length;
    const counts = { tepat_waktu: count('Hadir'), terlambat: count('Terlambat'), izin: count('Izin'), sakit: count('Sakit'),
      dispensasi: count('Dispensasi'), alpha: count('Alpha'), tanpa_catatan: count('Tanpa catatan'), tidak_lengkap: count('Tidak lengkap') };
    counts.hadir = counts.tepat_waktu + counts.terlambat;
    counts.total = counts.hadir + counts.izin + counts.sakit + counts.dispensasi;
    return { profile, counts, days };
  });
  return { month: Number(month), year: Number(year), generated_at: new Date(now).toISOString(), participants };
}

function sheet(workbook, name, title, meta, headers, widths) {
  const page = workbook.addWorksheet(name, {
    views: [{ state: 'frozen', ySplit: 4 }],
    pageSetup: { orientation: 'landscape', paperSize: 9, fitToPage: true, fitToWidth: 1, fitToHeight: 0, printTitlesRow: '1:4' },
  });
  page.columns = widths.map(width => ({ width }));
  page.mergeCells(1, 1, 1, headers.length);
  page.getCell(1, 1).value = title;
  page.getCell(1, 1).font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FF1E40AF' } };
  page.getRow(1).height = 28;
  page.mergeCells(2, 1, 2, headers.length);
  page.getCell(2, 1).value = meta;
  page.getRow(2).height = 30;
  page.getCell(2, 1).alignment = { wrapText: true, vertical: 'middle' };
  page.getRow(4).values = headers;
  page.getRow(4).height = 36;
  page.getRow(4).eachCell(cell => {
    cell.font = { name: 'Arial', bold: true, color: { argb: 'FFFFFFFF' }, size: 10 };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E40AF' } };
    cell.alignment = { wrapText: true, vertical: 'middle', horizontal: 'center' };
  });
  return page;
}
function finalize(page) {
  page.autoFilter = { from: { row: 4, column: 1 }, to: { row: Math.max(4, page.rowCount), column: page.columnCount } };
  for (let index = 5; index <= page.rowCount; index++) {
    const row = page.getRow(index);
    let lines = 1;
    row.eachCell(cell => {
      const width = page.getColumn(cell.col).width ?? 12;
      const estimate = String(cell.value ?? '').split('\n').reduce((sum, part) => sum + Math.max(1, Math.ceil(part.length / Math.max(1, width - 2))), 0);
      lines = Math.max(lines, estimate);
    });
    row.height = Math.min(180, Math.max(30, lines * 14 + 10));
    row.eachCell({ includeEmpty: true }, cell => {
      cell.font = { name: 'Arial', size: 10 };
      cell.alignment = { vertical: 'middle', wrapText: true };
      if (index % 2 === 0) cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    });
  }
}
export async function reportWorkbook(report) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'BPS Kota Batu';
  workbook.created = new Date(report.generated_at);
  const meta = `Periode ${String(report.month).padStart(2, '0')}/${report.year} | Dibuat ${wib(report.generated_at).toISOString().slice(0, 19).replace('T', ' ')} WIB`;
  const summary = sheet(workbook, 'Ringkasan', 'REKAP PRESENSI PESERTA MAGANG', meta,
    ['No', 'Nama', 'Asal instansi', 'Hadir tepat waktu', 'Terlambat', 'Total hadir', 'Izin', 'Sakit', 'Dispensasi', 'Alpha', 'Tanpa catatan', 'Tidak lengkap', 'Total tercatat'],
    [6, 30, 30, 14, 12, 12, 10, 10, 14, 10, 14, 14, 14]);
  const detail = sheet(workbook, 'Detail harian', 'DETAIL PRESENSI HARIAN', meta,
    ['Nama', 'Tanggal', 'Status', 'Jam masuk WIB', 'Jam pulang WIB', 'Dihitung', 'Catatan'], [30, 14, 22, 16, 16, 12, 70]);
  report.participants.forEach((person, index) => {
    const c = person.counts;
    // String dari pengguna selalu cell string, tidak pernah dimasukkan sebagai formula.
    summary.addRow([index + 1, person.profile.nama_lengkap, person.profile.asal_instansi ?? '-', c.tepat_waktu, c.terlambat,
      c.hadir, c.izin, c.sakit, c.dispensasi, c.alpha, c.tanpa_catatan, c.tidak_lengkap, c.total]);
    for (const day of person.days) detail.addRow([person.profile.nama_lengkap, day.tanggal, day.status, day.jam_masuk, day.jam_pulang, day.dihitung ? 'Ya' : 'Tidak', day.catatan]);
  });
  finalize(summary); finalize(detail);
  const info = workbook.addWorksheet('Keterangan');
  info.columns = [{ width: 30 }, { width: 100 }];
  info.addRows([
    ['Aturan perhitungan', 'Keterangan'],
    ['Zona waktu', 'Seluruh tanggal/jam kantor memakai WIB.'],
    ['Total hadir', 'Hadir tepat waktu + terlambat. Keterlambatan tidak dihitung dua kali.'],
    ['Total tercatat', 'Total hadir + izin + sakit + dispensasi.'],
    ['Hari tidak dihitung', 'Akhir pekan, hari libur dan tanggal mendatang tetap ditampilkan, tetapi tidak masuk total.'],
    ['Tanpa catatan', 'Tanggal kerja yang sudah lewat tanpa presensi/izin disetujui. Tidak otomatis dianggap alpha.'],
    ['Hari ini', 'Tanpa data ditampilkan sebagai Belum tercatat.'],
    ['Prioritas data', 'Presensi nyata mengungguli izin. Hanya izin disetujui yang dihitung.'],
    ['Tidak lengkap', 'Baris presensi tanpa jam masuk atau status yang dapat dihitung.'],
  ]);
  info.eachRow(row => { row.height = 40; row.eachCell(cell => { cell.font = { name: 'Arial', size: 11 }; cell.alignment = { wrapText: true, vertical: 'middle' }; }); });
  info.getRow(1).font = { bold: true, name: 'Arial', size: 12 };
  return Buffer.from(await workbook.xlsx.writeBuffer());
}

export function createReports(database) {
  let exporting = false;
  async function load(user, input) {
    if (user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
    const { month, year, start, end } = period(input);
    const client = await database.connect();
    try {
      await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
      const clock = await serverClock(client);
      const profiles = (await client.query("SELECT id, nama_lengkap, nim, asal_instansi FROM presensi.profiles WHERE role = 'peserta' ORDER BY id LIMIT 1001")).rows;
      if (profiles.length > 1000) throw new HttpError(413, 'Rekap dibatasi 1000 peserta per ekspor.');
      const attendance = (await client.query(`SELECT *, to_char(tanggal, 'YYYY-MM-DD') AS tanggal FROM presensi.absensi
        WHERE tanggal BETWEEN $1::date AND $2::date`, [start, end])).rows;
      const leaves = (await client.query(`SELECT *, to_char(tanggal_mulai, 'YYYY-MM-DD') AS tanggal_mulai,
        to_char(tanggal_selesai, 'YYYY-MM-DD') AS tanggal_selesai FROM presensi.izin
        WHERE tanggal_mulai <= $2::date AND tanggal_selesai >= $1::date AND status_persetujuan = 'disetujui'`, [start, end])).rows;
      const holidays = (await client.query(`SELECT keterangan, to_char(tanggal, 'YYYY-MM-DD') AS tanggal FROM presensi.hari_libur
        WHERE tanggal BETWEEN $1::date AND $2::date`, [start, end])).rows;
      await client.query('COMMIT');
      return buildReport({ month, year, profiles, attendance, leaves, holidays, now: clock.instant });
    } catch (error) { await client.query('ROLLBACK'); throw error; }
    finally { client.release(); }
  }
  return {
    load,
    async xlsx(user, input) {
      if (exporting) throw new HttpError(429, 'Ekspor lain sedang diproses. Coba kembali sebentar.');
      exporting = true;
      try {
        const report = await load(user, input);
        return { buffer: await reportWorkbook(report), filename: `rekap-presensi-${report.year}-${String(report.month).padStart(2, '0')}.xlsx` };
      } finally { exporting = false; }
    },
  };
}
