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

const { validate, makeAuth } = require('../api/_lib');
const auth = makeAuth(SECRET, ADMIN_PIN);
const pinMatches = auth.pinMatches;
const issueToken = auth.issueToken;
const tokenValid = auth.tokenValid;

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
