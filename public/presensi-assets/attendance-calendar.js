export function monthRange(period) {
    if (!/^(20\d{2}|2100)-(0[1-9]|1[0-2])$/.test(period)) throw new Error('Periode bulan tidak valid.');
    const [year, month] = period.split('-').map(Number);
    return { from: `${period}-01`, to: `${period}-${new Date(Date.UTC(year, month, 0)).getUTCDate()}`, year, month };
}
export function moveMonth(period, amount) {
    const { year, month } = monthRange(period);
    const date = new Date(Date.UTC(year, month - 1 + amount, 1));
    const next = date.toISOString().slice(0, 7);
    return next < '2000-01' ? '2000-01' : next > '2100-12' ? '2100-12' : next;
}
export function attendanceCalendar(period, attendance = [], leaves = [], holidays = []) {
    const { from, to, year, month } = monthRange(period);
    const records = new Map(attendance.map(row => [String(row.tanggal).slice(0, 10), row]));
    const holidaysByDay = new Map(holidays.map(row => [String(row.tanggal).slice(0, 10), row]));
    const stats = { hadir: 0, terlambat: 0, izin: 0, libur: 0 };
    const days = [];
    for (let day = 1; day <= Number(to.slice(-2)); day++) {
        const date = `${period}-${String(day).padStart(2, '0')}`;
        const weekday = new Date(`${date}T12:00:00Z`).getUTCDay();
        const weekend = weekday === 0 || weekday === 6;
        const holiday = holidaysByDay.get(date);
        const row = records.get(date);
        const leave = leaves.find(r => r.status_persetujuan === 'disetujui' && String(r.tanggal_mulai).slice(0, 10) <= date && String(r.tanggal_selesai).slice(0, 10) >= date);
        let status = 'belum';
        if (row?.status === 'dispensasi' || row?.status === 'dinas_luar') status = 'dispensasi';
        else if (row?.jam_masuk) status = row.status === 'terlambat' ? 'terlambat' : 'hadir';
        else if (row && ['izin', 'sakit', 'alpha'].includes(row.status)) status = row.status;
        else if (leave) status = leave.jenis === 'sakit' ? 'sakit' : 'izin';
        const label = { hadir: 'Hadir', terlambat: 'Terlambat', izin: 'Izin', sakit: 'Sakit', dispensasi: 'Dispensasi', alpha: 'Alpha', belum: 'Belum ada catatan' }[status];
        if (weekend || holiday) stats.libur++;
        else {
            if (['hadir', 'terlambat'].includes(status)) stats.hadir++;
            if (status === 'terlambat') stats.terlambat++;
            if (['izin', 'sakit'].includes(status)) stats.izin++;
        }
        days.push({ date, day, weekend, holiday, attendance: row, leave, status, label });
    }
    return { days, stats, from, to, leading: (new Date(Date.UTC(year, month - 1, 1)).getUTCDay() + 6) % 7 };
}
