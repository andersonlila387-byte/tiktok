const test = require('node:test');
const assert = require('node:assert');
const http = require('http');

process.env.ADMIN_PIN = '4321';
delete process.env.VERCEL;
delete process.env.UPSTASH_REDIS_REST_URL;
delete process.env.KV_REST_API_URL;

const analytics = require('../api/analytics');
const login = require('../api/login');

const zeros = (n) => Array(n).fill(0);
const post = (views = 39) => ({
  id: 'p1',
  caption: 'Lions',
  thumbnailUrl: '',
  postedAt: '2024-07-03T11:52:00.000',
  updatedAt: '2026-11-02T10:00:00.000',
  durationSec: 55.87,
  views,
  likes: 6,
  comments: 0,
  shares: 0,
  saves: 0,
  playTimeSec: 383,
  avgWatchSec: 8.5,
  fullWatchPct: 8.89,
  newFollowers: 0,
  avgWatchedPct: 15,
  stopSec: 2,
  likePeakSec: 2,
  totalViewers: 28,
  viewersChange: -1,
  newViewers: 12,
  followerViewers: 0,
  male: 0,
  female: 5,
  other: 2,
  ages: [3, 2, 1, 1, 0],
  locations: [{ name: 'US', count: 4 }],
  traffic: [{ name: 'For You', count: 9 }],
  queries: [],
  topWords: [{ name: 'wow', count: 3 }],
});
const sample = (views = 39) => ({
  posts: [post(views)],
  inspiration: { trending: [{ caption: 'c', likes: '1M', author: 'a' }] },
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

test('password check accepts only the right password', async () => {
  assert.strictEqual((await signIn('0000')).status, 401);
  const ok = await signIn();
  assert.strictEqual(ok.status, 200);
  assert.strictEqual(ok.body.ok, true);
});

test('writes need the password; edits are public and validated', async () => {
  assert.strictEqual((await call(analytics, { method: 'PUT', body: { data: sample() } })).status, 401);
  const { body } = await signIn();
  const h = authed('4321');

  const saved = await call(analytics, { method: 'PUT', headers: h, body: { data: sample(20) } });
  assert.strictEqual(saved.status, 200);

  const pub = await call(analytics);
  assert.strictEqual(pub.body.data.posts[0].views, 20);
  const same = await call(analytics, { headers: { 'if-none-match': pub.headers.etag } });
  assert.strictEqual(same.status, 304);

  const bad = await call(analytics, { method: 'PUT', headers: h, body: { data: { ...sample(), posts: [{ ...post(), views: "x" }] } } });
  assert.strictEqual(bad.status, 400);
  assert.strictEqual((await call(analytics)).body.data.posts[0].views, 20);

  assert.strictEqual((await call(analytics, { method: 'DELETE', headers: h })).status, 200);
  assert.strictEqual((await call(analytics)).status, 404);
});

test('a wrong password on a save is refused', async () => {
  const forged = await call(analytics, { method: 'PUT', headers: authed('abc.def'), body: { data: sample() } });
  assert.strictEqual(forged.status, 401);
});

test('repeated wrong passwords are throttled per address', async () => {
  let last;
  for (let i = 0; i < 6; i++) last = await signIn('bad', '9.9.9.9');
  assert.strictEqual(last.status, 429);
  assert.strictEqual((await signIn('4321', '8.8.8.8')).status, 200);
});

test('with nothing configured the default password in the code works', async () => {
  const saved = process.env.ADMIN_PIN;
  delete process.env.ADMIN_PIN;
  try {
    const lib = require('../api/_lib');
    assert.strictEqual((await signIn(lib.DEFAULT_PASSWORD, '4.4.4.4')).status, 200);
    assert.strictEqual((await signIn('nope', '4.4.4.4')).body.error, 'Incorrect password');
  } finally {
    process.env.ADMIN_PIN = saved;
  }
});

test('pictures that make the figures too large are refused', async () => {
  const big = sample();
  big.posts[0].thumbnailUrl = 'data:image/jpeg;base64,' + 'A'.repeat(1_000_000);
  const out = await call(analytics, { method: 'PUT', headers: authed('4321'), body: { data: big } });
  assert.strictEqual(out.status, 400);
  assert.match(out.body.error, /pictures/);
});

test('hosted without a database refuses instead of losing edits', async () => {
  process.env.VERCEL = '1';
  const out = await call(analytics);
  delete process.env.VERCEL;
  assert.strictEqual(out.status, 500);
  assert.match(out.body.error, /GITHUB_TOKEN/);
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
    const put = await call(analytics, { method: 'PUT', headers: authed('4321'), body: { data: sample(30) } });
    assert.strictEqual(put.status, 200);
    assert.strictEqual((await call(analytics)).body.data.posts[0].views, 30);
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

test('stores the figures as a JSON file in a GitHub repo, no database', async () => {
  const files = new Map(); // "branch:path" -> { content, sha }
  const branches = new Set(['main']);
  let n = 0;
  const server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      assert.strictEqual(req.headers.authorization, 'Bearer ghtok');
      const url = new URL(req.url, 'http://x');
      const body = raw ? JSON.parse(raw) : null;
      const out = (status, json) => {
        res.statusCode = status;
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(json));
      };
      const p = url.pathname.replace('/repos/me/site', '');
      if (p === '') return out(200, { default_branch: 'main' });
      let m = /^\/git\/ref\/heads\/(.+)$/.exec(p);
      if (m) return branches.has(m[1]) ? out(200, { object: { sha: 'base' } }) : out(404, { message: 'Not Found' });
      if (p === '/git/refs') { branches.add(body.ref.replace('refs/heads/', '')); return out(201, {}); }
      m = /^\/contents\/(.+)$/.exec(p);
      if (!m) return out(404, { message: 'Not Found' });
      const key = `${req.method === 'GET' ? url.searchParams.get('ref') : body.branch}:${m[1]}`;
      const cur = files.get(key);
      if (req.method === 'GET') {
        return cur ? out(200, { content: cur.content, sha: cur.sha }) : out(404, { message: 'Not Found' });
      }
      if (!branches.has(body.branch)) return out(422, { message: 'Branch not found' });
      if (cur && body.sha !== cur.sha) return out(409, { message: 'sha mismatch' });
      if (req.method === 'DELETE') { files.delete(key); return out(200, {}); }
      const next = { content: body.content, sha: `sha${++n}` };
      files.set(key, next);
      return out(cur ? 200 : 201, { content: { sha: next.sha } });
    });
  });
  await new Promise((r) => server.listen(0, r));
  const saved = { ...process.env };
  process.env.GITHUB_TOKEN = 'ghtok';
  process.env.GITHUB_REPO = 'me/site';
  process.env.GITHUB_API_URL = `http://localhost:${server.address().port}`;
  try {
    const { body } = await signIn('4321', '5.5.5.5');
    const h = authed('4321');
    const put = await call(analytics, { method: 'PUT', headers: h, body: { data: sample(11) } });
    assert.strictEqual(put.status, 200);
    assert.ok(branches.has('data'), 'branch created on first save');
    const file = files.get('data:data/analytics.json');
    assert.strictEqual(JSON.parse(Buffer.from(file.content, 'base64').toString()).data.posts[0].views, 11);
    assert.strictEqual((await call(analytics)).body.data.posts[0].views, 11);
    // A second save updates the same file.
    assert.strictEqual((await call(analytics, { method: 'PUT', headers: h, body: { data: sample(12) } })).status, 200);
    assert.strictEqual(JSON.parse(Buffer.from(files.get('data:data/analytics.json').content, 'base64').toString()).data.posts[0].views, 12);
    assert.strictEqual((await call(analytics, { method: 'DELETE', headers: h })).status, 200);
    assert.strictEqual(files.size, 0);
  } finally {
    for (const k of ['GITHUB_TOKEN', 'GITHUB_REPO', 'GITHUB_API_URL']) delete process.env[k];
    server.closeAllConnections();
    server.close();
  }
});
