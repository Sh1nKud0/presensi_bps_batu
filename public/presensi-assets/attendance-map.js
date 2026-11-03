import { OFFICE_LOCATION } from './domain.js?v=20261029-gps170-r1';
let library;
function leaflet() {
    if (window.L) return Promise.resolve(window.L);
    if (!library) library = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = '/presensi-assets/vendor/leaflet/leaflet.js?v=1.9.4';
        script.onload = () => resolve(window.L);
        script.onerror = () => { library = null; script.remove(); reject(new Error('Peta belum dapat dimuat.')); };
        document.head.append(script);
    });
    return library;
}
export async function mountAttendanceMap(element) {
    const L = await leaflet();
    if (!element.isConnected) return null;
    const office = [OFFICE_LOCATION.latitude, OFFICE_LOCATION.longitude];
    const map = L.map(element, { zoomControl: false, scrollWheelZoom: false, zoomAnimation: false, fadeAnimation: false, markerZoomAnimation: false }).setView(office, 18);
    L.control.zoom({ position: 'topright' }).addTo(map);
    const tile = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' }).addTo(map);
    tile.on('tileerror', () => { const note = document.querySelector('#map-service-note'); if (note) note.hidden = false; });
    const area = L.circle(office, { radius: OFFICE_LOCATION.radius, color: '#304eb5', weight: 2, fillColor: '#465dba', fillOpacity: 0.16 }).addTo(map);
    L.marker(office, { icon: L.divIcon({ className: 'office-map-marker', html: '<span aria-hidden="true">▥</span>', iconSize: [34, 34], iconAnchor: [17, 17] }), title: 'BPS Kota Batu', keyboard: true }).addTo(map).bindPopup('BPS Kota Batu · radius 100 meter');
    let position, accuracy;
    const resize = new ResizeObserver(() => map.invalidateSize()); resize.observe(element);
    map.fitBounds(area.getBounds(), { padding: [24, 24], maxZoom: 18 });
    return {
        update(point) {
            const latlng = [point.latitude, point.longitude];
            if (!position) {
                accuracy = L.circle(latlng, { radius: point.accuracy, color: '#4779dd', fillOpacity: 0.06, weight: 1 }).addTo(map);
                position = L.circleMarker(latlng, { pane: 'markerPane', radius: 8, color: '#fff', weight: 3, fillColor: '#2345b6', fillOpacity: 1 }).addTo(map).bindTooltip('Posisi perangkat');
            } else { position.setLatLng(latlng); accuracy.setLatLng(latlng).setRadius(point.accuracy); }
        },
        clearDevice() { if (position) map.removeLayer(position); if (accuracy) map.removeLayer(accuracy); position = null; accuracy = null; },
        centerOffice() { map.fitBounds(area.getBounds(), { padding: [24, 24], maxZoom: 18 }); },
        centerDevice() { if (position) map.setView(position.getLatLng(), 18); else map.setView(office, 18); },
        destroy() { resize.disconnect(); map.stop(); map.remove(); },
    };
}
