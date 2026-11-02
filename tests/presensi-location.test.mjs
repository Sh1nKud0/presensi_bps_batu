import test from 'node:test';
import assert from 'node:assert/strict';
import { collectLocation, validateAttendancePoint } from '../public/presensi-assets/location.js';
import { OFFICE_LOCATION, distanceMeters } from '../public/presensi-assets/domain.js';

function device() {
    let success;
    let failure;
    const cleared = [];
    let options;
    return {
        cleared,
        get options() { return options; },
        watchPosition(onSuccess, onError, settings) { success = onSuccess; failure = onError; options = settings; return 0; },
        clearWatch(id) { cleared.push(id); },
        sample(accuracy, changes = {}) {
            success({ coords: { latitude: OFFICE_LOCATION.latitude, longitude: OFFICE_LOCATION.longitude, accuracy, ...changes }, timestamp: changes.timestamp ?? Date.now() });
        },
        error(code) { failure({ code }); },
    };
}

test('coarse first fix is refined before attendance without changing reported accuracy or coordinates', async () => {
    const gps = device(); const updates = [];
    const collected = collectLocation(gps, { onProgress: point => updates.push(point.accuracy) });
    let completed = false; collected.then(() => { completed = true; });
    gps.sample(220);
    await Promise.resolve(); assert.equal(completed, false);
    gps.sample(180); gps.sample(159, { latitude: -7.86675 });
    const point = await collected;
    assert.deepEqual(updates, [220, 180, 159]);
    assert.equal(point.accuracy, 159); assert.equal(point.latitude, -7.86675);
    assert.ok(validateAttendancePoint(point) < 100);
    assert.deepEqual(gps.cleared, [0]);
    assert.equal(gps.options.enableHighAccuracy, true); assert.equal(gps.options.maximumAge, 0);
});

test('persistent coarse fixes preserve the best accuracy and remain invalid for attendance', async () => {
    const gps = device();
    const collected = collectLocation(gps, { timeoutMs: 20 });
    gps.sample(220); gps.sample(171); gps.sample(200);
    const point = await collected;
    assert.equal(point.accuracy, 171);
    assert.throws(() => validateAttendancePoint(point), /171.*170/);
    assert.deepEqual(gps.cleared, [0]);
});

test('selection depends on accuracy rather than a point being closer to the office', async () => {
    const gps = device(); const collected = collectLocation(gps);
    gps.sample(220);
    gps.sample(10, { latitude: OFFICE_LOCATION.latitude + 0.01 });
    const point = await collected;
    assert.equal(point.latitude, OFFICE_LOCATION.latitude + 0.01);
    assert.throws(() => validateAttendancePoint(point), /radius 100/);
    assert.deepEqual(gps.cleared, [0]);
});

test('old, future and invalid samples never substitute for a fresh device position', async () => {
    const gps = device(); const updates = [];
    const collected = collectLocation(gps, { onProgress: point => updates.push(point) });
    gps.sample(1, { timestamp: Date.now() - 120000 });
    gps.sample(1, { timestamp: Date.now() + 60000 });
    gps.sample(1, { latitude: NaN }); gps.sample(1, { latitude: 100 }); gps.sample(-1);
    gps.sample(50);
    const point = await collected;
    assert.equal(updates.length, 1); assert.equal(point.accuracy, 50);
});

test('denied permission stops the watch even after a previous approximate fix', async () => {
    const gps = device(); const collected = collectLocation(gps);
    gps.sample(220); gps.error(1);
    await assert.rejects(collected, /Izin lokasi ditolak/);
    assert.deepEqual(gps.cleared, [0]);
});

test('a transient provider failure can recover, while no position eventually fails', async () => {
    const gps = device(); const collected = collectLocation(gps);
    gps.error(2); gps.sample(20);
    assert.equal((await collected).accuracy, 20);
    const unavailable = device(); const failed = collectLocation(unavailable, { timeoutMs: 20 });
    unavailable.error(2);
    await assert.rejects(failed, /Lokasi perangkat belum ditemukan/);
    assert.deepEqual(unavailable.cleared, [0]);
});

test('cancellation and synchronous providers clean up the active location watch', async () => {
    const gps = device(); const controller = new AbortController();
    const collected = collectLocation(gps, { signal: controller.signal });
    controller.abort(); await assert.rejects(collected, /dibatalkan/);
    assert.deepEqual(gps.cleared, [0]);
    const cleared = [];
    await collectLocation({
        watchPosition(success) { success({ coords: { ...OFFICE_LOCATION, accuracy: 10 }, timestamp: Date.now() }); return 7; },
        clearWatch(id) { cleared.push(id); },
    });
    assert.deepEqual(cleared, [7]);
});

test('the radius comparison uses exact distance even just beyond 100 metres', () => {
    const latitude = OFFICE_LOCATION.latitude + 100.2 / 6371000 * 180 / Math.PI;
    const point = { latitude, longitude: OFFICE_LOCATION.longitude, accuracy: 10 };
    assert.ok(distanceMeters(latitude, point.longitude) > 100);
    assert.ok(distanceMeters(latitude, point.longitude) < 100.5);
    assert.throws(() => validateAttendancePoint(point), /radius 100/);
});

test('accepts the 170 metre accuracy boundary and rejects values immediately above it', async () => {
    const gps = device(); const collected = collectLocation(gps);
    gps.sample(170);
    assert.equal((await collected).accuracy, 170);
    assert.equal(validateAttendancePoint({ ...OFFICE_LOCATION, accuracy: 170 }), 0);
    assert.throws(() => validateAttendancePoint({ ...OFFICE_LOCATION, accuracy: 170.01 }), /170/);
    assert.deepEqual(gps.cleared, [0]);
});
