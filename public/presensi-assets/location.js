import { OFFICE_LOCATION, distanceMeters } from './domain.js?v=20261029-gps170-r1';

function positionError(code) {
    return new Error(({ 1: 'Izin lokasi ditolak. Izinkan akses lokasi untuk situs ini pada pengaturan peramban.',
        2: 'Lokasi perangkat belum ditemukan. Aktifkan layanan lokasi dan Wi-Fi, lalu coba di tempat terbuka.',
        3: 'Belum mendapat lokasi perangkat dalam 30 detik. Periksa layanan lokasi, lalu coba kembali.' })[code] ?? 'Lokasi perangkat tidak tersedia.');
}

// A browser's first fix can be coarse. Wait for fresh updates before accepting
// it, preserving the reported accuracy and timestamp exactly as received.
export function collectLocation(geolocation, { timeoutMs = 30000, onProgress = () => {}, signal, now = Date.now } = {}) {
    return new Promise((resolve, reject) => {
        let best;
        let lastError;
        let watchId;
        let finished = false;
        let timer;
        const finish = error => {
            if (finished) return;
            finished = true;
            clearTimeout(timer);
            if (watchId !== undefined) geolocation.clearWatch(watchId);
            signal?.removeEventListener('abort', cancel);
            if (error) reject(error);
            else if (best) resolve(best);
            else reject(lastError ?? positionError(3));
        };
        const cancel = () => finish(new Error('Pengambilan lokasi dibatalkan.'));
        if (signal?.aborted) { cancel(); return; }
        signal?.addEventListener('abort', cancel, { once: true });
        timer = setTimeout(() => finish(), timeoutMs);
        try {
            watchId = geolocation.watchPosition(position => {
                if (finished) return;
                const { latitude, longitude, accuracy } = position.coords;
                const age = now() - position.timestamp;
                if (![latitude, longitude, accuracy, position.timestamp].every(Number.isFinite)
                    || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || accuracy <= 0 || age > 15000 || age < -30000) return;
                const point = { latitude, longitude, accuracy, captured_at: new Date(position.timestamp).toISOString(), is_mocked: false };
                if (!best || point.accuracy <= best.accuracy) best = point;
                onProgress(best);
                if (best.accuracy <= OFFICE_LOCATION.maxAccuracy) finish();
            }, error => {
                if (finished) return;
                lastError = positionError(error.code);
                if (error.code === 1) finish(lastError);
            }, { enableHighAccuracy: true, maximumAge: 0, timeout: timeoutMs });
            // Native callbacks are asynchronous; also clean up synchronous test/providers.
            if (finished && watchId !== undefined) geolocation.clearWatch(watchId);
        } catch {
            finish(new Error('Lokasi perangkat belum dapat diakses. Periksa izin lokasi peramban.'));
        }
    });
}

export function validateAttendancePoint(point) {
    if (point.accuracy > OFFICE_LOCATION.maxAccuracy) {
        throw new Error(`Perkiraan lokasi perangkat masih ±${Math.ceil(point.accuracy)} meter setelah pencarian. Diperlukan akurasi maksimal ${OFFICE_LOCATION.maxAccuracy} meter. Aktifkan layanan lokasi dan Wi-Fi; gunakan HP jika laptop belum mendapat lokasi yang presisi.`);
    }
    const distance = distanceMeters(point.latitude, point.longitude);
    if (distance > OFFICE_LOCATION.radius) {
        throw new Error(`Lokasi perangkat terukur sekitar ${Math.ceil(distance)} meter dari kantor. Presensi harus dalam radius ${OFFICE_LOCATION.radius} meter.`);
    }
    return distance;
}
