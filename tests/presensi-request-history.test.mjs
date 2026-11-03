import test from 'node:test';
import assert from 'node:assert/strict';
import { decisionHistory } from '../public/presensi-assets/request-history.js';
test('history excludes pending requests and orders across request types by decision time', () => {
 const groups=[{kind:'izin',requests:[{id:'1',status_persetujuan:'disetujui',created_at:'2026-01-01',diproses_at:'2026-01-03'},{id:'2',status_persetujuan:'menunggu'}]},{kind:'susulan',requests:[{id:'3',status_persetujuan:'ditolak',created_at:'2026-01-02',diproses_at:'2026-01-04',alasan_penolakan:'Tidak lengkap'}]}];
 const rows=decisionHistory(groups);assert.deepEqual(rows.map(r=>r.id),['3','1']);assert.equal(rows[0].kind,'susulan');assert.equal(rows[0].alasan_penolakan,'Tidak lengkap');assert.equal(decisionHistory(groups,{status:'disetujui'}).length,1);
});
test('missing decision timestamp falls back to submission without fabricating a decision time', () => {
 const rows=decisionHistory([{kind:'pembatalan',requests:[{id:'1',status_persetujuan:'disetujui',created_at:'2026-01-02'}]}]);assert.equal(rows.length,1);assert.equal(rows[0].diproses_at,undefined);
});
