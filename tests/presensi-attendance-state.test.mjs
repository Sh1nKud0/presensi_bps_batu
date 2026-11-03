import test from 'node:test';
import assert from 'node:assert/strict';
import { attendanceEligibility } from '../public/presensi-assets/attendance-state.js';
const now=Date.parse('2026-11-03T06:30:00Z');
const point={latitude:-7.8668,longitude:112.5073,accuracy:20,captured_at:new Date(now).toISOString(),is_mocked:false};
test('submission needs a fresh accurate device fix inside the office radius',()=>{
 const today={can_check_in:true};assert.equal(attendanceEligibility(today,point,now).ready,true);
 for(const changed of [{latitude:-7.88},{accuracy:171},{accuracy:0},{latitude:NaN},{is_mocked:true},{captured_at:new Date(now-15001).toISOString()},{captured_at:new Date(now+30001).toISOString()}])assert.equal(attendanceEligibility(today,{...point,...changed},now).ready,false);
 assert.equal(attendanceEligibility(today,null,now).ready,false);
});
test('server availability and block reasons always override a valid location',()=>{
 assert.deepEqual(attendanceEligibility({can_check_out:true},point,now),{kind:'check-out',valid:true,ready:true});
 assert.equal(attendanceEligibility({can_check_in:true,block_reason:'Hari libur'},point,now).ready,false);
 assert.equal(attendanceEligibility({can_check_in:false,can_check_out:false},point,now).ready,false);
});
