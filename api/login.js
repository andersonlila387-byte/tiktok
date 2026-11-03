// POST /api/login  {password}  ->  {ok: true}, or 401 when it is wrong
const lib = require('./_lib');

module.exports = async (req, res) => {
  if (lib.preflight(req, res)) return;
  if (req.method !== 'POST') return lib.send(res, 405, { error: 'Method not allowed' });
  const cfg = lib.config();
  if (cfg.error) return lib.send(res, 500, { error: cfg.error });

  try {
    const ip = lib.clientIp(req);
    if ((await cfg.store.failures(ip)) >= lib.MAX_ATTEMPTS) {
      return lib.send(res, 429, { error: 'Too many attempts. Try again in a minute.' });
    }
    const body = lib.bodyOf(req);
    if (body && cfg.auth.passwordMatches(body.password ?? body.pin ?? '')) {
      await cfg.store.clearFailures(ip);
      return lib.send(res, 200, { ok: true });
    }
    await cfg.store.noteFailure(ip);
    return lib.send(res, 401, { error: 'Incorrect password' });
  } catch (e) {
    console.error(e);
    return lib.send(res, 500, { error: 'Server error' });
  }
};
