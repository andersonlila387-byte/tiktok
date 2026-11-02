// Analytics backend: stores the dashboard figures, lets the admin change them,
// and serves the built Flutter web app. No npm dependencies.
//
//   ADMIN_PIN     admin password (required in production; defaults to 1234)
//   PORT          listen port (default 8080)
//   DATA_FILE     where figures are stored (default ./data/analytics.json)
//   WEB_DIR       built Flutter web app (default ../pulse_analytics/build/web)
//   TOKEN_SECRET  signs login tokens (default: random per start, so admin
//                 sessions end when the server restarts)

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8080);
const ADMIN_PIN = process.env.ADMIN_PIN || '1234';
const DATA_FILE = path.resolve(
  process.env.DATA_FILE || path.join(__dirname, 'data', 'analytics.json'),
);
const WEB_DIR = path.resolve(
  process.env.WEB_DIR ||
    path.join(__dirname, '..', 'pulse_analytics', 'build', 'web'),
);
const SECRET = process.env.TOKEN_SECRET || crypto.randomBytes(32).toString('hex');
const TOKEN_TTL_MS = 12 * 60 * 60 * 1000;
const MAX_BODY = 8 * 1024 * 1024;

if (!process.env.ADMIN_PIN) {
  console.warn('ADMIN_PIN not set: using the default PIN 1234. Set it before going live.');
}

// ------------------------------------------------------------------ storage

/** {updatedAt: number, data: object} or null when nothing was saved yet. */
let current = null;
try {
  current = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
} catch (_) {
  current = null;
}

