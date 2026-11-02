export const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
export const todayWib = (now = new Date()) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jakarta', year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
export const timeWib = value => {
    if (!value) return '—';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('id-ID', { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(date).replace('.', ':');
};
export const dateLabel = value => {
    if (!value) return '—';
    const date = new Date(`${String(value).slice(0, 10)}T12:00:00+07:00`);
    return Number.isNaN(date.getTime()) ? '—' : new Intl.DateTimeFormat('id-ID', { timeZone: 'Asia/Jakarta', day: 'numeric', month: 'short', year: 'numeric' }).format(date);
};
export const datetimeLabel = value => value ? `${dateLabel(todayWib(new Date(value)))} · ${timeWib(value)} WIB` : 'Belum diproses';
export const shiftDay = (day, amount) => { const date = new Date(`${day}T00:00:00Z`); date.setUTCDate(date.getUTCDate() + amount); return date.toISOString().slice(0, 10); };
export const OFFICE_LOCATION = Object.freeze({ latitude: -7.8668, longitude: 112.5073, radius: 100, maxAccuracy: 170 });
export function distanceMeters(latitude, longitude) {
    const radians = value => value * Math.PI / 180;
    const office = [OFFICE_LOCATION.latitude, OFFICE_LOCATION.longitude];
    const a = Math.sin(radians(latitude - office[0]) / 2) ** 2 + Math.cos(radians(latitude)) * Math.cos(radians(office[0])) * Math.sin(radians(longitude - office[1]) / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
}
// Same precedence as Android: pending requests, approved leave, then actual attendance.
export function dailyStatuses(day, participants, attendance, leaves, supplementary) {
    const statuses = new Map();
    for (const row of supplementary) {
        if (row.tanggal?.slice(0, 10) === day && row.status_persetujuan === 'menunggu') statuses.set(row.user_id, { label: 'Susulan menunggu', status: 'menunggu' });
    }
    for (const approved of [false, true]) {
        for (const row of leaves) {
            if (row.status_persetujuan !== (approved ? 'disetujui' : 'menunggu')) continue;
            if (row.tanggal_mulai.slice(0, 10) <= day && row.tanggal_selesai.slice(0, 10) >= day) {
                const kind = row.jenis === 'sakit' ? 'Sakit' : 'Izin';
                statuses.set(row.user_id, { label: `${kind} ${approved ? 'disetujui' : 'menunggu'}`, status: approved ? row.jenis : 'menunggu' });
            }
        }
    }
    for (const row of attendance) {
        if (row.tanggal.slice(0, 10) !== day) continue;
        if (!row.jam_masuk && ['izin', 'sakit'].includes(row.status)) statuses.set(row.user_id, { label: row.status === 'sakit' ? 'Sakit disetujui' : 'Izin disetujui', status: row.status });
        else if (row.jam_masuk || !statuses.has(row.user_id)) statuses.set(row.user_id, { label: row.status, status: row.status, attendance: row });
    }
    return participants.map(profile => ({ profile, ...(statuses.get(profile.id) ?? { label: 'Belum tercatat', status: 'belum' }) }));
}
