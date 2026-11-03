// Shared by the Vercel functions in this folder and by server/server.js.
// Files starting with "_" are not exposed as endpoints.

const crypto = require('crypto');

/** The admin password. Change it here and push; nothing else to configure.
 *  (An ADMIN_PASSWORD environment variable overrides it if you ever want that.)
 *  Keep the GitHub repo private, since anyone who can read the code sees it. */
const DEFAULT_PASSWORD = '1234';
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

const POST_NUMBERS = [
  'durationSec', 'views', 'likes', 'comments', 'shares', 'saves', 'playTimeSec',
  'avgWatchSec', 'fullWatchPct', 'newFollowers', 'avgWatchedPct', 'stopSec',
  'likePeakSec', 'totalViewers', 'viewersChange', 'newViewers', 'followerViewers',
  'male', 'female', 'other',
];
const POST_TALLIES = ['locations', 'traffic', 'queries', 'topWords'];
const MAX_POSTS = 500;
/** Uploaded pictures are saved inside the figures, so keep the file under
 *  GitHub's 1 MB inline-read limit. */
const MAX_DATA_BYTES = 900 * 1024;

/** Checks the payload has the shape the app reads, so a bad request cannot
 *  break every visitor's page. Returns a problem description or null. */
function validate(data) {
  const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);
  if (!isObj(data)) return 'data must be an object';
  if (!Array.isArray(data.posts) || data.posts.length > MAX_POSTS) return 'posts';
  const ids = new Set();
  for (const [i, p] of data.posts.entries()) {
    const at = `posts[${i}]`;
    if (!isObj(p)) return at;
    if (typeof p.id !== 'string' || !p.id || ids.has(p.id)) return `${at}.id`;
    ids.add(p.id);
    for (const k of ['caption', 'thumbnailUrl']) {
      if (typeof p[k] !== 'string') return `${at}.${k}`;
    }
    for (const k of ['postedAt', 'updatedAt']) {
      if (typeof p[k] !== 'string' || Number.isNaN(Date.parse(p[k]))) return `${at}.${k}`;
    }
    for (const k of POST_NUMBERS) {
      if (!Number.isFinite(p[k])) return `${at}.${k}`;
    }
    if (!Array.isArray(p.ages) || !p.ages.every(Number.isFinite)) return `${at}.ages`;
    for (const k of POST_TALLIES) {
      const ok =
        Array.isArray(p[k]) &&
        p[k].every((e) => e && typeof e.name === 'string' && Number.isFinite(e.count));
      if (!ok) return `${at}.${k}`;
    }
  }
  if (!isObj(data.inspiration)) return 'inspiration';
  if (Buffer.byteLength(JSON.stringify(data)) > MAX_DATA_BYTES) {
    return 'too many or too large pictures (limit about 900 KB in total); remove some';
  }
  for (const [k, list] of Object.entries(data.inspiration)) {
    const ok =
      Array.isArray(list) &&
      list.every(
        (e) =>
          e &&
          ['caption', 'likes', 'author'].every((f) => typeof e[f] === 'string') &&
          ['image', 'avatar'].every((f) => e[f] === undefined || typeof e[f] === 'string'),
      );
    if (!ok) return `inspiration.${k}`;
  }
  return null;
}

/** Admin check: the password typed at sign-in is sent with every save and
 *  compared with the one in the code. */
