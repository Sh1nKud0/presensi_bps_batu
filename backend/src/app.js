import { createServer } from 'node:http';
import { createAuth } from './auth.js';
import { HttpError } from './errors.js';
import { bearerToken, createRateLimiter } from './security.js';
import { createAttendance } from './attendance.js';
import { createCancellation } from './cancellation.js';
import { createNotifications } from './notifications.js';
import { createFiles, MAX_UPLOAD_BYTES } from './files.js';
import { createReports } from './reports.js';
import { createHolidays } from './holidays.js';
import { createMobileQueries } from './mobile.js';

function json(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  if (request.headers['content-type']?.split(';')[0].trim().toLowerCase() !== 'application/json') {
    request.resume();
    throw new HttpError(415, 'Gunakan Content-Type application/json.');
  }
  const buffer = await readBody(request, 16384);
  try {
    const data = JSON.parse(buffer.toString('utf8'));
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error();
    return data;
  } catch { throw new HttpError(400, 'Isi JSON harus berupa objek yang valid.'); }
}

function readBody(request, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let bytes = 0;
    let tooLarge = false;
    request.on('data', chunk => {
      if (tooLarge) return;
      bytes += chunk.length;
      if (bytes > maxBytes) {
        tooLarge = true;
        chunks.length = 0;
        reject(new HttpError(413, 'Isi permintaan terlalu besar.'));
      } else chunks.push(chunk);
    });
    request.on('end', () => {
      if (tooLarge) return;
      resolve(Buffer.concat(chunks));
    });
    request.on('error', () => reject(new HttpError(400, 'Permintaan terputus.')));
    request.on('aborted', () => reject(new HttpError(400, 'Permintaan terputus.')));
  });
}

