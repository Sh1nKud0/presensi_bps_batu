export const CALENDAR_PREFIX = '[Kalender Indonesia] ';
export const CALENDAR_SOURCE = 'https://github.com/ahrulsyamil/indonesian-holidays';

export function normalizeCalendar(data, year) {
    if (data?.year !== year || !Array.isArray(data.holidays) || !Array.isArray(data.sources) || !data.sources.length) throw new Error('Format sumber kalender tidak valid.');
    const dates = new Map();
    for (const row of data.holidays) {
        if (!['national_holiday', 'joint_leave'].includes(row.type)) continue;
        if (typeof row.date !== 'string' || !new RegExp(`^${year}-\\d{2}-\\d{2}$`).test(row.date) || new Date(`${row.date}T00:00:00Z`).toISOString().slice(0, 10) !== row.date || typeof row.name !== 'string' || !row.name.trim()) throw new Error('Tanggal atau nama libur tidak valid.');
        const names = dates.get(row.date) ?? [];
        const name = `${row.type === 'joint_leave' ? 'Cuti bersama: ' : ''}${row.name.trim()}`;
        if (!names.includes(name)) names.push(name);
        dates.set(row.date, names);
    }
    // Reject missing or incomplete feeds before any database mutation.
    if (dates.size < 10 || dates.size > 60) throw new Error('Kalender belum lengkap; data lama dipertahankan.');
    return [...dates].sort(([a], [b]) => a.localeCompare(b)).map(([tanggal, names]) => ({ tanggal, keterangan: CALENDAR_PREFIX + names.join('; ') }));
}

export async function synchronizeCalendar(client, rows, year, today) {
    await client.query('BEGIN');
    try {
        await client.query('SELECT pg_advisory_xact_lock(50142026)');
        const previous = (await client.query("SELECT tanggal::text FROM presensi.hari_libur WHERE keterangan LIKE $1 AND tanggal >= $2::date AND tanggal <= $3::date", [CALENDAR_PREFIX+'%', `${year}-01-01`, `${year}-12-31`])).rows;
        const dates = new Set(rows.map(row => row.tanggal));
        const removed = previous.filter(row => row.tanggal >= today && !dates.has(row.tanggal));
        if (removed.length > 3 || (previous.length && removed.length / previous.length > 0.3)) throw new Error('Perubahan kalender terlalu besar; perlu pemeriksaan admin.');
        let changed = 0;
        for (const row of rows) {
            const result = await client.query(`INSERT INTO presensi.hari_libur(tanggal, keterangan) VALUES ($1, $2)
                ON CONFLICT(tanggal) DO UPDATE SET keterangan = EXCLUDED.keterangan
                WHERE presensi.hari_libur.keterangan LIKE $3 AND presensi.hari_libur.keterangan IS DISTINCT FROM EXCLUDED.keterangan
                RETURNING id`, [row.tanggal, row.keterangan, CALENDAR_PREFIX+'%']);
            changed += result.rows.length;
        }
        for (const row of removed) await client.query('DELETE FROM presensi.hari_libur WHERE tanggal = $1::date AND keterangan LIKE $2', [row.tanggal, CALENDAR_PREFIX+'%']);
        await client.query('COMMIT');
        return { count: rows.length, changed, removed: removed.length };
    } catch (error) { await client.query('ROLLBACK'); throw error; }
}
