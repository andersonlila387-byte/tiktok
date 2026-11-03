// GET    /api/analytics   the figures everyone sees (404 until first saved)
// PUT    /api/analytics   admin: replace the figures  {data}
// DELETE /api/analytics   admin: reset to the app's defaults
const lib = require('./_lib');

module.exports = async (req, res) => {
  if (lib.preflight(req, res)) return;
  const cfg = lib.config();
  if (cfg.error) return lib.send(res, 500, { error: cfg.error });

  try {
    if (req.method === 'GET') {
      const current = await cfg.store.get();
      if (!current) return lib.send(res, 404, { error: 'No data saved yet' });
      const tag = `"${current.updatedAt}"`;
      if (req.headers['if-none-match'] === tag) return lib.send(res, 304, '', { ETag: tag });
      return lib.send(res, 200, current, { ETag: tag });
    }

    if (req.method !== 'PUT' && req.method !== 'DELETE') {
      return lib.send(res, 405, { error: 'Method not allowed' });
    }
    if (!cfg.auth.authorised(req.headers.authorization)) {
      return lib.send(res, 401, { error: 'Admin sign-in required' });
    }

    if (req.method === 'DELETE') {
      await cfg.store.del();
      return lib.send(res, 200, { ok: true });
    }

    const body = lib.bodyOf(req);
    const problem = lib.validate(body && body.data);
    if (problem) return lib.send(res, 400, { error: `Invalid data: ${problem}` });
    const previous = await cfg.store.get();
    const updatedAt = Math.max(Date.now(), previous ? previous.updatedAt + 1 : 0);
    await cfg.store.set({ updatedAt, data: body.data });
    return lib.send(res, 200, { updatedAt }, { ETag: `"${updatedAt}"` });
  } catch (e) {
    console.error(e);
    return lib.send(res, 500, { error: 'Server error' });
  }
};
