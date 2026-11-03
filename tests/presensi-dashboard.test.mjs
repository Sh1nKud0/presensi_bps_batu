import test from 'node:test';
import assert from 'node:assert/strict';
import { dashboardSummary } from '../public/presensi-assets/dashboard.js';

test('belum masuk menawarkan absen sekarang', () => {
    const result = dashboardSummary({ attendance: null, can_check_in: true, can_check_out: false });
    assert.equal(result.action, 'Presensi Sekarang');
    assert.equal(result.minutes, 0);
    assert.equal(result.available, true);
});
test('jam kerja dihitung dari masuk sampai pulang', () => {
    const result = dashboardSummary({ attendance: { jam_masuk: '2026-11-02T00:00:00Z', jam_pulang: '2026-11-02T08:15:00Z' }, can_check_in: false, can_check_out: false });
    assert.equal(result.hours, 8);
    assert.equal(result.remainingMinutes, 15);
    assert.equal(result.complete, true);
    assert.equal(result.action, 'Presensi sudah lengkap');
    assert.equal(result.available, false);
});
test('belum pulang memakai waktu sekarang dan menghormati blokir backend', () => {
    const now = new Date('2026-11-02T02:15:00Z');
    const today = { attendance: { jam_masuk: '2026-11-02T00:00:00Z' }, can_check_out: true };
    assert.equal(dashboardSummary(today, now).action, 'Presensi Pulang');
    assert.equal(dashboardSummary(today, now).minutes, 135);
    assert.equal(dashboardSummary({ ...today, block_reason: 'Izin' }, now).available, false);
});
