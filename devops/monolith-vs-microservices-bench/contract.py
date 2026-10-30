#!/usr/bin/env python3
"""Contract check: send each case in order, compare status and JSON body (order_id ignored).
Usage: contract.py BASE_URL expected/contract.json [--record]
--record fills in status and response from the live app and rewrites the file."""
import json
import sys
import urllib.error
import urllib.request


def send(base, c):
    data = c["raw"].encode() if "raw" in c else json.dumps(c["body"]).encode() if "body" in c else None
    req = urllib.request.Request(base + c["path"], data=data, method=c["method"],
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            code, body = r.status, json.load(r)
    except urllib.error.HTTPError as e:
        code, body = e.code, json.load(e)
    if isinstance(body, dict):
        body.pop("order_id", None)
    return code, body


def main():
    base, path = sys.argv[1], sys.argv[2]
    record = "--record" in sys.argv[3:]
    cases = json.load(open(path))
    bad = 0
    for c in cases:
        code, body = send(base, c)
        if record:
            c["status"], c["response"] = code, body
        elif (code, body) != (c["status"], c["response"]):
            bad += 1
            print(f"MISMATCH {c['method']} {c['path']}: got {code} {body}, want {c['status']} {c['response']}")
    if record:
        json.dump(cases, open(path, "w"), indent=1)
        print(f"recorded {len(cases)} cases into {path}")
    else:
        print(f"contract: {len(cases) - bad}/{len(cases)} ok")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
