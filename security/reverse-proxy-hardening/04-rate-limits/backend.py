"""The Part 4 app: a login form, an API, and a page that reports which client the app thinks it is talking to.

POST /login       always 401 (wrong password), like a brute-force target
GET  /api/items   small JSON list, the kind of call a page load fires a few dozen of
GET  /whoami      JSON with the X-Forwarded-For and X-Real-IP headers the app received
GET  /            JSON hello (unlimited in every config)
GET  /boom        500 with a traceback, so ../audit.sh can check the error page carry-over from Part 1
anything else     404 from the app
Every response carries X-Powered-By, like the earlier parts' backend.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, obj):
        data = (json.dumps(obj) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("X-Powered-By", "Express")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]  # probes add ?N so curl treats each request as its own URL
        if path == "/":
            self.reply(200, {"page": "hello"})
        elif path == "/api/items":
            self.reply(200, {"items": [1, 2, 3]})
        elif path == "/whoami":
            self.reply(200, {
                "x-forwarded-for": self.headers.get("X-Forwarded-For"),
                "x-real-ip": self.headers.get("X-Real-IP"),
                "socket-peer": self.client_address[0],
            })
        elif path == "/boom":
            data = b"Traceback (most recent call last):\nKeyError: 'user'\n"
            self.send_response(500)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("X-Powered-By", "Express")
            self.end_headers()
            self.wfile.write(data)
        else:
            self.reply(404, {"error": "not found"})

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length") or 0))
        if self.path.split("?")[0] == "/login":
            self.reply(401, {"error": "bad password"})
        else:
            self.reply(404, {"error": "not found"})

    def log_message(self, *args):
        pass


class Server(ThreadingHTTPServer):
    # Threaded: nginx's burst queue holds requests open, and one slow request must not stall the rest.
    # The stdlib default backlog of 5 drops SYNs under 20 parallel requests and adds a 1 s retransmit.
    request_queue_size = 128


Server(("0.0.0.0", 8080), Handler).serve_forever()
