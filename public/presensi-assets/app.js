import { escapeHtml as e, todayWib, timeWib, dateLabel, datetimeLabel, shiftDay, distanceMeters, dailyStatuses, OFFICE_LOCATION } from './domain.js?v=20261029-gps170-r1';
import { collectLocation, validateAttendancePoint } from './location.js?v=20261029-gps170-r1';

const $ = selector => document.querySelector(selector);
const state = { user: null, tab: 'home', authMode: 'login', csrf: $('meta[name="csrf-token"]').content, filters: {}, pages: {}, epoch: 0, busy: false, session: 0 };
const PAGE_SIZE = 25;
const localTest = document.body.dataset.localTest === 'true';
const kinds = { izin: 'Izin / sakit', susulan: 'Absen susulan', pembatalan: 'Pembatalan pulang' };
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
    state.filters = {}; state.pages = {};
    delete state.locationPoint;
    $('#workspace').hidden = true; $('#auth').hidden = false; $('#loading').hidden = true;
    $('#account-menu').open = false; $('#account-menu').hidden = true; $('#header-label').hidden = false;
    document.body.classList.add('auth-screen');
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
    $('#header-label').hidden = true; $('#account-menu').hidden = false; $('#account-menu').open = false;
    document.body.classList.remove('auth-screen');
    $('#greeting').textContent = `Halo, ${user.nama_lengkap}`;
    $('#role-tag').textContent = user.role;
    $('#account-name').textContent = user.nama_lengkap;
    $('#workspace-subtitle').textContent = user.role === 'admin' ? 'Pantau kehadiran dan kelola pengajuan peserta magang.' : 'Semoga hari magang Anda berjalan menyenangkan.';
    const tabs = user.role === 'admin'
        ? [['home', 'Ringkasan'], ['requests', 'Persetujuan'], ['report', 'Rekap presensi'], ['users', 'Peserta'], ['holidays', 'Hari libur'], ['notifications', 'Notifikasi'], ['profile', 'Profil']]
        : [['home', 'Hari ini'], ['history', 'Riwayat'], ['requests', 'Pengajuan'], ['notifications', 'Notifikasi'], ['files', 'Bukti'], ['holidays', 'Hari libur'], ['profile', 'Profil']];
    $('#tabs').innerHTML = tabs.map(([tab, title]) => `<button type="button" data-tab="${tab}">${title}</button>`).join('');
    return renderTab();
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
function rangeFilter(key, values, extra = '') { return `<form class="filters" data-filter="${key}"><label>Dari tanggal<input type="date" name="from" value="${e(values.from)}" required></label><label>Sampai tanggal<input type="date" name="to" value="${e(values.to)}" required></label>${extra}<button class="button subtle" type="submit">Tampilkan</button></form>`; }
async function renderTab({ silent = false } = {}) {
    if (!state.user) return;
    const epoch = ++state.epoch;
    document.querySelectorAll('[data-tab]').forEach(button => { const active = button.dataset.tab === state.tab; button.classList.toggle('active', active); button.setAttribute('aria-current', active ? 'page' : 'false'); });
    if (!silent) $('#content').innerHTML = spinner;
    try {
        const renderers = { home: state.user.role === 'admin' ? adminHome : participantHome, history: historyPage, requests: requestsPage, report: reportPage, users: usersPage, holidays: holidaysPage, notifications: notificationsPage, files: filesPage, profile: profilePage };
        const html = await renderers[state.tab]();
        if (epoch !== state.epoch || !state.user) return;
        $('#content').innerHTML = html;
        if (state.tab === 'home' && state.locationPoint) showLocation(state.locationPoint);
        synced();
    } catch (error) {
        if (epoch !== state.epoch || !state.user) return;
        if (!silent) $('#content').innerHTML = '<div class="card empty"><strong>Data belum dapat dimuat</strong>Periksa koneksi Anda, kemudian tekan Perbarui.</div>';
        notify(error.message, true);
        $('#sync-status').textContent = 'Pembaruan belum berhasil. Data terbaru akan tampil setelah layanan terhubung.';
    }
}

