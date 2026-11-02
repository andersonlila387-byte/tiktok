const test = require('node:test');
const assert = require('node:assert');
const http = require('http');

process.env.ADMIN_PIN = '4321';
process.env.TOKEN_SECRET = 'test-secret';
delete process.env.VERCEL;
delete process.env.UPSTASH_REDIS_REST_URL;
delete process.env.KV_REST_API_URL;

const analytics = require('../api/analytics');
const login = require('../api/login');

const zeros = (n) => Array(n).fill(0);
const sample = (male = 56) => ({
  topWords: [],
  followers: Array(31).fill(120),
  metrics: { Likes: zeros(30) },
  male,
  female: 44,
  ages: { '18-24': 50 },
  locations: [{ name: 'US', percent: 50 }],
  hourly: zeros(24),
  weekday: zeros(7),
  viewerHourly: zeros(24),
  viewerWeekday: zeros(7),
  traffic: [],
  queries: [],
  dashMetrics: [],
});

/** Calls a function handler the way Vercel does and returns what it answered. */
async function call(handler, { method = 'GET', body, headers = {}, ip = '1.1.1.1' } = {}) {
  const req = { method, body, headers: { 'x-forwarded-for': ip, ...headers } };
  const out = { headers: {} };
  const res = {
    setHeader: (k, v) => (out.headers[k.toLowerCase()] = v),
    end: (b) => (out.body = b ? JSON.parse(b) : undefined),
    set statusCode(v) { out.status = v; },
  };
  await handler(req, res);
  return out;
}

const signIn = async (pin = '4321', ip) =>
  call(login, { method: 'POST', body: { pin }, ip });
const authed = (token) => ({ authorization: `Bearer ${token}` });

test('nothing saved yet returns 404', async () => {
  assert.strictEqual((await call(analytics)).status, 404);
});

test('PIN check issues a token only for the right PIN', async () => {
  assert.strictEqual((await signIn('0000')).status, 401);
  const ok = await signIn();
  assert.strictEqual(ok.status, 200);
  assert.ok(ok.body.token);
});

test('writes need a token; edits are public and validated', async () => {
  assert.strictEqual((await call(analytics, { method: 'PUT', body: { data: sample() } })).status, 401);
  const { body } = await signIn();
  const h = authed(body.token);

  const saved = await call(analytics, { method: 'PUT', headers: h, body: { data: sample(20) } });
  assert.strictEqual(saved.status, 200);

  const pub = await call(analytics);
  assert.strictEqual(pub.body.data.male, 20);
  const same = await call(analytics, { headers: { 'if-none-match': pub.headers.etag } });
  assert.strictEqual(same.status, 304);

  const bad = await call(analytics, { method: 'PUT', headers: h, body: { data: { ...sample(), male: 80 } } });
  assert.strictEqual(bad.status, 400);
  assert.strictEqual((await call(analytics)).body.data.male, 20);

  assert.strictEqual((await call(analytics, { method: 'DELETE', headers: h })).status, 200);
  assert.strictEqual((await call(analytics)).status, 404);
});

test('a forged or expired token is refused', async () => {
  const forged = await call(analytics, { method: 'PUT', headers: authed('abc.def'), body: { data: sample() } });
  assert.strictEqual(forged.status, 401);
});

test('repeated wrong PINs are throttled per address', async () => {
  let last;
  for (let i = 0; i < 6; i++) last = await signIn('bad', '9.9.9.9');
  assert.strictEqual(last.status, 429);
  assert.strictEqual((await signIn('4321', '8.8.8.8')).status, 200);
});

test('missing settings give a clear error, not a crash', async () => {
  const pin = process.env.ADMIN_PIN;
  delete process.env.ADMIN_PIN;
  const out = await call(analytics);
  process.env.ADMIN_PIN = pin;
  assert.strictEqual(out.status, 500);
  assert.match(out.body.error, /ADMIN_PIN/);
});

test('hosted without a database refuses instead of losing edits', async () => {
  process.env.VERCEL = '1';
  const out = await call(analytics);
  delete process.env.VERCEL;
  assert.strictEqual(out.status, 500);
  assert.match(out.body.error, /Redis/);
});

test('works against a Redis REST server (Upstash protocol)', async () => {
  const kv = new Map();
  const seen = [];
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      assert.strictEqual(req.headers.authorization, 'Bearer tok');
      const [cmd, key, val] = JSON.parse(raw);
      seen.push(cmd);
      let result = null;
      if (cmd === 'GET') result = kv.get(key) ?? null;
      if (cmd === 'SET') { kv.set(key, val); result = 'OK'; }
      if (cmd === 'DEL') { result = kv.delete(key) ? 1 : 0; }
      if (cmd === 'INCR') { kv.set(key, String(Number(kv.get(key) || 0) + 1)); result = Number(kv.get(key)); }
      if (cmd === 'EXPIRE') result = 1;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ result }));
    });
  });
  await new Promise((r) => server.listen(0, r));
  process.env.UPSTASH_REDIS_REST_URL = `http://localhost:${server.address().port}`;
  process.env.UPSTASH_REDIS_REST_TOKEN = 'tok';
  try {
    const { body } = await signIn('4321', '7.7.7.7');
    const put = await call(analytics, { method: 'PUT', headers: authed(body.token), body: { data: sample(30) } });
    assert.strictEqual(put.status, 200);
    assert.strictEqual((await call(analytics)).body.data.male, 30);
    assert.ok(JSON.parse(kv.get('analytics:data')).updatedAt);
    await signIn('nope', '6.6.6.6');
    assert.ok(seen.includes('INCR') && seen.includes('EXPIRE'));
  } finally {
    delete process.env.UPSTASH_REDIS_REST_URL;
    delete process.env.UPSTASH_REDIS_REST_TOKEN;
    server.closeAllConnections();
    server.close();
  }
});
