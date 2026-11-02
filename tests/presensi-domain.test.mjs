import test from 'node:test';
import assert from 'node:assert/strict';
import { escapeHtml, todayWib, timeWib, distanceMeters, dailyStatuses } from '../public/presensi-assets/domain.js';

test('WIB day and time remain consistent across the UTC midnight boundary', () => {
    assert.equal(todayWib(new Date('2026-10-27T18:30:00Z')), '2026-10-28');
    assert.equal(timeWib('2026-10-27T18:30:00Z'), '01:30');
    assert.equal(timeWib(null), '—');
});
test('untrusted names and descriptions cannot become HTML', () => {
    assert.equal(escapeHtml('<img src=x onerror="alert(1)"> &'), '&lt;img src=x onerror=&quot;alert(1)&quot;&gt; &amp;');
});
test('GPS distance is measured from the same office coordinates as Android', () => {
    assert.equal(distanceMeters(-7.8668, 112.5073), 0);
    assert.ok(distanceMeters(-7.8658, 112.5073) > 100);
});
test('actual attendance overrides overlapping requests while approved leave covers its entire range', () => {
    const day = '2026-10-27';
    const people = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    const leave = [{ user_id: 'a', tanggal_mulai: '2026-10-26', tanggal_selesai: '2026-10-28', status_persetujuan: 'disetujui', jenis: 'izin' },
        { user_id: 'b', tanggal_mulai: day, tanggal_selesai: day, status_persetujuan: 'disetujui', jenis: 'sakit' }];
    const attendance = [{ user_id: 'a', tanggal: day, jam_masuk: '2026-10-27T00:20:00Z', status: 'hadir' }];
    const rows = dailyStatuses(day, people, attendance, leave, []);
    assert.equal(rows[0].status, 'hadir');
    assert.equal(rows[1].label, 'Sakit disetujui');
    assert.equal(rows[2].label, 'Belum tercatat');
});
test('pending leave and correction match the Android daily overview without becoming absence', () => {
    const day = '2026-10-27';
    const people = [{ id: 'a' }, { id: 'b' }];
    const leaves = [{ user_id: 'a', tanggal_mulai: day, tanggal_selesai: day, status_persetujuan: 'menunggu', jenis: 'izin' }];
    const corrections = [{ user_id: 'b', tanggal: day, status_persetujuan: 'menunggu' }];
    const rows = dailyStatuses(day, people, [], leaves, corrections);
    assert.equal(rows[0].label, 'Izin menunggu');
    assert.equal(rows[1].label, 'Susulan menunggu');
});