export function createApp({ database, auth = createAuth(database), attendance = createAttendance(database), uploadDirectory, rateLimit = createRateLimiter() }) {
  const cancellation = createCancellation(database);
  const notifications = createNotifications(database);
  const files = createFiles(database, uploadDirectory);
  const reports = createReports(database);
  const holidays = createHolidays(database);
  const mobile = createMobileQueries(database);
  const routes = {
    '/health': 'GET', '/ready': 'GET',
    '/api/auth/register': 'POST', '/api/auth/login': 'POST',
    '/api/auth/logout': 'POST', '/api/auth/password': 'POST',
    '/api/me': ['GET', 'PATCH'], '/api/admin/users': 'GET',
    '/api/me/statistics': 'GET', '/api/admin/participants': 'GET', '/api/admin/attendance': 'GET',
    '/api/attendance/today': 'GET', '/api/attendance/history': 'GET',
    '/api/attendance/check-in': 'POST', '/api/attendance/check-out': 'POST',
    requestList: ['GET', 'POST'], adminRequestList: 'GET', decision: 'POST',
    '/api/notifications': 'GET', '/api/notifications/read': 'PATCH',
    '/api/files': ['GET', 'POST'], fileDownload: 'GET',
    '/api/admin/rekap': 'GET', '/api/admin/rekap.xlsx': 'GET',
    '/api/holidays': 'GET', '/api/admin/holidays': 'POST', holidayDelete: 'DELETE',
  };
  return createServer({ requestTimeout: 30000, headersTimeout: 10000 }, async (request, response) => {
    const path = request.url?.split('?')[0];
    const decision = /^\/api\/admin\/requests\/(izin|susulan|pembatalan)\/([^/]+)\/decision$/.exec(path);
    const adminRequestList = /^\/api\/admin\/requests\/(izin|susulan|pembatalan)$/.exec(path);
    const requestList = /^\/api\/requests\/(izin|susulan|pembatalan)$/.exec(path);
    const fileDownload = /^\/api\/files\/([^/]+)$/.exec(path);
    const holidayDelete = /^\/api\/admin\/holidays\/([^/]+)$/.exec(path);
    const route = decision ? 'decision' : adminRequestList ? 'adminRequestList' : requestList ? 'requestList'
      : fileDownload ? 'fileDownload' : holidayDelete ? 'holidayDelete' : path;
    if (!Object.hasOwn(routes, route)) {
      json(response, 404, { error: 'Endpoint tidak ditemukan.' });
      return;
    }
    const methods = [routes[route]].flat();
    if (!methods.includes(request.method)) {
      response.setHeader('Allow', methods.join(', '));
      json(response, 405, { error: `Gunakan metode ${methods.join(' atau ')}.` });
      return;
    }
    if (path === '/health') {
      json(response, 200, { status: 'ok', service: 'presensi-bps-backend' });
      return;
    }
    if (path === '/ready') {
      try {
        await database.query('SELECT 1');
        json(response, 200, { status: 'ok', database: 'connected' });
      } catch {
        json(response, 503, {
          status: 'unavailable',
          error: 'Database belum dapat dihubungi. Periksa konfigurasi dan tunnel SSH.',
        });
      }
      return;
    }
    try {
      if (request.method !== 'GET') {
        rateLimit(request.socket.remoteAddress ?? 'unknown');
      }
      if (path === '/api/auth/register' || path === '/api/auth/login') {
        const input = await readJson(request);
        const register = path.endsWith('/register');
        json(response, register ? 201 : 200, await auth[register ? 'register' : 'login'](input));
        return;
      }
      const token = bearerToken(request);
      const user = await auth.authenticate(token);
      if (path.startsWith('/api/admin/') && user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
      if (path === '/api/me/statistics') {
        json(response, 200, await mobile.statistics(user));
      } else if (path === '/api/admin/participants' || path === '/api/admin/attendance') {
        const query = Object.fromEntries(new URL(request.url, 'http://localhost').searchParams);
        json(response, 200, await mobile[path.endsWith('/participants') ? 'participants' : 'attendance'](query));
      } else if (path === '/api/admin/users') {
        if (user.role !== 'admin') throw new HttpError(403, 'Akses hanya untuk admin.');
        json(response, 200, await auth.listUsers());
      } else if (path === '/api/me') {
        json(response, 200, request.method === 'GET' ? { user }
          : await auth.updateProfile(user, await readJson(request)));
      } else if (path === '/api/auth/logout') {
        json(response, 200, await auth.logout(token));
      } else if (path === '/api/auth/password') {
        json(response, 200, await auth.changePassword(user, token, await readJson(request)));
      } else if (path === '/api/attendance/today') {
        json(response, 200, await attendance.today(user));
      } else if (path === '/api/attendance/history') {
        const query = Object.fromEntries(new URL(request.url, 'http://localhost').searchParams);
        json(response, 200, await attendance.history(user, query));
      } else if (path === '/api/attendance/check-in' || path === '/api/attendance/check-out') {
        json(response, 200, await attendance[path.endsWith('/check-in') ? 'checkIn' : 'checkOut'](user, await readJson(request)));
      } else if (requestList || adminRequestList) {
        const kind = (requestList ?? adminRequestList)[1];
        if (request.method === 'POST') {
          json(response, 201, kind === 'pembatalan' ? await cancellation.submit(user, await readJson(request))
            : await attendance.submit(user, kind, await readJson(request)));
        } else {
          const query = Object.fromEntries(new URL(request.url, 'http://localhost').searchParams);
          if (adminRequestList && !query.status) query.status = 'menunggu';
          json(response, 200, kind === 'pembatalan' ? await cancellation.list(user, query, Boolean(adminRequestList))
            : await attendance.requests(user, kind, query, Boolean(adminRequestList)));
        }
      } else if (decision) {
        json(response, 200, decision[1] === 'pembatalan' ? await cancellation.decide(user, decision[2], await readJson(request))
          : await attendance.decide(user, decision[1], decision[2], await readJson(request)));
      } else if (path === '/api/notifications') {
        json(response, 200, await notifications.list(user, Object.fromEntries(new URL(request.url, 'http://localhost').searchParams)));
      } else if (path === '/api/notifications/read') {
        json(response, 200, await notifications.read(user, await readJson(request)));
      } else if (path === '/api/files') {
        if (request.method === 'GET') {
          json(response, 200, await files.list(user, Object.fromEntries(new URL(request.url, 'http://localhost').searchParams)));
        } else {
          const mime = request.headers['content-type']?.split(';')[0].trim().toLowerCase();
          if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) throw new HttpError(415, 'Gunakan Content-Type gambar JPEG, PNG, atau WebP.');
          json(response, 201, await files.upload(user, await readBody(request, MAX_UPLOAD_BYTES), mime));
        }
      } else if (fileDownload) {
        const file = await files.download(user, fileDownload[1]);
        response.writeHead(200, { 'Content-Type': file.mime, 'Content-Length': file.buffer.length,
          'Content-Disposition': `attachment; filename="${file.filename}"`, 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' });
        response.end(file.buffer);
      } else if (path === '/api/admin/rekap' || path === '/api/admin/rekap.xlsx') {
        const query = Object.fromEntries(new URL(request.url, 'http://localhost').searchParams);
        if (path.endsWith('.xlsx')) {
          const file = await reports.xlsx(user, query);
          response.writeHead(200, { 'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Length': file.buffer.length, 'Content-Disposition': `attachment; filename="${file.filename}"`, 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' });
          response.end(file.buffer);
        } else json(response, 200, await reports.load(user, query));
      } else if (path === '/api/holidays') {
        json(response, 200, await holidays.list(Object.fromEntries(new URL(request.url, 'http://localhost').searchParams)));
      } else if (path === '/api/admin/holidays') {
        json(response, 201, await holidays.add(user, await readJson(request)));
      } else if (holidayDelete) {
        json(response, 200, await holidays.remove(user, holidayDelete[1]));
      }
    } catch (error) {
      request.resume();
      if (response.destroyed) return;
      if (error instanceof HttpError) {
        if (error.status === 429) response.setHeader('Retry-After', '60');
        json(response, error.status, { error: error.message });
      } else {
        json(response, 503, { error: 'Layanan belum siap. Periksa koneksi dan jalankan migrasi database.' });
      }
    }
  });
}
