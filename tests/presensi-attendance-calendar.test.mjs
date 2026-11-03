import test from 'node:test';
import assert from 'node:assert/strict';
import { monthRange, moveMonth, attendanceCalendar } from '../public/presensi-assets/attendance-calendar.js';
test('month boundaries, leap years and Monday-first placement are correct',()=>{
 assert.equal(monthRange('2024-02').to,'2024-02-29');assert.equal(monthRange('2100-02').to,'2100-02-28');assert.equal(moveMonth('2026-01',-1),'2025-12');assert.equal(moveMonth('2026-12',1),'2027-01');assert.equal(attendanceCalendar('2026-11').leading,6);assert.throws(()=>monthRange('2026-13'));
});
test('real attendance overrides approved leave and pending leave never becomes attendance',()=>{
 const calendar=attendanceCalendar('2026-11',[{tanggal:'2026-11-02',jam_masuk:'2026-11-02T00:20:00Z',status:'hadir'},{tanggal:'2026-11-03',jam_masuk:'2026-11-03T01:00:00Z',status:'terlambat'},{tanggal:'2026-11-04',status:'dispensasi'}],[{tanggal_mulai:'2026-11-02',tanggal_selesai:'2026-11-05',jenis:'sakit',status_persetujuan:'disetujui'},{tanggal_mulai:'2026-11-06',tanggal_selesai:'2026-11-06',jenis:'izin',status_persetujuan:'menunggu'}]);
 assert.equal(calendar.days[1].status,'hadir');assert.equal(calendar.days[3].status,'dispensasi');assert.equal(calendar.days[4].status,'sakit');assert.equal(calendar.days[5].status,'belum');assert.deepEqual(calendar.stats,{hadir:2,terlambat:1,izin:1,libur:9});
});
test('weekend and public holiday counts never double count; missing data never becomes alpha',()=>{
 const calendar=attendanceCalendar('2026-11',[],[],[{tanggal:'2026-11-01',keterangan:'Weekend holiday'},{tanggal:'2026-11-04',keterangan:'National holiday'}]);assert.equal(calendar.stats.libur,10);assert.equal(calendar.stats.hadir,0);assert.ok(calendar.days.every(d=>d.status==='belum'));assert.equal(calendar.days.length,30);
});
