import { attendanceEligibility } from './attendance-state.js?v=20261103-flow1';
import { mountAttendanceMap } from './attendance-map.js?v=20261103-flow1';
import { monthRange, moveMonth, attendanceCalendar } from './attendance-calendar.js?v=20261103';
import { decisionHistory } from './request-history.js?v=20261103';
import { dashboardSummary } from './dashboard.js?v=20261103-presensi';
import { escapeHtml as e, todayWib, timeWib, dateLabel, datetimeLabel, shiftDay, distanceMeters, dailyStatuses, OFFICE_LOCATION } from './domain.js?v=20261029-gps170-r1';
import { collectLocation, validateAttendancePoint } from './location.js?v=20261029-gps170-r1';

const $ = selector => document.querySelector(selector);
const state = { user: null, tab: 'home', authMode: 'login', csrf: $('meta[name="csrf-token"]').content, filters: {}, pages: {}, epoch: 0, busy: false, session: 0 };
const PAGE_SIZE = 25;
const navIcons = {"home":"M3 10 12 3l9 7v11h-6v-7H9v7H3Z","attendance":"M8 3H5v18h14V3h-3M9 3h6v4H9ZM8 13l3 3 5-5","history":"M3 12a9 9 0 1 0 3-7M3 3v6h6M12 7v5l3 2","requests":"M14 3H5v18h14V8ZM14 3v5h5M8 12h8M8 16h5","files":"M8 12l6-6a3 3 0 0 1 4 4l-8 8a4 4 0 0 1-6-6l8-8","holidays":"M3 6h18v15H3ZM7 3v6M17 3v6M3 11h18M8 15h2M14 15h2","profile":"M5 21v-2a7 7 0 0 1 14 0v2M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8","users":"M3 21v-2a6 6 0 0 1 12 0v2M9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8M17 4a4 4 0 0 1 0 8M18 15a5 5 0 0 1 3 5","report":"M4 3h16v18H4ZM8 17v-4M12 17V7M16 17v-7"};
Object.assign(navIcons, { theme:'M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8', edit:'m4 16-1 5 5-1L20 8l-4-4ZM13 7l4 4', lock:'M5 10h14v11H5ZM8 10V7a4 4 0 0 1 8 0v3', logout:'M10 4H5v16h5M14 8l4 4-4 4M8 12h10' });
function navIcon(key) { return '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="'+(navIcons[key] || navIcons.home)+'"/></svg>'; }
const localTest = document.body.dataset.localTest === 'true';
const kinds = { izin: 'Izin / sakit', susulan: 'Presensi susulan', pembatalan: 'Pembatalan pulang' };
const spinner = '<div class="loading-panel"><span class="spinner"></span>Memuat data terbaru…</div>';
let modalCleanup = () => {};
let googleEpoch = 0;
let googleScriptPromise;
let googleButtonObserver;
let googleChallengePending = Promise.resolve();
let pendingGoogleCredential = null;
let locationController;

function notify(message, error = false) {
    $('#notice').textContent = message;
    $('#notice').classList.toggle('error', error);
    $('#notice').hidden = !message;
}
function setNotificationCount(value) {
    const count = Number(value);
    const unread = Number.isFinite(count) && count > 0 ? count : 0;
    $('#header-notification-dot').hidden = unread === 0;
    $('#header-notification').setAttribute('aria-label', unread ? `Notifikasi, ${unread} belum dibaca` : 'Notifikasi');
}
function synced() { $('#sync-status').textContent = `Diperbarui ${timeWib(new Date())} WIB · ${localTest ? 'Data uji lokal terpisah' : 'Data yang sama dengan aplikasi Android'}`; }
async function api(method, path, { query, body, bytes, mime, binary = false } = {}) {
    const url = new URL(`/presensi/api/${path}`, location.origin);
    for (const [key, value] of Object.entries(query ?? {})) if (value !== '' && value != null) url.searchParams.set(key, value);
    const headers = { Accept: binary ? '*/*' : 'application/json', 'X-CSRF-TOKEN': state.csrf };
    if (!['GET', 'HEAD'].includes(method)) headers['Content-Type'] = mime ?? 'application/json';
    const session = state.session;
    let response;
    try {
        response = await fetch(url, { method, headers, credentials: 'same-origin', cache: 'no-store', redirect: 'error',
            body: ['GET', 'HEAD'].includes(method) ? undefined : bytes ?? JSON.stringify(body ?? {}), signal: AbortSignal.timeout(50000) });
    } catch {
        throw new Error('Koneksi terputus atau layanan belum merespons. Jika baru mengirim data, periksa riwayat sebelum mengirim ulang.');
    }
    if (response.status === 419) {
        throw new Error('Sesi halaman sudah berubah. Muat ulang halaman ini lalu coba kembali.');
    }
    if (binary && response.ok) return response.blob();
    const data = await response.json().catch(() => ({}));
    if (data.csrf_token) state.csrf = data.csrf_token;
    if (!response.ok) {
        if (response.status === 401 && state.user && session === state.session) {
            showAuth();
            notify('Sesi presensi berakhir. Silakan masuk kembali.', true);
        }
        const error = new Error(data.error ?? data.message ?? `Permintaan gagal (${response.status}).`);
        error.status = response.status;
        error.code = data.code;
        throw error;
    }
    return data;
}
async function all(path, key, query = {}) {
    const rows = [];
    while (true) {
        const data = await api('GET', path, { query: { ...query, limit: 100, offset: rows.length } });
        if (!Array.isArray(data[key])) throw new Error('Format data layanan presensi tidak sesuai.');
        rows.push(...data[key]);
        if (data[key].length < 100) return rows;
    }
}
function showAuth(mode = 'login') {
    state.user = null; state.session++; state.epoch++;
    state.filters = {}; state.pages = {}; state.selectedRequest = null; seenNotifications.clear(); closeNotifications(); clearProofs();
    delete state.locationPoint; delete state.historyCalendar; delete state.historyRecords; delete state.attendancePane;
    $('#workspace').hidden = true; $('#auth').hidden = false; $('#loading').hidden = true;
    $('#account-menu').open = false; $('#account-menu').hidden = true; $('#header-actions').hidden = true; $('#header-label').hidden = false; setNotificationCount(0);
    document.body.classList.add('auth-screen');
    document.body.classList.remove('participant-dashboard', 'reference-flow');
    delete document.body.dataset.view;
    destroyAttendanceView();
    $('#content').replaceChildren();
    closeModal();
    $('#auth-form').reset();
    setAuthMode(mode);
    initGoogle();
}
function setAuthMode(mode) {
    state.authMode = mode;
    const register = mode === 'register';
    for (const button of document.querySelectorAll('[data-auth]')) {
        const active = button.dataset.auth === mode;
        button.classList.toggle('selected', active);
        button.setAttribute('aria-pressed', String(active));
    }
    $('#name-field').hidden = !register; $('#confirmation-field').hidden = !register;
    $('#name-field input').required = register; $('#confirmation-field input').required = register;
    $('#auth-form [name=password]').autocomplete = register ? 'new-password' : 'current-password';
    $('#auth-form [name=password]').minLength = register ? 8 : 1;
    $('#auth-title').textContent = register ? 'Buat akun presensimu' : 'Masuk ke akunmu';
    $('#auth-description').textContent = register ? (localTest ? 'Buat akun peserta untuk pengujian di komputer ini.' : 'Daftar sekali, gunakan di web dan aplikasi Android.') : 'Lanjutkan aktivitas magangmu di BPS Kota Batu.';
    for (const toggle of document.querySelectorAll('[data-toggle-password]')) {
        document.getElementById(toggle.dataset.togglePassword).type = 'password';
        toggle.setAttribute('aria-pressed', 'false'); toggle.setAttribute('aria-label', 'Tampilkan kata sandi');
    }
    $('#auth-submit').textContent = register ? 'Daftar sebagai peserta →' : 'Masuk ke Presensi →';
    $('#auth-error').hidden = true;
}
function showWorkspace(user) {
    googleEpoch++;
    googleButtonObserver?.disconnect();
    pendingGoogleCredential = null;
    state.user = user; state.session++; state.tab = 'home';
    $('#auth').hidden = true; $('#loading').hidden = true; $('#workspace').hidden = false;
    $('#header-label').hidden = true; $('#header-actions').hidden = false; $('#account-menu').hidden = false; $('#account-menu').open = false;
    document.body.classList.remove('auth-screen');
    document.body.classList.toggle('participant-dashboard', user.role !== 'admin');
    document.body.classList.toggle('reference-flow', user.role !== 'admin');
    $('#greeting').textContent = `Halo, ${user.nama_lengkap}`;
    $('#role-tag').textContent = user.role;
    $('#account-name').textContent = user.nama_lengkap;
    $('#workspace-subtitle').textContent = user.role === 'admin' ? 'Pantau kehadiran dan kelola pengajuan peserta magang.' : 'Siap untuk mulai berkarya hari ini?';
    const tabs = user.role === 'admin'
        ? [['home', 'Ringkasan'], ['requests', 'Persetujuan'], ['report', 'Rekap presensi'], ['users', 'Peserta'], ['holidays', 'Hari libur'], ['profile', 'Profil']]
        : [['home', 'Beranda'], ['attendance', 'Presensi'], ['history', 'Riwayat'], ['profile', 'Profil']];
    $('#tabs').innerHTML = tabs.map(([tab, title]) => `<button type="button" data-tab="${tab}">${navIcon(tab)}<span>${title}</span></button>`).join('');
    const rendered = renderTab();
    pollNotifications().catch(() => {});
    return rendered;
}

