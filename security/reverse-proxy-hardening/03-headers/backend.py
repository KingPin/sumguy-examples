"""The Part 3 app: one route per kind of response a proxy has to put headers on.

GET /             JSON echo of the request headers, no security headers of its own (most apps)
GET /app          HTML page that sets its own framing, CSP, and Referrer-Policy headers, like apps that ship their own security headers
GET /legacy       HTML page that sets only X-Frame-Options: SAMEORIGIN (older apps)
GET /embed/<page> HTML page that frames /<page> from the same origin, like an app embedding its own views
GET /static/a.css a stylesheet (the proxy config gives this path its own Cache-Control)
GET /boom         500, which the proxy replaces with its own error page
anything else     404 from the app
Every response carries X-Powered-By, like Part 1's backend.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer

APP_HEADERS = {
    "X-Frame-Options": "SAMEORIGIN",
    "Content-Security-Policy": "frame-ancestors 'self'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        extra = {}
        if self.path == "/":
            code, ctype = 200, "application/json"
            body = '{"page": "kitmark-root"}'  # browser.py looks for the kitmark-* strings
        elif self.path == "/app":
            code, ctype = 200, "text/html"
            body = "<!doctype html><title>app</title><p>kitmark-app</p>"
            extra = APP_HEADERS
        elif self.path == "/legacy":
            code, ctype = 200, "text/html"
            body = "<!doctype html><title>legacy</title><p>kitmark-legacy</p>"
            extra = {"X-Frame-Options": "SAMEORIGIN"}
        elif self.path.startswith("/embed/"):
            code, ctype = 200, "text/html"
            body = f'<!doctype html><title>embed</title><iframe src="/{self.path[7:]}"></iframe>'
        elif self.path == "/static/a.css":
            code, ctype = 200, "text/css"
            body = "p { color: teal; }"
        elif self.path == "/boom":
            code, ctype = 500, "text/plain"
            body = "Traceback (most recent call last):\nKeyError: 'user'\n"
        else:
            code, ctype = 404, "text/plain"
            body = "not found\n"
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Powered-By", "Express")
        for k, v in extra.items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
