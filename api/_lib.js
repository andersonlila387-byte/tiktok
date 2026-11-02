// Shared by the Vercel functions in this folder and by server/server.js.
// Files starting with "_" are not exposed as endpoints.

const crypto = require('crypto');

const TOKEN_TTL_MS = 12 * 60 * 60 * 1000;
const KEY = 'analytics:data';
const MAX_ATTEMPTS = 5;

/** The dashboard may be opened from another address while developing. Admin
 *  calls carry a bearer token, not cookies, so allowing any origin does not
 *  expose a signed-in session. */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, If-None-Match',
  'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
  'Access-Control-Expose-Headers': 'ETag',
};

/** Checks the payload has the shape the app reads, so a bad request cannot
 *  break every visitor's dashboard. Returns a problem description or null. */
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

/** Login tokens: signed, expiring, no database needed. */
function makeAuth(secret, pin) {
  const sign = (payload) => crypto.createHmac('sha256', secret).update(payload).digest('base64url');
  const hash = (v) => crypto.createHash('sha256').update(String(v)).digest();
  return {
    pinMatches: (entered) => crypto.timingSafeEqual(hash(entered), hash(pin)),
    issueToken() {
      const payload = Buffer.from(JSON.stringify({ exp: Date.now() + TOKEN_TTL_MS })).toString('base64url');
      return `${payload}.${sign(payload)}`;
    },
    tokenValid(header) {
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
    },
  };
}

// ------------------------------------------------------------------ storage

/** Upstash Redis through its REST API (no npm package needed). */
function redisStore(url, token) {
  async function cmd(...args) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
    });
    const body = await res.json();
    if (!res.ok || body.error) throw new Error(body.error || `Redis HTTP ${res.status}`);
    return body.result;
  }
  return {
    async get() {
      const raw = await cmd('GET', KEY);
      return raw ? JSON.parse(raw) : null;
    },
    async set(value) {
      await cmd('SET', KEY, JSON.stringify(value));
    },
    async del() {
      await cmd('DEL', KEY);
    },
    /** Counts a failed login for [ip]; the count resets after a minute. */
    async failures(ip) {
      return Number((await cmd('GET', `login:${ip}`)) || 0);
    },
    async noteFailure(ip) {
      const n = await cmd('INCR', `login:${ip}`);
      if (n === 1) await cmd('EXPIRE', `login:${ip}`, 60);
    },
    async clearFailures(ip) {
      await cmd('DEL', `login:${ip}`);
    },
  };
}

/** In-process store, for tests and local runs only. */
function memoryStore() {
  let value = null;
  const fails = new Map();
  return {
    async get() { return value; },
    async set(v) { value = v; },
    async del() { value = null; },
    async failures(ip) {
      const r = fails.get(ip);
      return r && Date.now() - r.first < 60_000 ? r.count : 0;
    },
    async noteFailure(ip) {
      const r = fails.get(ip);
      if (!r || Date.now() - r.first >= 60_000) fails.set(ip, { count: 1, first: Date.now() });
      else r.count++;
    },
    async clearFailures(ip) { fails.delete(ip); },
  };
}

let memory;

/** Settings from the environment, or {error} when something is missing. */
function config(env = process.env) {
  const pin = env.ADMIN_PIN;
  const secret = env.TOKEN_SECRET;
  if (!pin || !secret) {
    return { error: 'Server not configured: set ADMIN_PIN and TOKEN_SECRET.' };
  }
  const url = env.UPSTASH_REDIS_REST_URL || env.KV_REST_API_URL;
  const token = env.UPSTASH_REDIS_REST_TOKEN || env.KV_REST_API_TOKEN;
  let store;
  if (url && token) {
    store = redisStore(url, token);
  } else if (env.VERCEL) {
    // Memory would silently lose edits between requests when hosted.
    return { error: 'Storage not configured: connect an Upstash Redis database.' };
  } else {
    store = memory ||= memoryStore();
  }
  return { store, auth: makeAuth(secret, pin) };
}

// --------------------------------------------------------------------- http

function send(res, status, body, headers = {}) {
  const isJson = body !== '' && typeof body === 'object';
  res.statusCode = status;
  for (const [k, v] of Object.entries({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...CORS,
    ...headers,
  })) {
    res.setHeader(k, v);
  }
  res.end(isJson ? JSON.stringify(body) : body);
}

/** The request body as an object (Vercel parses JSON bodies already). */
function bodyOf(req) {
  const b = req.body;
  if (typeof b === 'string') {
    try { return JSON.parse(b); } catch (_) { return undefined; }
  }
  return b;
}

function clientIp(req) {
  const fwd = req.headers['x-forwarded-for'];
  return (fwd ? String(fwd).split(',')[0].trim() : req.socket && req.socket.remoteAddress) || 'unknown';
}

/** Answers CORS preflights; returns true when the request is finished. */
function preflight(req, res) {
  if (req.method !== 'OPTIONS') return false;
  res.statusCode = 204;
  for (const [k, v] of Object.entries({ ...CORS, 'Access-Control-Max-Age': '86400' })) {
    res.setHeader(k, v);
  }
  res.end();
  return true;
}

module.exports = {
  MAX_ATTEMPTS,
  validate,
  makeAuth,
  memoryStore,
  config,
  send,
  bodyOf,
  clientIp,
  preflight,
};
