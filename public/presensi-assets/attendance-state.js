import { validateAttendancePoint } from './location.js?v=20261029-gps170-r1';
export function attendanceEligibility(today, point, now = Date.now()) {
    const kind = today?.can_check_in ? 'check-in' : today?.can_check_out ? 'check-out' : null;
    let valid = false;
    if (point && [point.latitude, point.longitude, point.accuracy].every(Number.isFinite)
        && Math.abs(point.latitude) <= 90 && Math.abs(point.longitude) <= 180 && point.accuracy > 0 && point.is_mocked !== true) {
        const age = now - Date.parse(point.captured_at);
        try { validateAttendancePoint(point); valid = Number.isFinite(age) && age >= -30000 && age <= 15000; } catch {}
    }
    return { kind, valid, ready: Boolean(kind && !today?.block_reason && valid) };
}
