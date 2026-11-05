"""What does a real browser do with the headers the proxy sends?

Usage: python3 browser.py HTTPS_PORT [HOSTNAME]
Needs Python Playwright (pip install playwright). Uses Playwright's Chromium, or the binary in $CHROMIUM.

Framing: can the app frame its own pages (same origin), and can a stranger's site frame them (cross origin)?
Referer: when a user clicks from /app to another site, what does that site learn?
"""
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

from playwright.sync_api import sync_playwright

port = sys.argv[1]
host = sys.argv[2] if len(sys.argv) > 2 else "app.example.test"
base = f"https://{host}:{port}"
seen = {}


class Stranger(BaseHTTPRequestHandler):
    """A stranger's site on loopback: a second origin in the same (local) address space.
    In our runs, a page served by Playwright's route() could not frame 127.0.0.1 at all, whatever the
    headers said (most likely Chromium's Local Network Access rules), so the stranger needs a real server."""

    def do_GET(self):
        body = f'<iframe src="{base}{self.path}"></iframe>'.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


srv = HTTPServer(("127.0.0.1", 0), Stranger)
threading.Thread(target=srv.serve_forever, daemon=True).start()
stranger = f"http://stranger.example.net:{srv.server_port}/"
referer_sink = "https://elsewhere.example.net/"  # Playwright answers this one; only its Referer matters


def capture_referer(route):
    seen["referer"] = route.request.headers.get("referer")
    route.fulfill(content_type="text/html", body="thanks")


def framed(page, marker):
    """True if a child frame rendered the page we asked for."""
    for f in page.frames[1:]:
        try:
            if marker in f.content():
                return True
        except Exception:
            pass
    return False


with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=os.environ.get("CHROMIUM") or None,
        args=[f"--host-resolver-rules=MAP {host} 127.0.0.1, MAP stranger.example.net 127.0.0.1"],
    )
    page = browser.new_context(ignore_https_errors=True).new_page()
    page.route(referer_sink + "**", capture_referer)

    for target in ("", "app", "legacy"):
        marker = "kitmark-" + (target or "root")
        page.goto(f"{base}/embed/{target}")
        page.wait_for_timeout(1500)
        same = "loaded" if framed(page, marker) else "blocked"
        page.goto(stranger + target)
        page.wait_for_timeout(1500)
        cross = "loaded" if framed(page, marker) else "blocked"
        print(f"frame /{target:<7} same-origin: {same:<8} cross-origin: {cross}")

    page.goto(f"{base}/app")
    with page.expect_navigation():
        page.evaluate(f"location.href = '{referer_sink}'")
    print(f"referer sent from /app to another site: {seen.get('referer') or '(none)'}")
    browser.close()
