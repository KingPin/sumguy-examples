// The Part 5 app: an Express 5 app with an admin panel that trusts the proxy to guard it.
//   /admin, /admin/*  the admin panel, mounted with app.use like most Express admin routers.
//                     It has no login of its own: it expects the proxy to let only admins in.
//   GET /whoami       the identity the app believes, read from the Remote-User header
//                     (header auth, the way Grafana auth.proxy or Paperless-ngx can be set up)
//   GET /             hello
//   POST /login, GET /api/items  so the Part 4 rate-limit routes still have something to hit
//   GET /boom         500 with a traceback, for ../audit.sh
// Express defaults stay on: case-insensitive routing, non-strict trailing slash, X-Powered-By.
const express = require("express");
const app = express();

const seen = (req) => ({
  path: req.originalUrl,            // the request target exactly as the proxy forwarded it
  host: req.get("host") || null,
  remote_user: req.get("remote-user") || null,
});

app.use("/admin", (req, res) => res.json({ admin_panel: true, ...seen(req) }));
app.get("/whoami", (req, res) => res.json(seen(req)));
app.get("/", (req, res) => res.json({ page: "hello" }));
app.post("/login", (req, res) => res.status(401).json({ error: "bad password" }));
app.get("/api/items", (req, res) => res.json({ items: [1, 2, 3] }));
app.get("/boom", (req, res) => res.status(500).type("text/plain").send("Traceback (most recent call last):\nKeyError: 'user'\n"));
app.use((req, res) => res.status(404).json({ error: "not found", ...seen(req) }));

app.listen(8080, "0.0.0.0");