function persist(data) {
  const next = { updatedAt: Date.now(), data };
  if (current && next.updatedAt <= current.updatedAt) {
    next.updatedAt = current.updatedAt + 1;
  }
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  const tmp = `${DATA_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(next));
  fs.renameSync(tmp, DATA_FILE);
  current = next;
  return next.updatedAt;
}

function clearData() {
  try {
    fs.unlinkSync(DATA_FILE);
  } catch (_) {}
  current = null;
}

/** Checks the payload has the shape the app reads, so a bad request cannot
 *  break every visitor's dashboard. */
function validate(data) {
  const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);
  const nums = (v, n) =>
    Array.isArray(v) && (n == null || v.length === n) && v.every(Number.isFinite);
  if (!isObj(data)) return 'data must be an object';
  if (!nums(data.followers) || data.followers.length < 2) return 'followers';
  if (!isObj(data.metrics)) return 'metrics';
  for (const [k, v] of Object.entries(data.metrics)) {
    if (!nums(v) || v.length !== data.followers.length - 1) return `metrics.${k}`;
  }
  if (![data.male, data.female].every(Number.isFinite)) return 'gender';
  if (data.male < 0 || data.female < 0 || data.male + data.female > 100.0001) {
    return 'gender must add up to at most 100';
  }
  if (!isObj(data.ages) || !Object.values(data.ages).every(Number.isFinite)) return 'ages';
  for (const key of ['locations', 'traffic']) {
    const ok =
      Array.isArray(data[key]) &&
      data[key].every((e) => e && typeof e.name === 'string' && Number.isFinite(e.percent));
    if (!ok) return key;
  }
  for (const key of ['topWords', 'queries']) {
    const ok =
      Array.isArray(data[key]) &&
      data[key].every((e) => e && typeof e.word === 'string' && Number.isFinite(e.count));
    if (!ok) return key;
  }
  if (!nums(data.hourly, 24) || !nums(data.viewerHourly, 24)) return 'hourly';
  if (!nums(data.weekday, 7) || !nums(data.viewerWeekday, 7)) return 'weekday';
  if (!Array.isArray(data.dashMetrics) || !data.dashMetrics.every((e) => typeof e === 'string')) {
    return 'dashMetrics';
  }
  return null;
}

// --------------------------------------------------------------------- auth

function sign(payload) {
  return crypto.createHmac('sha256', SECRET).update(payload).digest('base64url');
}

function issueToken() {
  const payload = Buffer.from(JSON.stringify({ exp: Date.now() + TOKEN_TTL_MS })).toString('base64url');
  return `${payload}.${sign(payload)}`;
}

function tokenValid(header) {
  const m = /^Bearer (.+)$/.exec(header || '');
  if (!m) return false;
  const [payload, sig] = m[1].split('.');
  if (!payload || !sig) return false;
  const want = Buffer.from(sign(payload));
  const got = Buffer.from(sig);
  if (want.length !== got.length || !crypto.timingSafeEqual(want, got)) return false;
  try {
    return JSON.parse(Buffer.from(payload, 'base64url').toString()).exp > Date.now();
  } catch (_) {
    return false;
  }
}

function pinMatches(pin) {
  const a = crypto.createHash('sha256').update(String(pin)).digest();
  const b = crypto.createHash('sha256').update(ADMIN_PIN).digest();
  return crypto.timingSafeEqual(a, b);
}

/** Five wrong PINs from one address block further tries for a minute. */
const attempts = new Map();
function throttled(ip) {
  const now = Date.now();
  const rec = attempts.get(ip);
  return !!rec && rec.count >= 5 && now - rec.first < 60_000;
}
function noteFailure(ip) {
  const now = Date.now();
  const rec = attempts.get(ip);
  if (!rec || now - rec.first >= 60_000) attempts.set(ip, { count: 1, first: now });
  else rec.count++;
}

// --------------------------------------------------------------------- http

/** The dashboard may be opened from another address while developing (for
 *  example `flutter run`). Admin calls carry a bearer token, not cookies, so
 *  allowing any origin does not expose a signed-in session. */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, If-None-Match',
  'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
  'Access-Control-Expose-Headers': 'ETag',
};

function send(res, status, body, headers = {}) {
  const isJson = typeof body === 'object' && !Buffer.isBuffer(body);
  const payload = isJson ? JSON.stringify(body) : body;
  res.writeHead(status, {
    'Content-Type': isJson ? 'application/json; charset=utf-8' : 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
    ...CORS,
    ...headers,
  });
  res.end(payload);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(Object.assign(new Error('too large'), { status: 413 }));
        req.destroy();
      } else chunks.push(c);
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || 'null'));
      } catch (_) {
        reject(Object.assign(new Error('invalid JSON'), { status: 400 }));
      }
    });
    req.on('error', reject);
  });
}

async function api(req, res, pathname) {
  const ip = req.socket.remoteAddress || '';

  if (pathname === '/api/login' && req.method === 'POST') {
    if (throttled(ip)) return send(res, 429, { error: 'Too many attempts. Try again in a minute.' });
    const body = await readBody(req);
    if (body && pinMatches(body.pin ?? '')) {
      attempts.delete(ip);
      return send(res, 200, { token: issueToken() });
    }
    noteFailure(ip);
    return send(res, 401, { error: 'Incorrect PIN' });
  }

  if (pathname === '/api/analytics') {
    if (req.method === 'GET') {
      if (!current) return send(res, 404, { error: 'No data saved yet' });
      const tag = `"${current.updatedAt}"`;
      if (req.headers['if-none-match'] === tag) return send(res, 304, '', { ETag: tag });
      return send(res, 200, current, { ETag: tag });
    }
    if (!tokenValid(req.headers.authorization)) return send(res, 401, { error: 'Admin sign-in required' });
    if (req.method === 'PUT') {
      const body = await readBody(req);
      const problem = validate(body && body.data);
      if (problem) return send(res, 400, { error: `Invalid data: ${problem}` });
      const updatedAt = persist(body.data);
      return send(res, 200, { updatedAt }, { ETag: `"${updatedAt}"` });
    }
    if (req.method === 'DELETE') {
      clearData();
      return send(res, 200, { ok: true });
    }
    return send(res, 405, { error: 'Method not allowed' });
  }

  return send(res, 404, { error: 'Not found' });
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.frag': 'text/plain',
};

function serveStatic(req, res, pathname) {
  let rel = decodeURIComponent(pathname);
  if (rel.endsWith('/')) rel += 'index.html';
  let file = path.join(WEB_DIR, rel);
  if (!file.startsWith(WEB_DIR)) return send(res, 403, 'Forbidden');
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(WEB_DIR, 'index.html'); // single-page app fallback
  }
  if (!fs.existsSync(file)) {
    return send(res, 404, 'The web app is not built yet. Run: flutter build web');
  }
  const ext = path.extname(file).toLowerCase();
  res.writeHead(200, {
    'Content-Type': MIME[ext] || 'application/octet-stream',
    // The app files change between releases; always revalidate.
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(file).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  try {
    if (pathname.startsWith('/api/')) {
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { ...CORS, 'Access-Control-Max-Age': '86400' });
        return res.end();
      }
      return await api(req, res, pathname);
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, 'Method not allowed');
    return serveStatic(req, res, pathname);
  } catch (e) {
    return send(res, e.status || 500, { error: e.status ? e.message : 'Server error' });
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`Analytics server on http://localhost:${PORT}`));
}

module.exports = { server, validate };