function googleLibrary() {
    if (window.google?.accounts?.id) return Promise.resolve();
    if (!googleScriptPromise) googleScriptPromise = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://accounts.google.com/gsi/client'; script.async = true;
        const timeout = setTimeout(() => { script.remove(); googleScriptPromise = null; reject(new Error('Google belum dapat dimuat. Periksa koneksi, lalu coba lagi.')); }, 15000);
        script.onload = () => { clearTimeout(timeout); resolve(); };
        script.onerror = () => { clearTimeout(timeout); script.remove(); googleScriptPromise = null; reject(new Error('Google belum dapat dimuat. Silakan gunakan email atau coba lagi.')); };
        document.head.append(script);
    });
    return googleScriptPromise;
}
async function initGoogle() {
    const epoch = ++googleEpoch;
    googleButtonObserver?.disconnect();
    const container = $('#google-official-button');
    container.replaceChildren(); container.hidden = true; $('#google-unavailable').hidden = false; $('#google-retry').hidden = true;
    if (!$('#google-signin').dataset.clientId) { $('#google-status').textContent = 'Login Google belum diaktifkan. Gunakan email untuk sementara.'; return; }
    $('#google-status').textContent = 'Menyiapkan login Google…';
    try {
        const challenge = api('POST', 'auth/google/challenge');
        googleChallengePending = challenge.catch(() => {});
        const config = await challenge;
        await googleLibrary();
        if (epoch !== googleEpoch || state.user) return;
        window.google.accounts.id.initialize({ client_id: config.client_id, nonce: config.nonce, auto_select: false,
            ux_mode: 'popup', use_fedcm_for_button: true, callback: response => {
                if (epoch !== googleEpoch || state.user || state.busy || !response.credential) return;
                run($('#auth-form'), () => finishGoogle(response.credential));
            } });
        container.hidden = false; $('#google-unavailable').hidden = true;
        let renderedWidth;
        const renderButton = () => {
            const width = Math.min(400, Math.floor($('#google-signin').clientWidth));
            if (epoch !== googleEpoch || state.user || width === renderedWidth || width < 1) return;
            renderedWidth = width;
            container.replaceChildren();
            window.google.accounts.id.renderButton(container, { type: 'standard', theme: 'outline', size: 'large', text: 'continue_with', shape: 'rectangular', logo_alignment: 'left', width });
        };
        renderButton();
        googleButtonObserver = new ResizeObserver(renderButton);
        googleButtonObserver.observe($('#google-signin'));
        $('#google-status').textContent = 'Satu akun Google untuk masuk atau mendaftar sebagai peserta.';
        $('#google-retry').hidden = false;
    } catch (error) {
        if (epoch !== googleEpoch || state.user) return;
        $('#google-status').textContent = error.message;
        $('#google-retry').hidden = false;
    }
}
async function finishGoogle(credential, existingPassword) {
    try {
        const data = await api('POST', 'auth/google', { body: { credential, ...(existingPassword !== undefined ? { existing_password: existingPassword } : {}) } });
        closeModal(); $('#auth-form').reset(); notify(''); await showWorkspace(data.user);
    } catch (error) {
        if (error.code === 'google_link_required') {
            openModal('Hubungkan akun presensi', '<p>Email Google ini sudah memiliki akun presensi. Masukkan kata sandi presensi untuk menghubungkan keduanya. Data dan peran akun Anda tetap sama.</p><form data-action="google-link"><label>Kata sandi presensi<input type="password" name="existing_password" autocomplete="current-password" required maxlength="256"></label><p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button primary wide">Hubungkan & masuk</button></form>');
            pendingGoogleCredential = credential;
            modalCleanup = () => { pendingGoogleCredential = null; };
            return;
        }
        if (['google_challenge_expired', 'google_invalid_credential', 'google_retry'].includes(error.code)) {
            closeModal(); initGoogle();
        }
        throw error;
    }
}
function badge(value, label = value) { return `<span class="badge ${e(String(value ?? '').replace(/[^a-z_]/g, ''))}">${e(label ?? 'Belum tercatat')}</span>`; }
function empty(message = 'Belum ada data untuk ditampilkan.') { return `<div class="empty"><strong>Belum ada catatan</strong>${e(message)}</div>`; }
function table(headers, rows) { return rows.length ? `<div class="table-wrap"><table><thead><tr>${headers.map(h => `<th scope="col">${e(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(cell => `<td>${cell}</td>`).join('')}</tr>`).join('')}</tbody></table></div>` : empty(); }
function stat(label, value, note = '') { return `<div class="stat"><small>${e(label)}</small><strong>${e(value)}</strong><span>${e(note)}</span></div>`; }
function filterFor(key, defaults = {}) { return state.filters[key] ??= { ...defaults }; }
function offset(key) { return (state.pages[key] ?? 0) * PAGE_SIZE; }
function pager(key, count) { const page = state.pages[key] ?? 0; return `<div class="pager"><span>Halaman ${page + 1} · ${count} catatan</span><div><button class="button subtle" data-page="${key}" data-direction="-1" ${page === 0 ? 'disabled' : ''}>Sebelumnya</button><button class="button subtle" data-page="${key}" data-direction="1" ${count < PAGE_SIZE ? 'disabled' : ''}>Berikutnya</button></div></div>`; }
function rangeFilter(key, values, extra = '') { return `<form class="filters" data-filter="${key}"><label>Dari tanggal<input type="date" name="from" value="${e(values.from)}" required></label><label>Sampai tanggal<input type="date" name="to" value="${e(values.to)}" required></label>${extra}</form>`; }
async function renderTab({ silent = false } = {}) {
    if (!state.user) return;
    const epoch = ++state.epoch;
    destroyAttendanceView();
    document.body.dataset.view = state.tab;
    document.querySelectorAll('[data-tab]').forEach(button => { const active = button.dataset.tab === state.tab; button.classList.toggle('active', active); button.setAttribute('aria-current', active ? 'page' : 'false'); });
    if (!silent) $('#content').innerHTML = spinner;
    try {
        const renderers = { home: state.user.role === 'admin' ? adminHome : participantHome, attendance: participantAttendance, history: attendanceHistory, requests: requestsPage, report: reportPage, users: usersPage, holidays: holidaysPage, notifications: notificationsPage, files: filesPage, profile: profilePage };
        const html = await renderers[state.tab]();
        if (epoch !== state.epoch || !state.user) return;
        const focused = document.activeElement;
        const searchFocus = focused?.matches('form[data-filter] input[type="text"], form[data-filter] input:not([type])') ? { name: focused.name, start: focused.selectionStart, end: focused.selectionEnd } : null;
        clearProofs();
        $('#content').innerHTML = html;
        if (searchFocus) {
            const input = [...document.querySelectorAll('#content form[data-filter] input')].find(input => input.name === searchFocus.name);
            if (input) { input.focus(); input.setSelectionRange(searchFocus.start, searchFocus.end); }
        }
        if (state.tab === 'attendance') initializeAttendanceView();
        synced();
    } catch (error) {
        if (epoch !== state.epoch || !state.user) return;
        if (!silent) $('#content').innerHTML = '<div class="card empty"><strong>Data belum dapat dimuat</strong>Periksa koneksi Anda, kemudian tekan Perbarui.</div>';
        notify(error.message, true);
        $('#sync-status').textContent = 'Pembaruan belum berhasil. Data terbaru akan tampil setelah layanan terhubung.';
    }
}

async function participantHome() {
    const [today, notifications] = await Promise.all([api('GET', 'attendance/today'), api('GET', 'notifications', { query: { limit: 1 } })]);
    state.today = today; setNotificationCount(notifications.unread_count);
    const summary = dashboardSummary(today); const row = summary.attendance;
    const fullDate = new Intl.DateTimeFormat('id-ID', { timeZone: 'Asia/Jakarta', weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }).format(new Date(`${String(today.tanggal).slice(0,10)}T12:00:00+07:00`));
    const time = value => value ? timeWib(value) : '--:--';
    return `<div class="android-home"><section class="mobile-status-card"><h2>STATUS HARI INI</h2><p class="mobile-date">${e(fullDate)}</p><div class="mobile-status-grid"><div class="mobile-status-item">${navIcon('attendance')}<strong>${e(time(row?.jam_masuk))}</strong><span>Masuk</span></div><div class="mobile-status-item">${navIcon('attendance')}<strong>${e(time(row?.jam_pulang))}</strong><span>Pulang</span></div><div class="mobile-status-item">${navIcon('history')}<strong class="work-time">${summary.hours}j ${summary.remainingMinutes}m</strong><span>Kerja</span></div></div></section>
    <button class="mobile-attendance-button" data-tab="attendance" ${summary.available ? '' : 'disabled'}>${fingerprintIcon()}${e(summary.action)}</button>
    ${today.block_reason ? `<p class="mobile-block-reason">${e(today.block_reason)}</p>` : ''}${!row?.jam_masuk && !today.hari_libur && !today.block_reason ? '<div class="mobile-reminder"><strong>Anda belum presensi hari ini!</strong><span>Segera lakukan presensi. Jika ada kendala kegiatan di luar BPS atau GPS, ajukan Presensi Susulan di menu Profil.</span></div>' : ''}
    ${canCancel(row, today.tanggal) ? '<button class="mobile-cancel" data-new-request="pembatalan">Ajukan pembatalan presensi pulang</button>' : ''}${summary.complete ? '<div class="mobile-target">Target jam kerja hari ini sudah tercapai (8 jam+).</div>' : ''}</div>`;
}
function fingerprintIcon() { return '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M4 10a8 8 0 0 1 16 0M7 11a5 5 0 1 1 10 0c0 4-.4 7-2 10M10 20c1-2 1-5 1-9a1 1 0 1 1 2 0c0 4 0 6-.6 9M5 13c0 2 0 4-1 6m15-6c0 2 0 4-.5 6"/></svg>'; }
async function participantAttendance() {
    const today = await api('GET', 'attendance/today'); state.today = today;
    const kind = today.can_check_in ? 'check-in' : today.can_check_out ? 'check-out' : null;
    return `<section class="android-attendance"><div class="page-title"><h2>Lakukan Presensi</h2><p>Periksa posisi Anda, lalu kirim presensi ${kind === 'check-out' ? 'pulang' : 'masuk'}.</p></div><div class="map-attendance-layout"><section class="area-card"><div class="area-header"><div><h3>Area presensi</h3><p>BPS Kota Batu</p></div><span class="area-state" id="area-state" role="status">Mencari lokasi…</span></div><div class="live-map-wrap"><div id="attendance-live-map" role="region" aria-label="Peta kantor, radius presensi, dan posisi perangkat"></div><div class="map-extra-controls"><button type="button" data-map-center="office" aria-label="Pusatkan kantor" title="Pusatkan kantor">▥</button><button type="button" data-map-center="device" aria-label="Pusatkan perangkat" title="Pusatkan perangkat">◎</button></div></div><p id="map-service-note" class="map-service-note" hidden>Peta dasar belum tersedia. Radius dan validasi lokasi perangkat tetap diperiksa.</p><div class="area-footer"><div><span>Jarak ke kantor</span><strong id="location-distance">—</strong><small id="location-accuracy">Menunggu posisi perangkat</small></div><button class="text-link" data-locate>↻ Perbarui</button></div></section><aside class="attendance-send-panel"><p id="location-result" role="status" aria-live="polite">Izinkan akses lokasi untuk memastikan Anda berada dalam area kantor.</p><div id="location-reading" class="location-reading" hidden><span id="location-coordinates"></span><a id="device-location-link" target="_blank" rel="noopener noreferrer">Lihat titik perangkat di peta</a></div><button class="text-link" data-location-cancel hidden>Batalkan pencarian lokasi</button><div class="send-cta"><button type="button" class="mobile-attendance-button" id="send-attendance" data-punch="${kind || 'check-in'}" disabled>${fingerprintIcon()}<span>${kind ? `Kirim Presensi ${kind === 'check-in' ? 'Masuk' : 'Pulang'}` : 'Presensi tidak tersedia'}</span></button><p id="attendance-block-reason" class="small-note">${e(today.block_reason || (!kind ? 'Presensi hari ini sudah lengkap atau belum tersedia.' : 'Menunggu lokasi yang memenuhi radius dan akurasi.'))}</p></div><div class="attendance-times"><div><span>Masuk</span><strong id="attendance-time-in">${e(timeWib(today.attendance?.jam_masuk))}</strong></div><div><span>Pulang</span><strong id="attendance-time-out">${e(timeWib(today.attendance?.jam_pulang))}</strong></div></div><p class="small-note">Radius kantor ${OFFICE_LOCATION.radius} m · akurasi maksimal ${OFFICE_LOCATION.maxAccuracy} m. Waktu presensi mengikuti server (WIB).</p><button class="text-link" data-tab="history">Lihat riwayat kehadiran →</button></aside></div></section>`;
}
async function participantProfile() {
    const [{ user }, statistics] = await Promise.all([api('GET', 'me'), api('GET', 'me/statistics')]); state.user = user;
    const action = (icon, title, attr, note = '') => `<button type="button" class="profile-action" ${attr}>${navIcon(icon)}<span><strong>${title}</strong>${note ? `<small>${note}</small>` : ''}</span><b aria-hidden="true">›</b></button>`;
    return `<div class="android-profile"><div class="page-title"><h2>Profil</h2></div><div class="profile-layout"><div class="profile-overview"><section class="profile-identity"><span class="profile-portrait">${navIcon('profile')}</span><h3>${e(user.nama_lengkap)}</h3><p>Peserta Magang</p></section><div class="profile-totals"><section><h3><span class="profile-stat-check">✓</span>Hadir</h3><strong>${e(statistics.hadir ?? 0)} <small>Hari</small></strong></section><section><h3>${navIcon('requests')}Izin/Sakit</h3><strong>${e(statistics.izin ?? 0)} <small>Disetujui</small></strong></section></div><p class="small-note profile-count-note">Izin/sakit menampilkan jumlah pengajuan yang disetujui.</p></div><section class="profile-menu"><h3>AKTIVITAS</h3>${action('holidays','Izin / Sakit','data-new-request="izin"')}${action('history','Presensi Susulan','data-new-request="susulan"')}${action('requests','Pengajuan & riwayat keputusan','data-tab="requests"')}<h3>TAMPILAN</h3><button type="button" class="profile-action" data-theme-toggle role="switch" aria-checked="${document.body.dataset.theme === 'dark'}">${navIcon('theme')}<span><strong>Mode gelap</strong><small data-theme-label>${document.body.dataset.theme === 'dark' ? 'Aktif' : 'Nonaktif'}</small></span><span class="theme-switch" aria-hidden="true"></span></button><h3>PENGATURAN AKUN</h3>${action('edit','Edit Profil','data-profile-editor')}${action('lock',user.has_password === false ? 'Buat kata sandi' : 'Ganti kata sandi','data-password-editor')}${action('files','Kelola bukti pengajuan','data-tab="files"')}${action('logout','Keluar','id="profile-logout"')}</section></div></div>`;
}
function participantProfileForm(user) {
    return `<form data-action="profile"><label>Nama lengkap<input name="nama_lengkap" maxlength="150" value="${e(user.nama_lengkap)}" required></label><label>Email<input value="${e(user.email)}" type="email" disabled></label><label>NIM<input name="nim" maxlength="200" value="${e(user.nim)}"></label><label>Asal instansi<input name="asal_instansi" maxlength="200" value="${e(user.asal_instansi)}"></label><label>Nomor HP<input name="no_hp" type="tel" maxlength="200" value="${e(user.no_hp)}"></label><p class="form-error" data-modal-error role="alert" hidden></p><button class="button primary" type="submit">Simpan profil</button></form>`;
}
function participantPasswordForm(user) {
    return `<p class="small-note">${user.has_password === false ? 'Buat kata sandi setelah baru masuk dengan Google.' : 'Seluruh sesi web dan Android berakhir setelah kata sandi diubah.'}</p><form data-action="password">${user.has_password === false ? '' : '<label>Kata sandi saat ini<input name="current_password" type="password" autocomplete="current-password" required maxlength="256"></label>'}<label>Kata sandi baru<input name="new_password" type="password" autocomplete="new-password" minlength="8" maxlength="256" required></label><label>Ulangi kata sandi baru<input name="confirmation" type="password" autocomplete="new-password" required maxlength="256"></label><p class="form-error" data-modal-error role="alert" hidden></p><button class="button primary" type="submit">${user.has_password === false ? 'Buat kata sandi' : 'Ubah kata sandi'}</button></form>`;
}

function canCancel(row, day) { return row?.jam_pulang && row.tanggal.slice(0, 10) === day && ['hadir', 'terlambat'].includes(row.status) && timeWib(row.jam_pulang) < '16:00'; }
async function adminHome() {
    const f = filterFor('home', { date: todayWib() });
    const [attendance, participants, leaves, approvedLeaves, supplementary, notifications] = await Promise.all([
        all('admin/attendance', 'attendance', { from: f.date, to: f.date }), all('admin/participants', 'participants'),
        all('admin/requests/izin', 'requests', { status: 'menunggu' }), all('admin/requests/izin', 'requests', { status: 'disetujui' }),
        all('admin/requests/susulan', 'requests', { status: 'menunggu' }), api('GET', 'notifications', { query: { limit: 1 } }),
    ]);
    setNotificationCount(notifications.unread_count);
    const rows = dailyStatuses(f.date, participants, attendance, [...leaves, ...approvedLeaves], supplementary);
    return `<div class="stats">${stat('Peserta magang', participants.length, 'Terdaftar di presensi')}${stat('Sudah masuk', rows.filter(r => r.attendance?.jam_masuk).length, dateLabel(f.date))}${stat('Izin / sakit', rows.filter(r => ['izin', 'sakit'].includes(r.status)).length, 'Pengajuan disetujui')}${stat('Notifikasi baru', notifications.unread_count ?? 0, 'Menunggu tindak lanjut')}</div><section class="card"><div class="section-heading"><div><h2>Kehadiran peserta</h2><p class="muted">Presensi dan status pengajuan pada tanggal pilihan.</p></div><button class="button primary" data-tab="requests">Tinjau pengajuan →</button></div><form class="filters" data-filter="home"><label>Tanggal<input type="date" name="date" required value="${e(f.date)}"></label><label>Cari peserta<input name="search" value="${e(f.search ?? '')}" placeholder="Nama peserta"></label></form>
    ${table(['Peserta', 'Asal instansi', 'Status', 'Masuk WIB', 'Pulang WIB'], rows.filter(r => r.profile.nama_lengkap.toLowerCase().includes((f.search ?? '').toLowerCase())).map(r => [e(r.profile.nama_lengkap), e(r.profile.asal_instansi ?? '—'), badge(r.status, r.label), e(timeWib(r.attendance?.jam_masuk)), e(timeWib(r.attendance?.jam_pulang))]))}</section>`;
}
async function attendanceHistory() {
    const today = todayWib();
    const f = filterFor('history', { period: today.slice(0, 7), selected: today });
    const range = monthRange(f.period);
    const [attendance, leaves, holidays] = await Promise.all([
        all('attendance/history', 'attendance', { from: range.from, to: range.to }),
        all('requests/izin', 'requests', { status: 'disetujui' }),
        all('holidays', 'holidays', { from: range.from, to: range.to }),
    ]);
    const calendar = attendanceCalendar(f.period, attendance, leaves, holidays);
    state.historyCalendar = calendar;
    if (!calendar.days.some(d => d.date === f.selected)) f.selected = today.startsWith(f.period) ? today : range.from;
    const title = new Intl.DateTimeFormat('id-ID', { month: 'long', year: 'numeric', timeZone: 'Asia/Jakarta' }).format(new Date(`${range.from}T12:00:00+07:00`));
    state.historyRecords = attendance;
    return `<div class="android-history history-calendar-page"><div class="page-title"><h2>Riwayat</h2></div><section class="calendar-period" aria-label="Periode riwayat"><button type="button" class="calendar-arrow" data-history-month="-1" aria-label="Bulan sebelumnya" ${f.period === '2000-01' ? 'disabled' : ''}>‹</button><div><span>PERIODE MAGANG</span><h3>${e(title)}</h3></div><button type="button" class="calendar-arrow" data-history-month="1" aria-label="Bulan berikutnya" ${f.period === '2100-12' ? 'disabled' : ''}>›</button></section>
    <section class="attendance-calendar card" aria-label="Kalender ${e(title)}"><div class="calendar-weekdays">${['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((label, i) => `<span class="${i > 4 ? 'weekend-label' : ''}">${label}</span>`).join('')}</div><div class="calendar-dates" role="group" aria-label="Tanggal presensi">${'<span class="calendar-blank" aria-hidden="true"></span>'.repeat(calendar.leading)}${calendar.days.map(d => `<button type="button" data-history-day="${d.date}" class="calendar-day ${d.weekend ? 'is-weekend' : ''} ${d.holiday ? 'is-holiday' : ''} ${d.date === f.selected ? 'is-selected' : ''}" aria-pressed="${d.date === f.selected}" ${d.date === today ? 'aria-current="date"' : ''} aria-label="${e(`${dateLabel(d.date)}, ${d.label}${d.holiday ? ', '+d.holiday.keterangan.replace(/^\[Kalender Indonesia\] /, '') : d.weekend ? ', Akhir pekan' : ''}`)}"><span>${d.day}</span><i class="calendar-dot status-${d.status}" aria-hidden="true"></i>${d.holiday ? '<i class="holiday-dot" aria-hidden="true"></i>' : ''}</button>`).join('')}</div>
    <div class="calendar-legend">${[['hadir','Hadir'],['terlambat','Terlambat'],['izin','Izin/Sakit'],['dispensasi','Dispensasi'],['holiday','Libur Nasional']].map(([status,label]) => `<span><i class="calendar-dot status-${status}"></i>${label}</span>`).join('')}<span class="weekend-label">Sab/Min Libur</span></div></section>
    <div class="calendar-summary">${[['hadir','Total Hadir','Hari','attendance'],['terlambat','Terlambat','Kali','history'],['izin','Izin/Sakit','Hari','requests'],['libur','Hari Libur','Hari','holidays']].map(([key,label,unit,icon]) => `<div class="calendar-stat stat-${key}"><span class="calendar-stat-icon">${navIcon(icon)}</span><div><h3>${label}</h3><strong>${calendar.stats[key]} <small>${unit}</small></strong></div></div>`).join('')}</div>
    <button type="button" class="text-link calendar-ledger-link" data-history-ledger>Daftar catatan bulan ini →</button></div>`;
}
function historyDayDetail(day) {
    if (!day) return empty('Pilih tanggal untuk melihat catatan presensi.');
    const row = day.attendance;
    const holiday = day.holiday?.keterangan?.replace(/^\[Kalender Indonesia\] /, '');
    return `<span class="eyebrow">DETAIL HARIAN</span><h2>${e(dateLabel(day.date))}</h2>${day.status === 'belum' ? '<span class="badge">Belum ada catatan</span>' : badge(day.status, day.label)}
    ${holiday || day.weekend ? `<div class="calendar-holiday-note">${e(holiday || 'Libur akhir pekan (Sabtu/Minggu)')}</div>` : ''}
    <div class="punches"><div class="punch"><small>JAM MASUK</small><strong>${e(timeWib(row?.jam_masuk))}</strong></div><div class="punch"><small>JAM PULANG</small><strong>${e(timeWib(row?.jam_pulang))}</strong></div></div>
    ${row?.jarak_dari_kantor_meter != null ? `<p class="small-note">Jarak dari kantor: ${e(Math.round(row.jarak_dari_kantor_meter))} meter.</p>` : ''}
    ${day.leave && ['izin', 'sakit'].includes(day.status) ? `<div class="info-strip"><strong>${day.status === 'sakit' ? 'Sakit' : 'Izin'} disetujui</strong><p>${e(day.leave.keterangan || '')}</p><span class="small-note">${e(dateLabel(day.leave.tanggal_mulai))} – ${e(dateLabel(day.leave.tanggal_selesai))}</span></div>` : ''}
    ${day.status === 'belum' ? `<p class="small-note">${day.date > todayWib() ? 'Tanggal ini belum berlangsung.' : 'Tidak ada catatan presensi pada tanggal ini.'}</p>` : ''}<p class="small-note">Seluruh waktu ditampilkan dalam WIB.</p>`;
}

async function requestsPage() {
    const admin = state.user.role === 'admin';
    if (state.selectedRequest) return requestDetail();
    const f = filterFor('requests', { kind: 'izin', status: admin ? 'menunggu' : '', view: 'active' });
    const history = f.view === 'history';
    let rows;
    let total;
    if (history) {
        const groups = await Promise.all((f.kind ? [f.kind] : Object.keys(kinds)).map(async kind => {
            const statuses = f.status ? [f.status] : ['disetujui', 'ditolak'];
            const requests = (await Promise.all(statuses.map(status => all(`${admin ? 'admin/' : ''}requests/${kind}`, 'requests', { status })))).flat();
            return { kind, requests };
        }));
        const decisions = decisionHistory(groups, f);
        total = decisions.length;
        rows = decisions.slice(offset('requests'), offset('requests') + PAGE_SIZE);
    } else {
        const data = await api('GET', `${admin ? 'admin/' : ''}requests/${f.kind || 'izin'}`, { query: { status: f.status, limit: PAGE_SIZE, offset: offset('requests') } });
        rows = data.requests.map(row => ({ ...row, kind: f.kind || 'izin' }));
    }
    const statuses = history ? [['', 'Semua keputusan'], ['disetujui', 'Disetujui'], ['ditolak', 'Ditolak']] : [['', 'Semua status'], ['menunggu', 'Menunggu'], ['disetujui', 'Disetujui'], ['ditolak', 'Ditolak']];
    return `<section class="card"><div class="section-heading"><div><h2>${history ? 'Riwayat persetujuan' : admin ? 'Persetujuan pengajuan' : 'Pengajuan saya'}</h2><p class="muted">${history ? (admin ? 'Riwayat keputusan seluruh peserta, diurutkan dari yang terbaru.' : 'Riwayat keputusan untuk pengajuan Anda, diurutkan dari yang terbaru.') : admin ? 'Periksa detail dan bukti sebelum memberikan keputusan.' : 'Pantau status izin, susulan, dan pembatalan jam pulang.'}</p></div>${admin || history ? '' : '<div class="actions"><button class="button subtle" data-tab="files">Kelola bukti</button><button class="button primary" data-new-request="izin">+ Buat pengajuan</button></div>'}</div>
    <div class="request-views" role="group" aria-label="Daftar pengajuan"><button type="button" class="button ${history ? 'subtle' : 'primary'}" data-request-view="active" aria-pressed="${!history}">${admin ? 'Kelola pengajuan' : 'Pengajuan saya'}</button><button type="button" class="button ${history ? 'primary' : 'subtle'}" data-request-view="history" aria-pressed="${history}">Riwayat persetujuan</button></div>
    <form class="filters" data-filter="requests"><input type="hidden" name="view" value="${history ? 'history' : 'active'}"><label>Jenis pengajuan<select name="kind">${history ? `<option value="" ${!f.kind ? 'selected' : ''}>Semua jenis</option>` : ''}${Object.entries(kinds).map(([key, label]) => `<option value="${key}" ${f.kind === key ? 'selected' : ''}>${label}</option>`).join('')}</select></label><label>${history ? 'Keputusan' : 'Status'}<select name="status">${statuses.map(([key, label]) => `<option value="${key}" ${f.status === key ? 'selected' : ''}>${label}</option>`).join('')}</select></label></form>
    ${!admin && !history ? '<div class="actions" style="margin-bottom:22px"><button class="button subtle" data-new-request="izin">Izin / sakit</button><button class="button subtle" data-new-request="susulan">Presensi susulan</button><button class="button subtle" data-new-request="pembatalan">Pembatalan pulang</button></div>' : ''}
    ${history ? `<p class="small-note">${total} keputusan ditemukan. Waktu ditampilkan dalam WIB.</p>` : ''}<div class="list">${rows.length ? rows.map(row => requestCard(row, row.kind, admin)).join('') : empty(history ? 'Belum ada keputusan persetujuan dengan filter ini.' : 'Tidak ada pengajuan dengan filter ini.')}</div>${pager('requests', rows.length)}</section>`;
}

function requestCard(row, kind, admin) {
    const label = kind === 'izin' ? (row.jenis === 'sakit' ? 'Sakit' : 'Izin') : kinds[kind];
    const period = kind === 'izin' ? `${dateLabel(row.tanggal_mulai)} – ${dateLabel(row.tanggal_selesai)}` : dateLabel(row.tanggal);
    return `<article class="request-card"><div class="request-top"><div><h3>${e(admin ? row.nama_lengkap : label)}</h3><small>${e(admin ? `${label} · ${period}` : period)}</small></div>${badge(row.status_persetujuan)}</div>
    ${kind === 'susulan' ? `<div class="request-meta"><span>Masuk: ${e(row.jam_masuk_diajukan ?? '—')} WIB</span><span>Pulang: ${e(row.jam_pulang_diajukan ?? '—')} WIB</span><span>${e(row.jenis_alasan)}</span></div>` : ''}
    ${kind === 'pembatalan' ? `<div class="request-meta"><span>Jam pulang: ${e(timeWib(row.jam_pulang_awal))} WIB</span></div>` : ''}
    <p>${e(row.keterangan ?? row.alasan ?? '')}</p><div class="request-meta"><span>Diajukan ${e(datetimeLabel(row.created_at))}</span>${row.diproses_at ? `<span>Keputusan ${e(datetimeLabel(row.diproses_at))} WIB</span>` : ''}</div>
    ${row.alasan_penolakan ? `<div class="info-strip">Alasan penolakan: ${e(row.alasan_penolakan)}</div>` : ''}
    <div class="request-proof">${proofLink(row)}</div>${admin && row.status_persetujuan === 'menunggu' ? `<div class="actions" style="margin-top:14px"><button class="button success" data-decision="true" data-kind="${kind}" data-id="${e(row.id)}" data-name="${e(row.nama_lengkap)}">Setujui</button><button class="button danger" data-decision="false" data-kind="${kind}" data-id="${e(row.id)}" data-name="${e(row.nama_lengkap)}">Tolak</button></div>` : ''}</article>`;
}
function proofLink(row) {
    if (row.bukti_id) return `<strong>Bukti pendukung</strong><button class="button subtle" data-inline-proof="${e(row.bukti_id)}" aria-expanded="false">Tampilkan bukti</button><div class="inline-proof" hidden></div>`;
    if (typeof row.bukti_url === 'string' && /^https:\/\//i.test(row.bukti_url)) return `<a class="text-link" href="${e(row.bukti_url)}" target="_blank" rel="noopener noreferrer">Lihat bukti lampiran ↗</a>`;
    return '<span class="small-note">Tidak ada bukti terlampir.</span>';
}
async function notificationsPage() {
    const f = filterFor('notifications', { date: '', unread: '' });
    const data = await api('GET', 'notifications', { query: { ...f, limit: PAGE_SIZE, offset: offset('notifications') } });
    setNotificationCount(data.unread_count);
    return `<section class="card"><div class="section-heading"><h2>Notifikasi</h2><span class="badge hadir">${e(data.unread_count)} belum dibaca</span></div><form class="filters" data-filter="notifications"><label>Tanggal (opsional)<input type="date" name="date" value="${e(f.date)}"></label><label>Tampilkan<select name="unread"><option value="">Semua</option><option value="true" ${f.unread === 'true' ? 'selected' : ''}>Belum dibaca</option></select></label></form><div class="list">${data.notifications.length ? data.notifications.map(notificationCard).join('') : empty('Belum ada notifikasi dengan filter ini.')}</div>${pager('notifications', data.notifications.length)}</section>`;
}
async function filesPage() {
    const data = await api('GET', 'files', { query: { limit: PAGE_SIZE, offset: offset('files') } });
    return `<section class="card"><div class="section-heading"><div><h2>Bukti saya</h2><p class="muted">Lampiran privat yang tersimpan pada akun presensi.</p></div></div><p class="small-note">Terpakai ${(data.used_bytes / 1048576).toFixed(2)} MiB dari ${(data.quota_bytes / 1048576).toFixed(0)} MiB. Setiap gambar maksimal 5 MiB.</p><div class="quota"><span style="width:${Math.min(100, Math.max(0, data.used_bytes / data.quota_bytes * 100))}%"></span></div><div class="list">${data.files.length ? data.files.map(file => `<div class="file-entry"><div><strong>${e(file.mime_type)}</strong><small>${e(datetimeLabel(file.created_at))} · ${(file.size_bytes / 1024).toFixed(0)} KiB</small></div><button class="button subtle" data-evidence="${e(file.id)}">Lihat / unduh</button></div>`).join('') : empty('Lampirkan bukti saat membuat pengajuan izin atau susulan.')}</div>${pager('files', data.files.length)}</section>`;
}
async function holidaysPage() {
    const day = todayWib();
    const f = filterFor('holidays', { from: `${day.slice(0, 4)}-01-01`, to: `${day.slice(0, 4)}-12-31` });
    const [data, calendar] = await Promise.all([
        api('GET', 'holidays', { query: { ...f, limit: PAGE_SIZE, offset: offset('holidays') } }),
        fetch(`/presensi-assets/calendar-status.json?v=${Date.now()}`, { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null),
    ]);
    const admin = state.user.role === 'admin';
    const status = calendar?.years?.[f.from.slice(0, 4)];
    const syncNote = status?.available ? `Terakhir berhasil disinkronkan ${datetimeLabel(status.checked_at)}. Pemeriksaan otomatis setiap jam.${calendar.ok === false ? ' Pemeriksaan terakhir terkendala; data terakhir tetap digunakan.' : ''}` : 'Data tahun ini belum tersedia dari sumber kalender. Hari libur khusus tetap dapat ditambahkan admin.';
    return `<section class="card"><div class="section-heading"><div><h2>Kalender hari libur Indonesia</h2><p class="muted">Libur nasional, cuti bersama, dan hari libur khusus kantor.</p></div>${admin ? '<button class="button primary" data-new-holiday>+ Hari libur khusus</button>' : ''}</div><div class="info-strip"><strong>Tersinkron dengan presensi web dan Android</strong><p class="small-note">${e(syncNote)} Sumber: <a href="https://github.com/ahrulsyamil/indonesian-holidays" target="_blank" rel="noopener noreferrer">Kalender Indonesia berdasarkan SKB 3 Menteri</a>.</p></div>${rangeFilter('holidays', f)}${table(['Tanggal', 'Keterangan', 'Sumber', ...(admin ? ['Tindakan'] : [])], data.holidays.map(h => {
        const automatic = h.keterangan.startsWith('[Kalender Indonesia] ');
        return [e(dateLabel(h.tanggal)), e(h.keterangan.replace(/^\[Kalender Indonesia\] /, '')), automatic ? badge('hadir', 'Kalender Indonesia') : badge('izin', 'Khusus kantor'), ...(admin ? [automatic ? '<span class="small-note">Diperbarui otomatis</span>' : `<button class="button danger" data-delete-holiday="${e(h.id)}" data-name="${e(h.keterangan)}">Hapus</button>`] : [])];
    }))}${pager('holidays', data.holidays.length)}<p class="small-note" style="margin-top:20px">Akhir pekan dan seluruh tanggal pada daftar ini mengikuti aturan PostgreSQL yang sama dengan aplikasi Android.</p></section>`;
}

async function usersPage() {
    const data = await api('GET', 'admin/participants', { query: { limit: PAGE_SIZE, offset: offset('users') } });
    return `<section class="card"><div class="section-heading"><h2>Peserta magang</h2></div>${table(['Nama lengkap', 'NIM', 'Asal instansi'], data.participants.map(p => [e(p.nama_lengkap), e(p.nim ?? '—'), e(p.asal_instansi ?? '—')]))}${pager('users', data.participants.length)}<p class="small-note" style="margin-top:20px">Daftar peserta mengikuti akun yang terdaftar pada layanan presensi.</p></section>`;
}
async function reportPage() {
    const day = todayWib();
    const f = filterFor('report', { period: day.slice(0, 7) });
    const [year, month] = f.period.split('-');
    const report = await api('GET', 'admin/rekap', { query: { month: Number(month), year: Number(year) } });
    return `<section class="card"><div class="section-heading"><div><h2>Rekap presensi bulanan</h2><p class="muted">Dibuat ${e(datetimeLabel(report.generated_at))}</p></div><button class="button primary" data-download-report>Unduh Excel ↓</button></div><form class="filters" data-filter="report"><label>Periode<input type="month" name="period" min="2000-01" max="2100-12" value="${e(f.period)}" required></label></form>
    ${table(['Nama peserta', 'Instansi', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Dispensasi', 'Alpha', 'Tanpa catatan', 'Tidak lengkap', 'Total tercatat'], report.participants.map(p => [e(p.profile.nama_lengkap), e(p.profile.asal_instansi ?? '—'), e(p.counts.hadir), e(p.counts.terlambat), e(p.counts.izin), e(p.counts.sakit), e(p.counts.dispensasi), e(p.counts.alpha), e(p.counts.tanpa_catatan), e(p.counts.tidak_lengkap), `<strong>${e(p.counts.total)}</strong>`]))}
    <p class="small-note" style="margin-top:20px">Total hadir sudah mencakup keterlambatan. Akhir pekan, hari libur, dan tanggal mendatang tidak dihitung. Tanggal tanpa catatan tidak otomatis dianggap alpha.</p>
    <div class="report-details">${report.participants.map(p => `<details><summary>${e(p.profile.nama_lengkap)} · Detail harian</summary>${table(['Tanggal', 'Status', 'Masuk WIB', 'Pulang WIB', 'Dihitung', 'Catatan'], p.days.map(d => [e(dateLabel(d.tanggal)), e(d.status), e(d.jam_masuk), e(d.jam_pulang), d.dihitung ? 'Ya' : 'Tidak', e(d.catatan)]))}</details>`).join('')}</div></section>`;
}
async function profilePage() {
    if (state.user.role !== 'admin') return participantProfile();
    const { user } = await api('GET', 'me'); state.user = user;
    const admin = user.role === 'admin';
    return `<div class="columns equal"><section class="card"><h2>${admin ? 'Profil administrator' : 'Profil saya'}</h2><p class="muted">${admin ? 'Kelola identitas dan kontak administrator Presensi Magang BPS Kota Batu.' : 'Perubahan profil juga akan terlihat di Android.'}</p><form data-action="profile"><label>Nama lengkap<input name="nama_lengkap" maxlength="150" value="${e(user.nama_lengkap)}" required></label><label>Email<input value="${e(user.email)}" type="email" disabled></label>${admin ? '<label>Peran akun<input value="Administrator" disabled></label>' : `<label>NIM<input name="nim" maxlength="200" value="${e(user.nim)}"></label>`}<label>${admin ? 'Unit kerja / instansi' : 'Asal instansi'}<input name="asal_instansi" maxlength="200" value="${e(user.asal_instansi)}" placeholder="${admin ? 'Contoh: BPS Kota Batu' : ''}"></label><label>${admin ? 'Nomor kontak' : 'Nomor HP'}<input name="no_hp" type="tel" maxlength="200" value="${e(user.no_hp)}"></label><button class="button primary" type="submit">Simpan profil</button></form></section><section class="card"><h2>${user.has_password === false ? 'Buat kata sandi' : 'Ganti kata sandi'}</h2><p class="muted">${user.has_password === false ? (admin ? 'Buat kata sandi untuk mengamankan akses administrator. Lakukan setelah baru masuk dengan Google.' : 'Buat kata sandi agar akun Google ini juga dapat digunakan untuk masuk ke aplikasi Android. Untuk keamanan, lakukan setelah baru masuk dengan Google.') : 'Setelah diubah, seluruh sesi web dan Android akan berakhir. Masuk kembali menggunakan kata sandi baru.'}</p><form data-action="password">${user.has_password === false ? '' : '<label>Kata sandi saat ini<input name="current_password" type="password" autocomplete="current-password" required maxlength="256"></label>'}<label>Kata sandi baru<input name="new_password" type="password" autocomplete="new-password" minlength="8" maxlength="256" required></label><label>Ulangi kata sandi baru<input name="confirmation" type="password" autocomplete="new-password" required maxlength="256"></label><button class="button primary" type="submit">${user.has_password === false ? 'Buat kata sandi' : 'Ubah kata sandi'}</button></form></section></div>`;
}

function openModal(title, html) {
    closeModal(); $('#modal-title').textContent = title; $('#modal-body').innerHTML = html; $('#modal').showModal();
}
function closeModal() { if ($('#modal').open) $('#modal').close(); modalCleanup(); modalCleanup = () => {}; }
async function newRequest(kind) {
    const day = todayWib();
    let fields;
    if (kind === 'izin') fields = `<label>Jenis<select name="jenis"><option value="izin">Izin</option><option value="sakit">Sakit</option></select></label><div class="details-grid"><label>Tanggal mulai<input type="date" name="tanggal_mulai" min="${shiftDay(day, -7)}" max="${shiftDay(day, 90)}" value="${day}" required></label><label>Tanggal selesai<input type="date" name="tanggal_selesai" min="${shiftDay(day, -7)}" max="${shiftDay(day, 90)}" value="${day}" required></label></div>`;
    else if (kind === 'susulan') fields = `<label>Tanggal<input type="date" name="tanggal" min="${shiftDay(day, -14)}" max="${day}" value="${day}" required></label><div class="details-grid"><label>Jam masuk (WIB)<input type="time" name="jam_masuk_diajukan" required></label><label>Jam pulang (opsional, WIB)<input type="time" name="jam_pulang_diajukan"></label></div><label>Jenis alasan<select name="jenis_alasan"><option value="lupa_absen">Lupa absen</option><option value="gps_error">Kendala GPS</option><option value="dispensasi">Dispensasi</option><option value="lainnya">Lainnya</option></select></label>`;
    else {
        const today = await api('GET', 'attendance/today');
        if (!canCancel(today.attendance, today.tanggal)) throw new Error('Pembatalan hanya tersedia untuk presensi normal hari ini dengan jam pulang sebelum 16:00 WIB.');
        fields = `<input type="hidden" name="absensi_id" value="${e(today.attendance.id)}"><div class="info-strip">Jam pulang tercatat ${e(timeWib(today.attendance.jam_pulang))} WIB. Jam pulang baru dapat dicatat setelah pembatalan disetujui admin pada hari yang sama.</div>`;
    }
    const reason = kind === 'pembatalan' ? 'alasan' : 'keterangan';
    openModal(`Ajukan ${kinds[kind].toLowerCase()}`, `<form data-action="request" data-kind="${kind}">${fields}<label>${kind === 'pembatalan' ? 'Alasan pembatalan' : 'Keterangan'}<textarea name="${reason}" required minlength="${kind === 'pembatalan' ? 5 : 3}" maxlength="1000" placeholder="Jelaskan alasan pengajuan Anda"></textarea></label>${kind !== 'pembatalan' ? '<label>Bukti (opsional)<input type="file" name="evidence" accept="image/jpeg,image/png,image/webp"><span class="small-note">JPEG, PNG, atau WebP. Maksimal 5 MiB.</span></label>' : ''}<p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button primary wide">Kirim pengajuan →</button></form>`);
}
function decisionModal(button) {
    const approve = button.dataset.decision === 'true';
    openModal(approve ? 'Setujui pengajuan' : 'Tolak pengajuan', `<p>Anda akan ${approve ? 'menyetujui' : 'menolak'} pengajuan ${e(kinds[button.dataset.kind].toLowerCase())} dari <strong>${e(button.dataset.name)}</strong>.</p><form data-action="decision" data-kind="${e(button.dataset.kind)}" data-id="${e(button.dataset.id)}" data-approve="${approve}">${approve ? '<p class="small-note">Keputusan akan langsung tersimpan dan terlihat pada akun peserta.</p>' : '<label>Alasan penolakan<textarea name="alasan_penolakan" required minlength="3" maxlength="1000"></textarea></label>'}<p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button ${approve ? 'success' : 'danger'} wide">${approve ? 'Ya, setujui' : 'Tolak pengajuan'}</button></form>`);
}
async function evidence(id) {
    const blob = await api('GET', `files/${id}`, { binary: true });
    const url = URL.createObjectURL(blob);
    openModal('Bukti lampiran', `<img class="evidence-preview" src="${url}" alt="Bukti pengajuan"><a class="button subtle" style="margin-top:18px" href="${url}" download="bukti-presensi">Unduh bukti ↓</a>`);
    modalCleanup = () => URL.revokeObjectURL(url);
}
function showLocation(point, searching = false) {
    state.locationPoint = point;
    const result = $('#location-result');
    if (!result) return;
    const precise = point.accuracy <= OFFICE_LOCATION.maxAccuracy;
    const distance = distanceMeters(point.latitude, point.longitude);
    const inside = distance <= 100;
    result.textContent = `Jarak perkiraan ${Math.ceil(distance)} m dari kantor · akurasi ±${Math.ceil(point.accuracy)} m${searching ? ' · Menunggu pembacaan lebih presisi…' : !precise ? ' · Belum memenuhi akurasi presensi.' : !inside ? ' · Di luar radius kantor.' : ' · Memenuhi radius dan akurasi lokasi.'}`;
    result.dataset.quality = searching ? 'searching' : precise && inside ? 'precise' : 'coarse';
    const stateBadge = $('#area-state');
    if (stateBadge) { stateBadge.textContent = !precise ? 'Akurasi rendah' : inside ? 'Dalam area' : 'Di luar area'; stateBadge.dataset.quality = precise && inside ? 'precise' : 'coarse'; }
    if ($('#location-distance')) $('#location-distance').textContent = Math.ceil(distance)+' m';
    if ($('#location-accuracy')) $('#location-accuracy').textContent = 'Akurasi GPS ±'+Math.ceil(point.accuracy)+' m';
    attendanceMap?.update(point); updateAttendanceGate();
    $('#location-reading').hidden = false;
    $('#location-coordinates').textContent = `Koordinat perangkat: ${point.latitude.toFixed(6)}, ${point.longitude.toFixed(6)} · diambil ${timeWib(point.captured_at)} WIB`;
    $('#device-location-link').href = `https://www.openstreetmap.org/?mlat=${point.latitude}&mlon=${point.longitude}#map=18/${point.latitude}/${point.longitude}`;
}
async function locationPoint() {
    if (!window.isSecureContext) throw new Error('Akses lokasi memerlukan HTTPS atau alamat localhost.');
    if (!navigator.geolocation) throw new Error('Peramban ini belum mendukung akses lokasi.');
    locationController?.abort();
    delete state.locationPoint; attendanceMap?.clearDevice(); updateAttendanceGate();
    const pendingBadge = $('#area-state'); if (pendingBadge) { pendingBadge.textContent = 'Mencari lokasi…'; pendingBadge.dataset.quality = 'searching'; }
    if ($('#location-distance')) $('#location-distance').textContent = '—';
    if ($('#location-accuracy')) $('#location-accuracy').textContent = 'Menunggu posisi perangkat';
    const controller = new AbortController();
    locationController = controller;
    const result = $('#location-result');
    const cancel = $('[data-location-cancel]');
    if (result) { result.textContent = 'Mencari lokasi perangkat yang lebih presisi, maksimal 30 detik…'; result.dataset.quality = 'searching'; }
    if (cancel) cancel.hidden = false;
    notify('');
    try {
        const point = await collectLocation(navigator.geolocation, { signal: controller.signal, onProgress: point => { if (locationController === controller && result?.isConnected) showLocation(point, point.accuracy > OFFICE_LOCATION.maxAccuracy); } });
        if (locationController === controller && result?.isConnected) showLocation(point);
        return point;
    } catch (error) {
        if (result?.isConnected && locationController === controller) { result.textContent = error.message; result.dataset.quality = 'coarse'; const area = $('#area-state'); if (area) { area.textContent = 'Lokasi belum tersedia'; area.dataset.quality = 'coarse'; } }
        throw error;
    } finally {
        if (cancel?.isConnected) cancel.hidden = true;
        if (locationController === controller) { locationController = null; updateAttendanceGate(); }
    }
}
async function punch(kind) {
    const point = await locationPoint();
    validateAttendancePoint(point);
    await api('POST', `attendance/${kind}`, { body: point });
    notify(`Presensi ${kind === 'check-in' ? 'masuk' : 'pulang'} berhasil dicatat.`);
    await renderTab();
}
async function upload(file) {
    if (!file || file.size === 0) return null;
    if (file.size > 5 * 1024 * 1024) throw new Error('Ukuran bukti maksimal 5 MiB.');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('Bukti harus berupa JPEG, PNG, atau WebP.');
    const result = await api('POST', 'files', { bytes: file, mime: file.type });
    return result.file.id;
}
async function downloadReport() {
    const period = filterFor('report').period;
    const [year, month] = period.split('-');
    const blob = await api('GET', 'admin/rekap.xlsx', { query: { month: Number(month), year: Number(year) }, binary: true });
    const url = URL.createObjectURL(blob); const link = document.createElement('a');
    link.href = url; link.download = `rekap-presensi-${period}.xlsx`; document.body.append(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
}
async function run(element, callback) {
    if (state.busy) return;
    state.busy = true;
    const buttons = element.matches('button') ? [element] : [...element.querySelectorAll('button')];
    const original = buttons.map(button => button.disabled); buttons.forEach(button => button.disabled = true);
    const localError = element.querySelector?.('[data-modal-error]'); if (localError) localError.hidden = true;
    try { await callback(); }
    catch (error) { if (localError?.isConnected) { localError.textContent = error.message; localError.hidden = false; } else notify(error.message, true); }
    finally { state.busy = false; buttons.forEach((button, index) => button.disabled = original[index]); updateAttendanceGate(); }
}

document.addEventListener('click', event => {
    const popup = $('#notification-popover');
    if (popup && !popup.hidden && !popup.contains(event.target) && !event.target.closest('#header-notification')) closeNotifications();
    const menu = $('#account-menu');
    if (menu.open && !menu.contains(event.target)) menu.open = false;
    const button = event.target.closest('button'); if (!button) return;
    if (button.dataset.togglePassword) {
        const input = document.getElementById(button.dataset.togglePassword);
        const show = input.type === 'password';
        input.type = show ? 'text' : 'password'; button.setAttribute('aria-pressed', String(show));
        button.setAttribute('aria-label', show ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'); return;
    }
    if (button.hasAttribute('data-google-retry')) { if (!state.busy) initGoogle(); return; }
    if (button.dataset.auth) { if (!state.busy) setAuthMode(button.dataset.auth); return; }
    if (button.id === 'close-modal') { if (!state.busy) closeModal(); return; }
    if (button.hasAttribute('data-location-cancel')) { locationController?.abort(); return; }
    if (state.busy) return;
    if (button.id === 'header-notification' && state.user?.role === 'admin') { toggleNotifications(); return; }
    if (button.hasAttribute('data-close-notifications')) { closeNotifications(); return; }
    if (button.dataset.openRequest) { run(button, () => openRequestNotification(button)); return; }
    if (button.hasAttribute('data-request-back')) { state.selectedRequest = null; renderTab(); return; }
    if (button.dataset.inlineProof) { run(button, () => inlineProof(button)); return; }
    if (button.dataset.tab) { closeNotifications(); state.selectedRequest = null; state.tab = button.dataset.tab; notify(''); renderTab(); return; }
    if (button.dataset.page) { state.pages[button.dataset.page] = Math.max(0, (state.pages[button.dataset.page] ?? 0) + Number(button.dataset.direction)); renderTab(); return; }
    if (button.id === 'refresh') { run(button, () => renderTab()); return; }
    if (button.id === 'logout' || button.id === 'profile-logout') {
        run(button, async () => { await api('POST', 'auth/logout'); showAuth(); notify('Anda telah keluar dari presensi.'); }); return;
    }
    if (button.hasAttribute('data-theme-toggle')) { setWebTheme(document.body.dataset.theme === 'dark' ? 'light' : 'dark'); return; }
    if (button.hasAttribute('data-profile-editor')) { openModal('Edit Profil', participantProfileForm(state.user)); return; }
    if (button.hasAttribute('data-password-editor')) { openModal(state.user.has_password === false ? 'Buat kata sandi' : 'Ganti kata sandi', participantPasswordForm(state.user)); return; }
    if (button.dataset.mapCenter) { if (button.dataset.mapCenter === 'device') attendanceMap?.centerDevice(); else attendanceMap?.centerOffice(); return; }
    if (button.hasAttribute('data-history-ledger')) { openModal('Catatan presensi bulanan', table(['Tanggal', 'Masuk', 'Pulang', 'Status'], (state.historyRecords ?? []).map(r => [e(dateLabel(r.tanggal)), e(timeWib(r.jam_masuk)), e(timeWib(r.jam_pulang)), badge(r.status)]))); return; }
    if (button.dataset.historyMonth) {
        const f = filterFor('history', { period: todayWib().slice(0, 7) });
        f.period = moveMonth(f.period, Number(button.dataset.historyMonth)); f.selected = null;
        renderTab(); return;
    }
    if (button.dataset.historyDay) {
        const day = state.historyCalendar?.days.find(d => d.date === button.dataset.historyDay);
        if (!day) return;
        state.filters.history.selected = day.date;
        document.querySelectorAll('[data-history-day]').forEach(item => { const selected = item.dataset.historyDay === day.date; item.classList.toggle('is-selected', selected); item.setAttribute('aria-pressed', String(selected)); });
        openModal('Detail presensi', historyDayDetail(day)); return;
    }
    if (button.dataset.requestView) {
        state.filters.requests = { view: button.dataset.requestView, kind: button.dataset.requestView === 'history' ? '' : 'izin', status: button.dataset.requestView === 'history' ? '' : state.user.role === 'admin' ? 'menunggu' : '' };
        state.pages.requests = 0; state.selectedRequest = null; renderTab(); return;
    }
    if (button.dataset.newRequest) { run(button, () => newRequest(button.dataset.newRequest)); return; }
    if (button.dataset.decision) { decisionModal(button); return; }
    if (button.dataset.evidence) { run(button, () => evidence(button.dataset.evidence)); return; }
    if (button.dataset.punch) { run(button, () => punch(button.dataset.punch)); return; }
    if (button.hasAttribute('data-locate')) {
        run(button, () => locationPoint()); return;
    }
    if (button.dataset.read) { run(button, async () => { await api('PATCH', 'notifications/read', { body: { ids: [button.dataset.read] } }); await renderTab(); await pollNotifications(); }); return; }
    if (button.hasAttribute('data-download-report')) { run(button, downloadReport); return; }
    if (button.hasAttribute('data-new-holiday')) {
        openModal('Tambah hari libur', '<form data-action="holiday"><label>Tanggal<input type="date" name="tanggal" required></label><label>Keterangan<input name="keterangan" maxlength="200" required></label><p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button primary wide">Simpan hari libur</button></form>'); return;
    }
    if (button.dataset.deleteHoliday) openModal('Hapus hari libur', `<p>Hapus hari libur <strong>${e(button.dataset.name)}</strong>? Perubahan berlaku pada presensi web dan Android.</p><form data-action="delete-holiday" data-id="${e(button.dataset.deleteHoliday)}"><p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button danger wide">Ya, hapus hari libur</button></form>`);
});

document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closeNotifications();
    if (event.key === 'Escape' && $('#account-menu').open) {
        $('#account-menu').open = false;
        $('#account-menu summary').focus();
    }
});

document.addEventListener('submit', event => {
    const form = event.target;
    event.preventDefault();
    if (form.id === 'auth-form') {
        run(form, async () => {
            $('#auth-error').hidden = true; notify('');
            const fields = Object.fromEntries(new FormData(form));
            try {
                await googleChallengePending;
                if (state.authMode === 'register') {
                    if (fields.password !== fields.confirmation) throw new Error('Konfirmasi kata sandi tidak cocok.');
                    await api('POST', 'auth/register', { body: { nama_lengkap: fields.nama_lengkap.trim(), email: fields.email.trim(), password: fields.password } });
                    setAuthMode('login'); form.reset(); notify('Pendaftaran berhasil. Silakan masuk dengan akun baru Anda.');
                } else {
                    const data = await api('POST', 'auth/login', { body: { email: fields.email.trim(), password: fields.password } });
                    form.reset(); await showWorkspace(data.user);
                }
            } catch (error) { $('#auth-error').textContent = error.message; $('#auth-error').hidden = false; }
        }); return;
    }
    if (form.dataset.filter) {
        if (!form.checkValidity()) return;
        if (state.busy) return;
        const values = Object.fromEntries(new FormData(form));
        if (values.from && values.to && values.from > values.to) { notify('Tanggal akhir tidak boleh sebelum tanggal awal.', true); return; }
        state.filters[form.dataset.filter] = values; state.pages[form.dataset.filter] = 0; notify(''); renderTab({ silent: true }); return;
    }
    if (!form.dataset.action) return;
    run(form, async () => {
        const values = Object.fromEntries(new FormData(form));
        switch (form.dataset.action) {
            case 'google-link':
                if (!pendingGoogleCredential) throw new Error('Sesi Google sudah berakhir. Coba masuk dengan Google lagi.');
                await finishGoogle(pendingGoogleCredential, values.existing_password); return;
            case 'profile': {
                const data = await api('PATCH', 'me', { body: values }); state.user = data.user;
                $('#greeting').textContent = `Halo, ${data.user.nama_lengkap}`; $('#account-name').textContent = data.user.nama_lengkap; closeModal(); notify('Profil berhasil diperbarui.'); await renderTab(); return;
            }
            case 'password':
                if (values.new_password !== values.confirmation) throw new Error('Konfirmasi kata sandi baru tidak cocok.');
                await api('POST', 'auth/password', { body: { current_password: values.current_password, new_password: values.new_password } });
                showAuth(); notify('Kata sandi berhasil diubah. Masuk kembali dengan kata sandi baru.'); return;
            case 'request': {
                const file = values.evidence; delete values.evidence;
                // Reuse the uploaded ID on a failed submission rather than uploading duplicates.
                if (file?.size && form.dataset.proofSignature !== `${file.name}/${file.size}/${file.lastModified}`) {
                    form.dataset.proof = await upload(file); form.dataset.proofSignature = `${file.name}/${file.size}/${file.lastModified}`;
                }
                if (file?.size && form.dataset.proof) values.bukti_id = form.dataset.proof;
                if (values.jam_pulang_diajukan === '') delete values.jam_pulang_diajukan;
                await api('POST', `requests/${form.dataset.kind}`, { body: values });
                closeModal(); notify('Pengajuan berhasil dikirim. Anda dapat memantau keputusan pada halaman Pengajuan.'); await renderTab(); return;
            }
            case 'decision':
                await api('POST', `admin/requests/${form.dataset.kind}/${form.dataset.id}/decision`, { body: { setujui: form.dataset.approve === 'true', ...values } });
                closeModal(); notify('Keputusan berhasil disimpan dan diteruskan ke akun peserta.'); await renderTab(); return;
            case 'holiday':
                await api('POST', 'admin/holidays', { body: values }); closeModal(); notify('Hari libur berhasil ditambahkan.'); await renderTab(); return;
            case 'delete-holiday':
                await api('DELETE', `admin/holidays/${form.dataset.id}`); closeModal(); notify('Hari libur berhasil dihapus.'); await renderTab(); return;
        }
    });
});
$('#modal').addEventListener('cancel', event => { if (state.busy) event.preventDefault(); else closeModal(); });
async function checkService() {
    try { await api('GET', 'ready'); $('#service-status').textContent = '● Layanan presensi tersedia'; $('#service-status').classList.remove('offline'); }
    catch { $('#service-status').textContent = 'Layanan presensi belum terhubung. Silakan coba lagi nanti.'; $('#service-status').classList.add('offline'); }
}
const seenNotifications = new Set();
const proofUrls = new Set();
let notificationLoading = false;
let filterTimer;
function closeNotifications() {
    const panel = $('#notification-popover');
    if (panel) panel.hidden = true;
    $('#header-notification').setAttribute('aria-expanded', 'false');
}
function notificationCard(n) {
    const target = kinds[n.jenis] && n.request_id;
    return `<article class="notification ${n.read_at ? '' : 'unread'}"><div><h3>${e(n.title)}</h3><p>${e(datetimeLabel(n.created_at))}</p>${target ? `<button class="text-link" data-open-request="${e(n.request_id)}" data-kind="${e(n.jenis)}" data-notice-id="${e(n.id)}">${e(kinds[n.jenis])} · Lihat pengajuan →</button>` : ''}</div>${n.read_at ? badge('dibaca', 'Dibaca') : `<button class="button subtle" data-read="${e(n.id)}">Tandai dibaca</button>`}</article>`;
}
async function pollNotifications(forceOpen = false) {
    if (!state.user || notificationLoading) return;
    notificationLoading = true;
    const session = state.session;
    try {
        const data = await api('GET', 'notifications', { query: { limit: 10 } });
        if (session !== state.session || !state.user) return;
        setNotificationCount(data.unread_count);
        $('#notification-items').innerHTML = data.notifications.map(notificationCard).join('') || empty('Belum ada notifikasi.');
        const fresh = data.notifications.some(n => !n.read_at && !seenNotifications.has(String(n.id)));
        data.notifications.forEach(n => seenNotifications.add(String(n.id)));
        if (forceOpen || (fresh && state.user.role === 'admin' && !$('#modal').open)) {
            $('#notification-popover').hidden = false;
            $('#header-notification').setAttribute('aria-expanded', 'true');
        }
    } finally { notificationLoading = false; }
}
function toggleNotifications() {
    if (!$('#notification-popover').hidden) { closeNotifications(); return; }
    pollNotifications(true).catch(error => notify(error.message, true));
}
async function openRequestNotification(button) {
    if (!kinds[button.dataset.kind]) return;
    closeNotifications();
    state.selectedRequest = { id: button.dataset.openRequest, kind: button.dataset.kind };
    state.tab = 'requests';
    await renderTab();
    if (button.dataset.noticeId) {
        await api('PATCH', 'notifications/read', { body: { ids: [button.dataset.noticeId] } });
        await pollNotifications();
    }
}
async function requestDetail() {
    const { id, kind } = state.selectedRequest;
    const admin = state.user.role === 'admin';
    let row;
    for (let offset = 0; ; offset += 100) {
        const data = await api('GET', `${admin ? 'admin/' : ''}requests/${kind}`, { query: { limit: 100, offset } });
        row = data.requests.find(r => String(r.id) === String(id));
        if (row || data.requests.length < 100) break;
    }
    return `<section class="card"><button class="text-link" data-request-back>← Semua pengajuan</button><h2 style="margin-top:20px">Detail ${e(kinds[kind].toLowerCase())}</h2>${row ? requestCard(row, kind, admin) : empty('Pengajuan tidak ditemukan atau sudah tidak tersedia.')}</section>`;
}
function clearProofs() { proofUrls.forEach(url => URL.revokeObjectURL(url)); proofUrls.clear(); }
async function inlineProof(button) {
    const container = button.parentElement.querySelector('.inline-proof');
    if (!container.hidden) { container.hidden = true; button.setAttribute('aria-expanded', 'false'); button.textContent = 'Tampilkan bukti'; return; }
    if (!container.childElementCount) {
        const blob = await api('GET', `files/${button.dataset.inlineProof}`, { binary: true });
        if (!button.isConnected) return;
        const url = URL.createObjectURL(blob); proofUrls.add(url);
        container.innerHTML = `<img src="${url}" alt="Bukti pendukung pengajuan"><a class="text-link" href="${url}" download="bukti-presensi">Unduh bukti ↓</a>`;
    }
    container.hidden = false; button.setAttribute('aria-expanded', 'true'); button.textContent = 'Sembunyikan bukti';
}
function applyFilter(form) {
    if (!form?.isConnected || !form.checkValidity() || state.busy) return;
    form.requestSubmit();
}
document.addEventListener('change', event => {
    const form = event.target.closest('form[data-filter]');
    if (form) { clearTimeout(filterTimer); applyFilter(form); }
});
document.addEventListener('input', event => {
    const form = event.target.closest('form[data-filter]');
    if (!form || !['text', 'search'].includes(event.target.type)) return;
    clearTimeout(filterTimer);
    filterTimer = setTimeout(() => applyFilter(form), 450);
});

function setWebTheme(theme) {
    document.body.dataset.theme = theme === 'dark' ? 'dark' : 'light';
    try { localStorage.setItem('presensi-web-theme', document.body.dataset.theme); } catch {}
    const dark = document.body.dataset.theme === 'dark';
    document.querySelectorAll('[data-theme-toggle]').forEach(button => button.setAttribute('aria-checked', String(dark)));
    document.querySelectorAll('[data-theme-label]').forEach(label => label.textContent = dark ? 'Aktif' : 'Nonaktif');
}
try { document.body.dataset.theme = localStorage.getItem('presensi-web-theme') === 'dark' ? 'dark' : 'light'; } catch { document.body.dataset.theme = 'light'; }
let attendanceMap;
let mapEpoch = 0;
function destroyAttendanceView() {
    mapEpoch++;
    locationController?.abort(); locationController = null;
    attendanceMap?.destroy(); attendanceMap = null;
}
function updateAttendanceGate() {
    const button = $('#send-attendance');
    if (!button) return;
    const today = state.today;
    const { kind, valid, ready } = attendanceEligibility(today, state.locationPoint);
    button.disabled = state.busy || !ready;
    button.dataset.punch = kind || 'check-in';
    const label = button.querySelector('span');
    if (label) label.textContent = kind ? `Kirim Presensi ${kind === 'check-in' ? 'Masuk' : 'Pulang'}` : 'Presensi tidak tersedia';
    const reason = $('#attendance-block-reason');
    if (reason) reason.textContent = today?.block_reason || (!kind ? 'Presensi hari ini sudah lengkap atau belum tersedia.' : valid ? 'Lokasi memenuhi syarat. Tekan tombol untuk mengirim presensi.' : 'Lokasi belum memenuhi syarat atau sudah kedaluwarsa. Tekan Perbarui.');
}
async function initializeAttendanceView() {
    const element = $('#attendance-live-map'); if (!element) return;
    const epoch = ++mapEpoch;
    mountAttendanceMap(element).then(map => {
        if (epoch !== mapEpoch || !element.isConnected) { map?.destroy(); return; }
        attendanceMap = map;
        if (state.locationPoint) map?.update(state.locationPoint);
    }).catch(() => { if (element.isConnected) { element.innerHTML = '<p class="map-unavailable">Peta belum dapat dimuat. Lokasi tetap diperiksa melalui GPS browser.</p>'; const note = $('#map-service-note'); if (note) note.hidden = false; } });
    try { await locationPoint(); } catch (error) { if (epoch === mapEpoch && element.isConnected) { const area = $('#area-state'); if (area) { area.textContent = 'Lokasi belum tersedia'; area.dataset.quality = 'coarse'; } notify(error.message, true); } }
    if (epoch === mapEpoch) updateAttendanceGate();
}
setInterval(() => {
    updateAttendanceGate();
    if (state.user && state.tab === 'attendance' && !document.hidden && !state.busy && !locationController && state.locationPoint
        && Date.now() - Date.parse(state.locationPoint.captured_at) > 10000) locationPoint().catch(() => {});
}, 1000);

async function init() {
    try { const { user } = await api('GET', 'me'); await showWorkspace(user); }
    catch (error) { showAuth(document.body.dataset.authMode === 'register' ? 'register' : 'login'); if (error.status !== 401) notify(error.message, true); }
    checkService();
}
setInterval(() => {
    if (document.hidden || state.busy || $('#modal').open || ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName)) return;
    if (state.user?.role === 'admin') pollNotifications().catch(() => {});
    if (state.user && ['home', 'notifications'].includes(state.tab)) renderTab({ silent: true });
    else if (state.user && state.tab === 'attendance') {
        const session = state.session;
        api('GET', 'attendance/today').then(today => { if (state.user && state.session === session && state.tab === 'attendance') { state.today = today; if ($('#attendance-time-in')) $('#attendance-time-in').textContent = timeWib(today.attendance?.jam_masuk); if ($('#attendance-time-out')) $('#attendance-time-out').textContent = timeWib(today.attendance?.jam_pulang); updateAttendanceGate(); } }).catch(() => {});
    } else if (!state.user) checkService();
}, 30000);
window.addEventListener('online', () => { if (state.user && !state.busy && !$('#modal').open) renderTab({ silent: true }); else if (!state.user) checkService(); });
window.addEventListener('pagehide', () => locationController?.abort());
init();
