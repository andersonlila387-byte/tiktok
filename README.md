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
