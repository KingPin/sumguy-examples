"""Tiny OpenAI-style /v1/embeddings server for testing the LiteLLM cache without an API key.
Hashed bag of words, 64 dims. Not a real embedding model: it only proves the wiring."""
import hashlib, json, math, re
from http.server import BaseHTTPRequestHandler, HTTPServer

DIM = 64


def embed(text):
    v = [0.0] * DIM
    for w in re.findall(r"[a-z0-9]+", text.lower()):
        v[int(hashlib.md5(w.encode()).hexdigest(), 16) % DIM] += 1.0
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]


class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        inp = body["input"] if isinstance(body["input"], list) else [body["input"]]
        out = {"object": "list", "model": body.get("model", "stub"),
               "data": [{"object": "embedding", "index": i, "embedding": embed(t)} for i, t in enumerate(inp)],
               "usage": {"prompt_tokens": 0, "total_tokens": 0}}
        data = json.dumps(out).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


HTTPServer(("0.0.0.0", 8081), H).serve_forever()
