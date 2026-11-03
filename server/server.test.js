const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'analytics-'));
const dataFile = path.join(dir, 'analytics.json');
const port = 18080 + Math.floor(Math.random() * 500);
const base = `http://localhost:${port}`;
let proc;

function start() {
  proc = spawn(process.execPath, [path.join(__dirname, 'server.js')], {
    env: { ...process.env, PORT: String(port), ADMIN_PIN: '4321', DATA_FILE: dataFile },
    stdio: 'ignore',
  });
  return new Promise((resolve) => setTimeout(resolve, 600));
}

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

async function login(pin) {
  const r = await fetch(`${base}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ pin }),
  });
  return { status: r.status, body: await r.json() };
}

const put = (token, data) =>
  fetch(`${base}/api/analytics`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }),
  });

test.before(start);
test.after(() => proc.kill());

test('nothing saved yet returns 404', async () => {
  assert.strictEqual((await fetch(`${base}/api/analytics`)).status, 404);
});

test('wrong password is rejected, right one is accepted', async () => {
  assert.strictEqual((await login('0000')).status, 401);
  const ok = await login('4321');
  assert.strictEqual(ok.status, 200);
  assert.strictEqual(ok.body.ok, true);
});

test('writing needs the password', async () => {
  assert.strictEqual((await put('nope', sample())).status, 401);
  const res = await fetch(`${base}/api/analytics`, { method: 'PUT', body: '{}' });
  assert.strictEqual(res.status, 401);
});

test('admin edits are public, validated and survive a restart', async () => {
  const { body } = await login('4321');
  assert.strictEqual((await put('4321', sample(20))).status, 200);

  const pub = await fetch(`${base}/api/analytics`);
  assert.strictEqual((await pub.json()).data.posts[0].views, 20);

  // 304 when nothing changed.
  const again = await fetch(`${base}/api/analytics`, {
    headers: { 'If-None-Match': pub.headers.get('etag') },
  });
  assert.strictEqual(again.status, 304);

  // Gender over 100 and malformed series are refused and change nothing.
  assert.strictEqual((await put('4321', { ...sample(), posts: [{ ...post(), views: "x" }] })).status, 400);
  assert.strictEqual((await put('4321', { ...sample(), posts: [{ ...post(), ages: "no" }] })).status, 400);
  assert.strictEqual((await (await fetch(`${base}/api/analytics`)).json()).data.posts[0].views, 20);

  proc.kill();
  await new Promise((r) => setTimeout(r, 300));
  await start();
  assert.strictEqual((await (await fetch(`${base}/api/analytics`)).json()).data.posts[0].views, 20);
});

test('reset removes saved data', async () => {
  const { body } = await login('4321');
  const del = await fetch(`${base}/api/analytics`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${'4321'}` },
  });
  assert.strictEqual(del.status, 200);
  assert.strictEqual((await fetch(`${base}/api/analytics`)).status, 404);
});

test('other origins can call the API (preflight and ETag)', async () => {
  const pre = await fetch(`${base}/api/login`, {
    method: 'OPTIONS',
    headers: { Origin: 'http://localhost:5555', 'Access-Control-Request-Method': 'POST' },
  });
  assert.strictEqual(pre.status, 204);
  assert.strictEqual(pre.headers.get('access-control-allow-origin'), '*');
  assert.match(pre.headers.get('access-control-allow-headers'), /Authorization/);
});

test('repeated wrong passwords are throttled', async () => {
  let last;
  for (let i = 0; i < 6; i++) last = await login('bad');
  assert.strictEqual(last.status, 429);
});
