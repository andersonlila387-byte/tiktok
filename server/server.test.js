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
    env: { ...process.env, PORT: String(port), ADMIN_PIN: '4321', DATA_FILE: dataFile, TOKEN_SECRET: 'test' },
    stdio: 'ignore',
  });
  return new Promise((resolve) => setTimeout(resolve, 600));
}

const zeros = (n) => Array(n).fill(0);
const sample = (male = 56) => ({
  topWords: [],
  followers: Array(31).fill(120),
  metrics: { Likes: zeros(30), 'Post views': zeros(30) },
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
  dashMetrics: ['Comments'],
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

test('wrong PIN is rejected, right PIN gives a token', async () => {
  assert.strictEqual((await login('0000')).status, 401);
  const ok = await login('4321');
  assert.strictEqual(ok.status, 200);
  assert.ok(ok.body.token);
});

test('writing needs a valid token', async () => {
  assert.strictEqual((await put('nope', sample())).status, 401);
  const res = await fetch(`${base}/api/analytics`, { method: 'PUT', body: '{}' });
  assert.strictEqual(res.status, 401);
});

test('admin edits are public, validated and survive a restart', async () => {
  const { body } = await login('4321');
  assert.strictEqual((await put(body.token, sample(20))).status, 200);

  const pub = await fetch(`${base}/api/analytics`);
  assert.strictEqual((await pub.json()).data.male, 20);

  // 304 when nothing changed.
  const again = await fetch(`${base}/api/analytics`, {
    headers: { 'If-None-Match': pub.headers.get('etag') },
  });
  assert.strictEqual(again.status, 304);

  // Gender over 100 and malformed series are refused and change nothing.
  assert.strictEqual((await put(body.token, { ...sample(), male: 80 })).status, 400);
  assert.strictEqual((await put(body.token, { ...sample(), hourly: [1] })).status, 400);
  assert.strictEqual((await (await fetch(`${base}/api/analytics`)).json()).data.male, 20);

  proc.kill();
  await new Promise((r) => setTimeout(r, 300));
  await start();
  assert.strictEqual((await (await fetch(`${base}/api/analytics`)).json()).data.male, 20);
});

test('reset removes saved data', async () => {
  const { body } = await login('4321');
  const del = await fetch(`${base}/api/analytics`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${body.token}` },
  });
  assert.strictEqual(del.status, 200);
  assert.strictEqual((await fetch(`${base}/api/analytics`)).status, 404);
});

test('repeated wrong PINs are throttled', async () => {
  let last;
  for (let i = 0; i < 6; i++) last = await login('bad');
  assert.strictEqual(last.status, 429);
});
