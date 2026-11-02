import { request as httpRequest } from 'node:http';
import { request as httpsRequest } from 'node:https';

// File bytes belong to the hosted backend. Sharing only their PostgreSQL
// metadata would leave Android unable to read uploads saved on this laptop.
export function useSharedFiles(server, upstreamOrigin) {
    const origin = new URL(upstreamOrigin);
    const loopback = ['127.0.0.1', 'localhost', '[::1]'].includes(origin.hostname);
    if (origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash
        || (origin.protocol !== 'https:' && !(origin.protocol === 'http:' && loopback))) {
        throw new Error('Origin berkas harus HTTPS tanpa path; HTTP hanya untuk localhost.');
    }
    const handlers = server.listeners('request');
    server.removeAllListeners('request');
    server.on('request', (request, response) => {
        const path = request.url?.split('?')[0];
        const listOrUpload = path === '/api/files' && ['GET', 'POST'].includes(request.method);
        const download = /^\/api\/files\/[0-9a-f-]{36}$/i.test(path ?? '') && request.method === 'GET';
        if (!listOrUpload && !download) {
            for (const handler of handlers) handler.call(server, request, response);
            return;
        }
        const headers = {};
        for (const name of ['authorization', 'accept', 'content-type', 'content-length']) {
            if (request.headers[name] !== undefined) headers[name] = request.headers[name];
        }
        const fail = () => {
            if (response.destroyed || response.writableEnded) return;
            if (response.headersSent) { response.destroy(); return; }
            response.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
            response.end(JSON.stringify({ error: 'Layanan berkas presensi belum dapat dihubungi. Periksa daftar bukti sebelum mengunggah ulang.' }));
        };
        const upstream = (origin.protocol === 'https:' ? httpsRequest : httpRequest)(new URL(request.url, origin), {
            method: request.method, headers,
        }, incoming => {
            if (incoming.statusCode >= 300 && incoming.statusCode < 400) {
                incoming.resume(); fail(); return;
            }
            const outgoingHeaders = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
            for (const name of ['content-type', 'content-length', 'content-disposition', 'retry-after']) {
                if (incoming.headers[name] !== undefined) outgoingHeaders[name] = incoming.headers[name];
            }
            response.writeHead(incoming.statusCode ?? 502, outgoingHeaders);
            incoming.on('error', fail);
            incoming.pipe(response);
        });
        upstream.setTimeout(40000, () => upstream.destroy(new Error('timeout')));
        upstream.on('error', fail);
        request.on('aborted', () => upstream.destroy());
        request.on('error', () => upstream.destroy());
        response.on('close', () => { if (!response.writableEnded) upstream.destroy(); });
        request.pipe(upstream);
    });
    return server;
}
