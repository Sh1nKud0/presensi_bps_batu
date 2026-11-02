import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { useSharedFiles } from '../scripts/lib/presensi-shared-files.mjs';

async function listen(server) {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    return `http://127.0.0.1:${server.address().port}`;
}
async function close(server) {
    if (server.listening) await new Promise(resolve => server.close(resolve));
}

test('private files retain hosted storage, authentication and bytes across the local API', async t => {
    const calls = [];
    const bytes = Buffer.from([137, 80, 78, 71, 0, 255, 42]);
    const hosted = createServer(async (request, response) => {
        const chunks = [];
        for await (const chunk of request) chunks.push(chunk);
        calls.push({ url: request.url, method: request.method, headers: request.headers, bytes: Buffer.concat(chunks) });
        if (request.url.includes('redirect')) {
            response.writeHead(302, { Location: 'https://example.test/private' }); response.end(); return;
        }
        if (request.headers.authorization !== 'Bearer test-session') {
            response.writeHead(401, { 'Content-Type': 'application/json' }); response.end('{"error":"Sesi berakhir"}'); return;
        }
        response.setHeader('Set-Cookie', 'hosted-only-cookie=not-for-browser');
        if (request.method === 'POST') {
            response.writeHead(201, { 'Content-Type': 'application/json' }); response.end('{"file":{"id":"shared-id"}}');
        } else if (request.url.includes('/11111111-1111-1111-1111-111111111111')) {
            response.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': bytes.length }); response.end(bytes);
        } else {
            response.writeHead(200, { 'Content-Type': 'application/json' }); response.end('{"files":[]}');
        }
    });
    const upstream = await listen(hosted);
    const local = useSharedFiles(createServer((request, response) => { response.end('local-handler'); }), upstream);
    const origin = await listen(local);
    t.after(async () => { await close(local); await close(hosted); });
    const authorization = 'Bearer test-session';
    const uploaded = await fetch(origin + '/api/files', { method: 'POST', headers: {
        authorization, 'Content-Type': 'image/png', Cookie: 'laravel-session=private', 'X-CSRF-TOKEN': 'private-csrf',
    }, body: bytes });
    assert.equal(uploaded.status, 201);
    assert.equal(uploaded.headers.get('set-cookie'), null);
    assert.deepEqual((await uploaded.json()).file, { id: 'shared-id' });
    assert.deepEqual(calls[0].bytes, bytes);
    assert.equal(calls[0].headers.authorization, authorization);
    assert.equal(calls[0].headers.cookie, undefined);
    assert.equal(calls[0].headers['x-csrf-token'], undefined);
    const downloaded = await fetch(origin + '/api/files/11111111-1111-1111-1111-111111111111', { headers: { authorization } });
    assert.equal(downloaded.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await downloaded.arrayBuffer()), bytes);
    assert.equal((await fetch(origin + '/api/files?limit=10&offset=20', { headers: { authorization } })).status, 200);
    assert.equal(calls.at(-1).url, '/api/files?limit=10&offset=20');
    const before = calls.length;
    const denied = await fetch(origin + '/api/files');
    assert.equal(denied.status, 401); assert.equal((await denied.json()).error, 'Sesi berakhir');
    assert.equal(calls.length, before + 1, 'Authentication failures must not be retried.');
    const redirect = await fetch(origin + '/api/files?redirect=1', { headers: { authorization } });
    assert.equal(redirect.status, 502); assert.equal(redirect.headers.get('location'), null);
    assert.equal(await (await fetch(origin + '/api/me')).text(), 'local-handler');
    assert.equal(await (await fetch(origin + '/api/files', { method: 'DELETE' })).text(), 'local-handler');
    await close(hosted);
    assert.equal((await fetch(origin + '/api/files', { headers: { authorization } })).status, 502);
});

test('file upstreams reject credentials, paths and unencrypted external origins', () => {
    for (const origin of ['http://example.test', 'https://user:password@example.test', 'https://example.test/api', 'https://example.test?query=1']) {
        assert.throws(() => useSharedFiles(createServer(), origin));
    }
});
