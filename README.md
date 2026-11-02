# Analytics dashboard

A TikTok-style analytics dashboard (Inspiration, Overview, Content, Viewers,
Followers, LIVE) whose figures are edited from an admin screen. Edits are saved
on a server, so every visitor sees them and they survive refreshes.

```
pulse_analytics/   Flutter web app (the dashboard and the admin screen)
server/            Node server: stores the figures, checks the admin PIN,
                   and serves the built web app. No npm dependencies.
```

## Run it

```bash
cd pulse_analytics
flutter pub get
flutter build web --release

cd ../server
ADMIN_PIN=choose-a-pin node server.js     # http://localhost:8080
```

Without `ADMIN_PIN` the PIN is `1234`; set your own before going live.

## Host on Vercel

1. Import this GitHub repo at vercel.com/new (leave every build setting empty; the
   app is prebuilt in `public/` and the API is in `api/`).
2. In the project: **Storage > Create > Upstash Redis** (free), connect it to the
   project.
3. **Settings > Environment Variables**: add `ADMIN_PIN` (your admin password)
   and `TOKEN_SECRET` (a long random string, e.g. `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`).
4. **Deployments > Redeploy** so the variables take effect.

After changing the app, run `bash scripts/build-web.sh`, commit `public/`, and
push; Vercel redeploys automatically.

## Troubleshooting: "Could not reach the server"

The admin PIN is checked by the server, so the server must be running
(`node server/server.js`). Open the dashboard at `http://localhost:8080`. If you
start the app with `flutter run`, it looks for the server at
`http://localhost:8080`; use `--dart-define=API_URL=...` to point elsewhere.

## Admin access

Long-press the **Analytics** title at the top of the dashboard and enter the
PIN. Changes save to the server and appear for all visitors within about ten
seconds (or on the next refresh).

## Server settings (environment variables)

| Variable       | Default                           | Purpose                                   |
| -------------- | --------------------------------- | ----------------------------------------- |
| `ADMIN_PIN`    | `1234`                            | Admin password                            |
| `PORT`         | `8080`                            | Port to listen on                         |
| `DATA_FILE`    | `server/data/analytics.json`      | Where figures are stored (back this up)   |
| `WEB_DIR`      | `pulse_analytics/build/web`       | Built web app to serve                    |
| `TOKEN_SECRET` | random each start                 | Signs admin sessions                      |

If the web app is hosted separately from the server, build it with
`flutter build web --dart-define=API_URL=https://your-server` and allow that
origin on the server (it currently serves same-origin only).

## Tests

```bash
cd pulse_analytics && flutter test
cd server && npm test
```
