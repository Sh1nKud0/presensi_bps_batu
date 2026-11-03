// Summary follows the Android Beranda while keeping times in WIB.
export function dashboardSummary(today, now = new Date()) {
    const attendance = today.attendance ?? null;
    const started = attendance?.jam_masuk ? Date.parse(attendance.jam_masuk) : NaN;
    const ended = attendance?.jam_pulang ? Date.parse(attendance.jam_pulang) : now.getTime();
    const minutes = Number.isFinite(started) && Number.isFinite(ended)
        ? Math.max(0, Math.floor((ended - started) / 60000)) : 0;
    const done = Boolean(attendance?.jam_masuk && attendance?.jam_pulang);
    const available = !today.block_reason && !done && Boolean(today.can_check_in || today.can_check_out);
    return { attendance, minutes, hours: Math.floor(minutes / 60), remainingMinutes: minutes % 60,
        complete: minutes >= 480, done, available,
        action: done ? 'Presensi sudah lengkap' : !available ? 'Presensi tidak tersedia' : attendance?.jam_masuk ? 'Presensi Pulang' : 'Presensi Sekarang' };
}