function makeAuth(password) {
  const hash = (v) => crypto.createHash('sha256').update(String(v)).digest();
  const matches = (entered) => crypto.timingSafeEqual(hash(entered), hash(password));
  return {
    passwordMatches: matches,
    authorised(header) {
      const m = /^Bearer (.*)$/.exec(header || '');
      return !!m && matches(m[1]);
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

/** The figures kept as one JSON file (data/analytics.json) on a separate
 *  branch of the GitHub repo, through GitHub's contents API. No database to
 *  set up; the branch is created on the first save. Reads are cached for a few
 *  seconds so polling visitors do not exhaust GitHub's rate limit. */
function githubStore({ token, repo, branch = 'data', file = 'data/analytics.json', api = 'https://api.github.com' }) {
  const CACHE_MS = 5000;
  let cache = null; // { at, value, sha }
  const throttle = memoryStore(); // login attempts only live in this process

  async function gh(method, path, body) {
    const res = await fetch(`${api}/repos/${repo}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/vnd.github+json',
        'User-Agent': 'analytics-dashboard',
        'Content-Type': 'application/json',
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch (_) { /* not JSON */ }
    return { status: res.status, json };
  }

  const fail = (what, r) => {
    const why = (r.json && r.json.message) || `HTTP ${r.status}`;
    return new Error(`GitHub ${what} failed: ${why}`);
  };

  async function load() {
    const r = await gh('GET', `/contents/${file}?ref=${encodeURIComponent(branch)}`);
    if (r.status === 404) return { value: null, sha: null };
    if (r.status !== 200) throw fail('read', r);
    const value = JSON.parse(Buffer.from(r.json.content, 'base64').toString('utf8'));
    return { value, sha: r.json.sha };
  }

  async function ensureBranch() {
    if ((await gh('GET', `/git/ref/heads/${encodeURIComponent(branch)}`)).status === 200) return;
    const repoInfo = await gh('GET', '');
    if (repoInfo.status !== 200) throw fail('lookup', repoInfo);
    const base = await gh('GET', `/git/ref/heads/${encodeURIComponent(repoInfo.json.default_branch)}`);
    if (base.status !== 200) throw fail('lookup', base);
    const made = await gh('POST', '/git/refs', { ref: `refs/heads/${branch}`, sha: base.json.object.sha });
    if (made.status !== 201 && made.status !== 422) throw fail('branch creation', made);
  }

  async function read() {
    if (cache && Date.now() - cache.at < CACHE_MS) return cache;
    const fresh = await load();
    cache = { at: Date.now(), ...fresh };
    return cache;
  }

  async function write(value) {
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = await load();
      if (current.sha === null) await ensureBranch();
      const body = {
        message: value === null ? 'Reset analytics data' : 'Update analytics data',
        branch,
        sha: current.sha || undefined,
      };
      let r;
      if (value === null) {
        if (!current.sha) { cache = { at: Date.now(), value: null, sha: null }; return; }
        r = await gh('DELETE', `/contents/${file}`, body);
      } else {
        body.content = Buffer.from(JSON.stringify(value)).toString('base64');
        r = await gh('PUT', `/contents/${file}`, body);
      }
      if (r.status === 200 || r.status === 201) {
        cache = { at: Date.now(), value, sha: r.json && r.json.content ? r.json.content.sha : null };
        return;
      }
      // Someone saved in between (409/422): reload the file's version and retry.
      if (r.status !== 409 && r.status !== 422) throw fail('save', r);
    }
    throw new Error('GitHub save failed: the file kept changing, try again');
  }

  return {
    async get() { return (await read()).value; },
    set: (value) => write(value),
    del: () => write(null),
    failures: throttle.failures,
    noteFailure: throttle.noteFailure,
    clearFailures: throttle.clearFailures,
  };
}

let memory;

/** Settings from the environment, or {error} when something is missing. */
function config(env = process.env) {
  const password = env.ADMIN_PASSWORD || env.ADMIN_PIN || DEFAULT_PASSWORD;
  const url = env.UPSTASH_REDIS_REST_URL || env.KV_REST_API_URL;
  const token = env.UPSTASH_REDIS_REST_TOKEN || env.KV_REST_API_TOKEN;
  const ghToken = env.GITHUB_TOKEN;
  // Vercel tells every deployment which repo it was built from.
  const repo =
    env.GITHUB_REPO ||
    (env.VERCEL_GIT_REPO_OWNER && env.VERCEL_GIT_REPO_SLUG
      ? `${env.VERCEL_GIT_REPO_OWNER}/${env.VERCEL_GIT_REPO_SLUG}`
      : '');
  let store;
  if (url && token) {
    store = redisStore(url, token);
  } else if (ghToken) {
    if (!repo) return { error: 'Storage not configured: set GITHUB_REPO to owner/name.' };
    store = githubStore({
      token: ghToken,
      repo,
      branch: env.GITHUB_BRANCH || 'data',
      api: env.GITHUB_API_URL || 'https://api.github.com',
    });
  } else if (env.VERCEL) {
    // Memory would silently lose edits between requests when hosted.
    return { error: 'Storage not configured: set GITHUB_TOKEN so figures can be saved.' };
  } else {
    store = memory ||= memoryStore();
  }
  return { store, auth: makeAuth(password) };
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
  DEFAULT_PASSWORD,
  MAX_DATA_BYTES,
  memoryStore,
  config,
  send,
  bodyOf,
  clientIp,
  preflight,
};
