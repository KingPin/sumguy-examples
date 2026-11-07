"""A stand-in forward-auth server, shaped like Authelia's verify endpoint.

GET /verify   200 with "Remote-User: alice" when the request carries the cookie session=alice-ok,
              otherwise 401. The proxy calls this before it lets a request through to /admin.
GET /verify on a path under /admin/health returns 200 with no Remote-User, the way an Authelia
              "bypass" rule answers for a health check. The proxy sends the original path in
              X-Forwarded-Uri (Caddy, Traefik) or X-Original-URI (nginx, set in its config).
It is a stub for testing how the proxies copy headers. It is not an auth server.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        uri = self.headers.get("X-Forwarded-Uri") or self.headers.get("X-Original-URI") or ""
        self.send_response(self.decide(uri))
        if self.user:
            self.send_header("Remote-User", self.user)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def decide(self, uri):
        self.user = None
        if uri.lower().startswith("/admin/health"):
            return 200
        if "session=alice-ok" in (self.headers.get("Cookie") or ""):
            self.user = "alice"
            return 200
        return 401

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("0.0.0.0", 9091), Handler).serve_forever()
