"""A small app that leaks like a real one.

GET /      echoes the request headers it received, as JSON, so you can see what the proxy forwarded.
GET /boom  returns a 500 with a stack trace in the body, the way a debug-mode app does.
Every response carries X-Powered-By and Python's default Server header.
"""
import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/boom":
            code, ctype = 500, "text/plain"
            body = (
                "Traceback (most recent call last):\n"
                '  File "/srv/app/views.py", line 42, in index\n'
                "    user = session['user']\n"
                "KeyError: 'user'\n"
            ).encode()
        else:
            code, ctype = 200, "application/json"
            body = json.dumps(dict(self.headers), indent=1).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Powered-By", "Express")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


# While /tmp/down exists the app closes its port, like a crashed process in a live container.
# The container keeps its IP and DNS name, so the proxy sees a clean "connection refused".
srv = None
while True:
    if os.path.exists("/tmp/down"):
        if srv:
            srv.server_close()
            srv = None
        time.sleep(0.2)
        continue
    if not srv:
        srv = HTTPServer(("0.0.0.0", 8080), Handler)
        srv.timeout = 0.2
    srv.handle_request()