async function participantHome() {
    const [today, statistics, notifications] = await Promise.all([api('GET', 'attendance/today'), api('GET', 'me/statistics'), api('GET', 'notifications', { query: { limit: 1 } })]);
    state.today = today;
    const row = today.attendance;
    return `<div class="stats">${stat('Total hadir', statistics.hadir ?? 0, 'Selama periode magang')}${stat('Izin disetujui', statistics.izin ?? 0, 'Pengajuan izin / sakit')}${stat('Status hari ini', row?.status ?? (today.hari_libur ? 'Libur' : 'Belum masuk'), dateLabel(today.tanggal))}${stat('Notifikasi baru', notifications.unread_count ?? 0, 'Keputusan & pengajuan')}</div>
    <div class="columns"><section class="card"><div class="section-heading"><div><h2>Presensi hari ini</h2><p class="muted">${e(dateLabel(today.tanggal))} · Waktu server ${e(timeWib(today.waktu_server))} WIB</p></div>${badge(row?.status ?? 'belum')}</div><div class="punches"><div class="punch"><small>JAM MASUK</small><strong>${e(timeWib(row?.jam_masuk))}</strong><span>Batas tepat waktu 07:30 WIB</span></div><div class="punch"><small>JAM PULANG</small><strong>${e(timeWib(row?.jam_pulang))}</strong><span>Waktu kantor 16:00 WIB</span></div></div>
    ${today.block_reason ? `<div class="info-strip">${e(today.block_reason)}</div>` : '<p class="small-note">Aktifkan lokasi perangkat. Lokasi terbaru akan diambil saat Anda menekan tombol presensi.</p>'}
    <div class="actions"><button type="button" class="button primary" data-punch="check-in" ${today.can_check_in ? '' : 'disabled'}>Presensi masuk</button><button type="button" class="button subtle" data-punch="check-out" ${today.can_check_out ? '' : 'disabled'}>Presensi pulang</button></div>
    ${canCancel(row, today.tanggal) ? '<button type="button" class="text-link" data-new-request="pembatalan">Ajukan pembatalan jam pulang</button>' : ''}</section>
    <section class="card"><div class="section-heading"><h2>Lokasi kantor</h2><span class="badge hadir">Radius 100 m</span></div><iframe class="map" title="Titik kantor BPS Kota Batu" loading="lazy" referrerpolicy="no-referrer" src="https://www.openstreetmap.org/export/embed.html?bbox=112.5033%2C-7.8708%2C112.5113%2C-7.8628&layer=mapnik&marker=-7.8668%2C112.5073"></iframe><p class="small-note map-caption">Penanda hijau menunjukkan titik kantor BPS. Posisi perangkat diperiksa melalui tombol di bawah.</p><div class="location-detail"><div><strong>Lokasi perangkat</strong><span id="location-result" role="status" aria-live="polite">Belum diperiksa. Akurasi yang diterima maksimal ${OFFICE_LOCATION.maxAccuracy} meter.</span></div><button type="button" class="button subtle" data-locate>Cek lokasi</button></div><div id="location-reading" class="location-reading" hidden><span id="location-coordinates"></span><a id="device-location-link" target="_blank" rel="noopener noreferrer">Lihat titik perangkat di peta</a></div><button type="button" class="text-link" data-location-cancel hidden>Batalkan pencarian lokasi</button><details class="location-help"><summary>Lokasi laptop kurang presisi?</summary><p>Aktifkan layanan lokasi pada Windows dan izinkan situs ini mengakses lokasi. Nyalakan Wi-Fi dan coba dekat jendela atau area terbuka. Laptop dapat memakai perkiraan jaringan; HP dengan GPS biasanya lebih presisi. Presensi melalui Android tetap terlihat di web.</p></details></section></div>
    <section class="card" style="margin-top:24px"><div class="section-heading"><h2>Perlu mengajukan sesuatu?</h2><span class="muted">Diproses oleh admin</span></div><div class="actions"><button class="button subtle" data-new-request="izin">Izin / sakit</button><button class="button subtle" data-new-request="susulan">Absen susulan</button><button class="button subtle" data-tab="requests">Lihat pengajuan saya →</button></div></section>`;
}
function canCancel(row, day) { return row?.jam_pulang && row.tanggal.slice(0, 10) === day && ['hadir', 'terlambat'].includes(row.status) && timeWib(row.jam_pulang) < '16:00'; }
async function adminHome() {
    const f = filterFor('home', { date: todayWib() });
    const [attendance, participants, leaves, approvedLeaves, supplementary, notifications] = await Promise.all([
        all('admin/attendance', 'attendance', { from: f.date, to: f.date }), all('admin/participants', 'participants'),
        all('admin/requests/izin', 'requests', { status: 'menunggu' }), all('admin/requests/izin', 'requests', { status: 'disetujui' }),
        all('admin/requests/susulan', 'requests', { status: 'menunggu' }), api('GET', 'notifications', { query: { limit: 1 } }),
    ]);
    const rows = dailyStatuses(f.date, participants, attendance, [...leaves, ...approvedLeaves], supplementary);
    return `<div class="stats">${stat('Peserta magang', participants.length, 'Terdaftar di presensi')}${stat('Sudah masuk', rows.filter(r => r.attendance?.jam_masuk).length, dateLabel(f.date))}${stat('Izin / sakit', rows.filter(r => ['izin', 'sakit'].includes(r.status)).length, 'Pengajuan disetujui')}${stat('Notifikasi baru', notifications.unread_count ?? 0, 'Menunggu tindak lanjut')}</div><section class="card"><div class="section-heading"><div><h2>Kehadiran peserta</h2><p class="muted">Presensi dan status pengajuan pada tanggal pilihan.</p></div><button class="button primary" data-tab="requests">Tinjau pengajuan →</button></div><form class="filters" data-filter="home"><label>Tanggal<input type="date" name="date" required value="${e(f.date)}"></label><label>Cari peserta<input name="search" value="${e(f.search ?? '')}" placeholder="Nama peserta"></label><button type="submit" class="button subtle">Tampilkan</button></form>
    ${table(['Peserta', 'Asal instansi', 'Status', 'Masuk WIB', 'Pulang WIB'], rows.filter(r => r.profile.nama_lengkap.toLowerCase().includes((f.search ?? '').toLowerCase())).map(r => [e(r.profile.nama_lengkap), e(r.profile.asal_instansi ?? '—'), badge(r.status, r.label), e(timeWib(r.attendance?.jam_masuk)), e(timeWib(r.attendance?.jam_pulang))]))}</section>`;
}
async function historyPage() {
    const f = filterFor('history', { from: shiftDay(todayWib(), -30), to: todayWib() });
    const data = await api('GET', 'attendance/history', { query: { ...f, limit: PAGE_SIZE, offset: offset('history') } });
    return `<section class="card"><div class="section-heading"><h2>Riwayat presensi</h2><span class="muted">Seluruh waktu dalam WIB</span></div>${rangeFilter('history', f)}${table(['Tanggal', 'Masuk', 'Pulang', 'Status', 'Jarak kantor'], data.attendance.map(r => [e(dateLabel(r.tanggal)), e(timeWib(r.jam_masuk)), e(timeWib(r.jam_pulang)), badge(r.status), r.jarak_dari_kantor_meter == null ? '—' : `${e(Math.round(r.jarak_dari_kantor_meter))} m`]))}${pager('history', data.attendance.length)}</section>`;
}
async function requestsPage() {
    const admin = state.user.role === 'admin';
    const f = filterFor('requests', { kind: 'izin', status: admin ? 'menunggu' : '' });
    const data = await api('GET', `${admin ? 'admin/' : ''}requests/${f.kind}`, { query: { status: f.status, limit: PAGE_SIZE, offset: offset('requests') } });
    return `<section class="card"><div class="section-heading"><div><h2>${admin ? 'Persetujuan pengajuan' : 'Pengajuan saya'}</h2><p class="muted">${admin ? 'Periksa detail dan bukti sebelum memberikan keputusan.' : 'Pantau status izin, susulan, dan pembatalan jam pulang.'}</p></div>${admin ? '' : '<button class="button primary" data-new-request="izin">+ Buat pengajuan</button>'}</div>
    <form class="filters" data-filter="requests"><label>Jenis pengajuan<select name="kind">${Object.entries(kinds).map(([key, label]) => `<option value="${key}" ${f.kind === key ? 'selected' : ''}>${label}</option>`).join('')}</select></label><label>Status<select name="status">${[...(!admin ? [['', 'Semua status']] : []), ['menunggu', 'Menunggu'], ['disetujui', 'Disetujui'], ['ditolak', 'Ditolak']].map(([key, label]) => `<option value="${key}" ${f.status === key ? 'selected' : ''}>${label}</option>`).join('')}</select></label><button type="submit" class="button subtle">Tampilkan</button></form>
    ${!admin ? '<div class="actions" style="margin-bottom:22px"><button class="button subtle" data-new-request="izin">Izin / sakit</button><button class="button subtle" data-new-request="susulan">Absen susulan</button><button class="button subtle" data-new-request="pembatalan">Pembatalan pulang</button></div>' : ''}
    <div class="list">${data.requests.length ? data.requests.map(row => requestCard(row, f.kind, admin)).join('') : empty('Tidak ada pengajuan dengan filter ini.')}</div>${pager('requests', data.requests.length)}</section>`;
}
function requestCard(row, kind, admin) {
    const label = kind === 'izin' ? (row.jenis === 'sakit' ? 'Sakit' : 'Izin') : kinds[kind];
    const period = kind === 'izin' ? `${dateLabel(row.tanggal_mulai)} – ${dateLabel(row.tanggal_selesai)}` : dateLabel(row.tanggal);
    return `<article class="request-card"><div class="request-top"><div><h3>${e(admin ? row.nama_lengkap : label)}</h3><small>${e(admin ? `${label} · ${period}` : period)}</small></div>${badge(row.status_persetujuan)}</div>
    ${kind === 'susulan' ? `<div class="request-meta"><span>Masuk: ${e(row.jam_masuk_diajukan ?? '—')} WIB</span><span>Pulang: ${e(row.jam_pulang_diajukan ?? '—')} WIB</span><span>${e(row.jenis_alasan)}</span></div>` : ''}
    ${kind === 'pembatalan' ? `<div class="request-meta"><span>Jam pulang: ${e(timeWib(row.jam_pulang_awal))} WIB</span></div>` : ''}
    <p>${e(row.keterangan ?? row.alasan ?? '')}</p><div class="request-meta"><span>Diajukan ${e(datetimeLabel(row.created_at))}</span>${row.diproses_at ? `<span>Diproses ${e(datetimeLabel(row.diproses_at))}</span>` : ''}</div>
    ${row.alasan_penolakan ? `<div class="info-strip">Alasan penolakan: ${e(row.alasan_penolakan)}</div>` : ''}
    ${proofLink(row)}${admin && row.status_persetujuan === 'menunggu' ? `<div class="actions" style="margin-top:14px"><button class="button success" data-decision="true" data-kind="${kind}" data-id="${e(row.id)}" data-name="${e(row.nama_lengkap)}">Setujui</button><button class="button danger" data-decision="false" data-kind="${kind}" data-id="${e(row.id)}" data-name="${e(row.nama_lengkap)}">Tolak</button></div>` : ''}</article>`;
}
function proofLink(row) {
    if (row.bukti_id) return `<button class="text-link" data-evidence="${e(row.bukti_id)}">Lihat bukti lampiran ↗</button>`;
    if (typeof row.bukti_url === 'string' && /^https:\/\//i.test(row.bukti_url)) return `<a class="text-link" href="${e(row.bukti_url)}" target="_blank" rel="noopener noreferrer">Lihat bukti lampiran ↗</a>`;
    return '';
}
async function notificationsPage() {
    const f = filterFor('notifications', { date: '', unread: '' });
    const data = await api('GET', 'notifications', { query: { ...f, limit: PAGE_SIZE, offset: offset('notifications') } });
    return `<section class="card"><div class="section-heading"><h2>Notifikasi</h2><span class="badge hadir">${e(data.unread_count)} belum dibaca</span></div><form class="filters" data-filter="notifications"><label>Tanggal (opsional)<input type="date" name="date" value="${e(f.date)}"></label><label>Tampilkan<select name="unread"><option value="">Semua</option><option value="true" ${f.unread === 'true' ? 'selected' : ''}>Belum dibaca</option></select></label><button type="submit" class="button subtle">Tampilkan</button></form><div class="list">${data.notifications.length ? data.notifications.map(n => `<article class="notification ${n.read_at ? '' : 'unread'}"><div><h3>${e(n.title)}</h3><p>${e(datetimeLabel(n.created_at))}</p></div>${n.read_at ? badge('dibaca', 'Dibaca') : `<button class="button subtle" data-read="${e(n.id)}">Tandai dibaca</button>`}</article>`).join('') : empty('Belum ada notifikasi dengan filter ini.')}</div>${pager('notifications', data.notifications.length)}</section>`;
}
async function filesPage() {
    const data = await api('GET', 'files', { query: { limit: PAGE_SIZE, offset: offset('files') } });
    return `<section class="card"><div class="section-heading"><div><h2>Bukti saya</h2><p class="muted">Lampiran privat yang tersimpan pada akun presensi.</p></div></div><p class="small-note">Terpakai ${(data.used_bytes / 1048576).toFixed(2)} MiB dari ${(data.quota_bytes / 1048576).toFixed(0)} MiB. Setiap gambar maksimal 5 MiB.</p><div class="quota"><span style="width:${Math.min(100, Math.max(0, data.used_bytes / data.quota_bytes * 100))}%"></span></div><div class="list">${data.files.length ? data.files.map(file => `<div class="file-entry"><div><strong>${e(file.mime_type)}</strong><small>${e(datetimeLabel(file.created_at))} · ${(file.size_bytes / 1024).toFixed(0)} KiB</small></div><button class="button subtle" data-evidence="${e(file.id)}">Lihat / unduh</button></div>`).join('') : empty('Lampirkan bukti saat membuat pengajuan izin atau susulan.')}</div>${pager('files', data.files.length)}</section>`;
}
async function holidaysPage() {
    const day = todayWib();
    const f = filterFor('holidays', { from: `${day.slice(0, 4)}-01-01`, to: `${day.slice(0, 4)}-12-31` });
    const data = await api('GET', 'holidays', { query: { ...f, limit: PAGE_SIZE, offset: offset('holidays') } });
    const admin = state.user.role === 'admin';
    return `<section class="card"><div class="section-heading"><h2>Kalender hari libur</h2>${admin ? '<button class="button primary" data-new-holiday>+ Tambah hari libur</button>' : ''}</div>${rangeFilter('holidays', f)}${table(['Tanggal', 'Keterangan', ...(admin ? ['Tindakan'] : [])], data.holidays.map(h => [e(dateLabel(h.tanggal)), e(h.keterangan), ...(admin ? [`<button class="button danger" data-delete-holiday="${e(h.id)}" data-name="${e(h.keterangan)}">Hapus</button>`] : [])]))}${pager('holidays', data.holidays.length)}<p class="small-note" style="margin-top:20px">Akhir pekan dan hari libur mengikuti aturan presensi pada aplikasi Android.</p></section>`;
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
    return `<section class="card"><div class="section-heading"><div><h2>Rekap presensi bulanan</h2><p class="muted">Dibuat ${e(datetimeLabel(report.generated_at))}</p></div><button class="button primary" data-download-report>Unduh Excel ↓</button></div><form class="filters" data-filter="report"><label>Periode<input type="month" name="period" min="2000-01" max="2100-12" value="${e(f.period)}" required></label><button class="button subtle" type="submit">Tampilkan</button></form>
    ${table(['Nama peserta', 'Instansi', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Dispensasi', 'Alpha', 'Tanpa catatan', 'Tidak lengkap', 'Total tercatat'], report.participants.map(p => [e(p.profile.nama_lengkap), e(p.profile.asal_instansi ?? '—'), e(p.counts.hadir), e(p.counts.terlambat), e(p.counts.izin), e(p.counts.sakit), e(p.counts.dispensasi), e(p.counts.alpha), e(p.counts.tanpa_catatan), e(p.counts.tidak_lengkap), `<strong>${e(p.counts.total)}</strong>`]))}
    <p class="small-note" style="margin-top:20px">Total hadir sudah mencakup keterlambatan. Akhir pekan, hari libur, dan tanggal mendatang tidak dihitung. Tanggal tanpa catatan tidak otomatis dianggap alpha.</p>
    <div class="report-details">${report.participants.map(p => `<details><summary>${e(p.profile.nama_lengkap)} · Detail harian</summary>${table(['Tanggal', 'Status', 'Masuk WIB', 'Pulang WIB', 'Dihitung', 'Catatan'], p.days.map(d => [e(dateLabel(d.tanggal)), e(d.status), e(d.jam_masuk), e(d.jam_pulang), d.dihitung ? 'Ya' : 'Tidak', e(d.catatan)]))}</details>`).join('')}</div></section>`;
}
async function profilePage() {
    const { user } = await api('GET', 'me'); state.user = user;
    return `<div class="columns equal"><section class="card"><h2>Profil saya</h2><p class="muted">Perubahan profil juga akan terlihat di Android.</p><form data-action="profile"><label>Nama lengkap<input name="nama_lengkap" maxlength="150" value="${e(user.nama_lengkap)}" required></label><label>Email<input value="${e(user.email)}" type="email" disabled></label><label>NIM<input name="nim" maxlength="200" value="${e(user.nim)}"></label><label>Asal instansi<input name="asal_instansi" maxlength="200" value="${e(user.asal_instansi)}"></label><label>Nomor HP<input name="no_hp" type="tel" maxlength="200" value="${e(user.no_hp)}"></label><button class="button primary" type="submit">Simpan profil</button></form></section><section class="card"><h2>${user.has_password === false ? 'Buat kata sandi' : 'Ganti kata sandi'}</h2><p class="muted">${user.has_password === false ? 'Buat kata sandi agar akun Google ini juga dapat digunakan untuk masuk ke aplikasi Android. Untuk keamanan, lakukan setelah baru masuk dengan Google.' : 'Setelah diubah, seluruh sesi web dan Android akan berakhir. Masuk kembali menggunakan kata sandi baru.'}</p><form data-action="password">${user.has_password === false ? '' : '<label>Kata sandi saat ini<input name="current_password" type="password" autocomplete="current-password" required maxlength="256"></label>'}<label>Kata sandi baru<input name="new_password" type="password" autocomplete="new-password" minlength="8" maxlength="256" required></label><label>Ulangi kata sandi baru<input name="confirmation" type="password" autocomplete="new-password" required maxlength="256"></label><button class="button primary" type="submit">${user.has_password === false ? 'Buat kata sandi' : 'Ubah kata sandi'}</button></form></section></div>`;
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
    $('#location-reading').hidden = false;
    $('#location-coordinates').textContent = `Koordinat perangkat: ${point.latitude.toFixed(6)}, ${point.longitude.toFixed(6)} · diambil ${timeWib(point.captured_at)} WIB`;
    $('#device-location-link').href = `https://www.openstreetmap.org/?mlat=${point.latitude}&mlon=${point.longitude}#map=18/${point.latitude}/${point.longitude}`;
}
async function locationPoint() {
    if (!window.isSecureContext) throw new Error('Akses lokasi memerlukan HTTPS atau alamat localhost.');
    if (!navigator.geolocation) throw new Error('Peramban ini belum mendukung akses lokasi.');
    const controller = new AbortController();
    locationController = controller;
    const result = $('#location-result');
    const cancel = $('[data-location-cancel]');
    if (result) { result.textContent = 'Mencari lokasi perangkat yang lebih presisi, maksimal 30 detik…'; result.dataset.quality = 'searching'; }
    if (cancel) cancel.hidden = false;
    notify('');
    try {
        const point = await collectLocation(navigator.geolocation, { signal: controller.signal, onProgress: point => showLocation(point, point.accuracy > OFFICE_LOCATION.maxAccuracy) });
        showLocation(point);
        return point;
    } catch (error) {
        if (result?.isConnected) { result.textContent = error.message; result.dataset.quality = 'coarse'; }
        throw error;
    } finally {
        if (cancel?.isConnected) cancel.hidden = true;
        if (locationController === controller) locationController = null;
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
    finally { state.busy = false; buttons.forEach((button, index) => button.disabled = original[index]); }
}

document.addEventListener('click', event => {
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
    if (button.dataset.tab) { state.tab = button.dataset.tab; notify(''); renderTab(); return; }
    if (button.dataset.page) { state.pages[button.dataset.page] = Math.max(0, (state.pages[button.dataset.page] ?? 0) + Number(button.dataset.direction)); renderTab(); return; }
    if (button.id === 'refresh') { run(button, () => renderTab()); return; }
    if (button.id === 'logout') {
        run(button, async () => { await api('POST', 'auth/logout'); showAuth(); notify('Anda telah keluar dari presensi.'); }); return;
    }
    if (button.dataset.newRequest) { run(button, () => newRequest(button.dataset.newRequest)); return; }
    if (button.dataset.decision) { decisionModal(button); return; }
    if (button.dataset.evidence) { run(button, () => evidence(button.dataset.evidence)); return; }
    if (button.dataset.punch) { run(button, () => punch(button.dataset.punch)); return; }
    if (button.hasAttribute('data-locate')) {
        run(button, () => locationPoint()); return;
    }
    if (button.dataset.read) { run(button, async () => { await api('PATCH', 'notifications/read', { body: { ids: [button.dataset.read] } }); await renderTab(); }); return; }
    if (button.hasAttribute('data-download-report')) { run(button, downloadReport); return; }
    if (button.hasAttribute('data-new-holiday')) {
        openModal('Tambah hari libur', '<form data-action="holiday"><label>Tanggal<input type="date" name="tanggal" required></label><label>Keterangan<input name="keterangan" maxlength="200" required></label><p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button primary wide">Simpan hari libur</button></form>'); return;
    }
    if (button.dataset.deleteHoliday) openModal('Hapus hari libur', `<p>Hapus hari libur <strong>${e(button.dataset.name)}</strong>? Perubahan berlaku pada presensi web dan Android.</p><form data-action="delete-holiday" data-id="${e(button.dataset.deleteHoliday)}"><p class="form-error" data-modal-error role="alert" hidden></p><button type="submit" class="button danger wide">Ya, hapus hari libur</button></form>`);
});

document.addEventListener('keydown', event => {
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
        if (state.busy) return;
        const values = Object.fromEntries(new FormData(form));
        if (values.from && values.to && values.from > values.to) { notify('Tanggal akhir tidak boleh sebelum tanggal awal.', true); return; }
        state.filters[form.dataset.filter] = values; state.pages[form.dataset.filter] = 0; notify(''); renderTab(); return;
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
                $('#greeting').textContent = `Halo, ${data.user.nama_lengkap}`; $('#account-name').textContent = data.user.nama_lengkap; notify('Profil berhasil diperbarui.'); await renderTab(); return;
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
async function init() {
    try { const { user } = await api('GET', 'me'); await showWorkspace(user); }
    catch (error) { showAuth(document.body.dataset.authMode === 'register' ? 'register' : 'login'); if (error.status !== 401) notify(error.message, true); }
    checkService();
}
setInterval(() => {
    if (document.hidden || state.busy || $('#modal').open || ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName)) return;
    if (state.user && ['home', 'notifications'].includes(state.tab)) renderTab({ silent: true });
    else if (!state.user) checkService();
}, 30000);
window.addEventListener('online', () => { if (state.user && !state.busy && !$('#modal').open) renderTab({ silent: true }); else if (!state.user) checkService(); });
window.addEventListener('pagehide', () => locationController?.abort());
init();
