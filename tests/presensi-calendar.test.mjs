import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
const requireBackend = createRequire(process.env.PRESENSI_BACKEND_ROOT ? resolve(process.env.PRESENSI_BACKEND_ROOT, 'package.json') : new URL('../../presensi_bps_batu/backend/package.json', import.meta.url));
const { PGlite } = requireBackend('@electric-sql/pglite');
import { normalizeCalendar, synchronizeCalendar, CALENDAR_PREFIX } from '../scripts/lib/national-holidays.mjs';
const feed=()=>({year:2026,sources:[{type:'skb'}],holidays:Array.from({length:12},(_,i)=>({date:`2026-01-${String(i+1).padStart(2,'0')}`,name:`Libur ${i}`,type:'national_holiday'}))});
test('invalid/incomplete feeds rejected; duplicate dates grouped and regional events excluded',()=>{
 const data=feed();data.holidays.push({...data.holidays[0],name:'Cuti',type:'joint_leave'},{date:'2026-01-20',name:'Regional',type:'regional'});
 const rows=normalizeCalendar(data,2026);assert.equal(rows.length,12);assert.match(rows[0].keterangan,/Cuti bersama: Cuti/);
 assert.throws(()=>normalizeCalendar({...data,holidays:[]},2026));assert.throws(()=>normalizeCalendar(data,2027));
});
test('shared PostgreSQL sync is idempotent and preserves manual dates; large deletions roll back',async()=>{
 const db=new PGlite();await db.exec('CREATE SCHEMA presensi; CREATE TABLE presensi.hari_libur(id serial PRIMARY KEY,tanggal date UNIQUE,keterangan text);');
 const client={query:(sql,args)=>sql.includes('pg_advisory_xact_lock')?Promise.resolve({rows:[]}):args?db.query(sql,args):db.exec(sql).then(r=>r.at(-1))};
 try{
 await db.query("INSERT INTO presensi.hari_libur(tanggal,keterangan) VALUES ('2026-01-01','Libur khusus kantor')");
 const rows=normalizeCalendar(feed(),2026);let result=await synchronizeCalendar(client,rows,2026,'2026-01-01');assert.equal(result.changed,11);
 result=await synchronizeCalendar(client,rows,2026,'2026-01-01');assert.equal(result.changed,0);
 assert.equal((await db.query("SELECT keterangan FROM presensi.hari_libur WHERE tanggal='2026-01-01'")).rows[0].keterangan,'Libur khusus kantor');
 const next=rows.filter(r=>r.tanggal!=='2026-01-12');result=await synchronizeCalendar(client,next,2026,'2026-01-01');assert.equal(result.removed,1);
 await assert.rejects(()=>synchronizeCalendar(client,rows.slice(0,2),2026,'2026-01-01'));assert.equal((await db.query('SELECT count(*)::int AS n FROM presensi.hari_libur')).rows[0].n,11);
 }finally{await db.close()}
});
