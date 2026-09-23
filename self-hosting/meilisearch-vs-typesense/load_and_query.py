#!/usr/bin/env python3
"""Index movies.json into both Meilisearch and Typesense, then run the same
typo'd query against each and print what comes back.

Stdlib only. No dependencies to install.

Usage:
    python3 load_and_query.py
"""
import json
import time
import urllib.request
import urllib.error
import urllib.parse

MEILI_URL = "http://localhost:7700"
MEILI_KEY = "change-me-master-key"

TYPESENSE_URL = "http://localhost:8108"
TYPESENSE_KEY = "change-me-typesense-key"

TYPO_QUERY = "Forklyft Dreems"  # typo'd version of "Forklift Dreams"


def request(method, url, headers=None, body=None, expect_json=True):
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as e:
        raw = e.read()
        if not (method == "DELETE" and e.code == 404):
            print(f"  ! HTTP {e.code} on {method} {url}: {raw[:300]}")
        return None
    if not raw or not expect_json:
        return raw
    return json.loads(raw)


def load_movies():
    with open("movies.json") as f:
        return json.load(f)


def setup_meilisearch(movies):
    print("== Meilisearch ==")
    headers = {
        "Authorization": f"Bearer {MEILI_KEY}",
        "Content-Type": "application/json",
    }
    # Meilisearch creates the index on first document write if it doesn't exist.
    task = request("POST", f"{MEILI_URL}/indexes/movies/documents?primaryKey=id",
                    headers=headers, body=movies)
    task_uid = task["taskUid"]
    # Poll until indexing finishes.
    for _ in range(60):
        status = request("GET", f"{MEILI_URL}/tasks/{task_uid}", headers=headers)
        if status["status"] in ("succeeded", "failed"):
            print(f"  indexing task {task_uid}: {status['status']}")
            break
        time.sleep(0.5)


def setup_typesense(movies):
    print("== Typesense ==")
    headers = {"X-TYPESENSE-API-KEY": TYPESENSE_KEY, "Content-Type": "application/json"}

    # Explicit schema required. Typesense has no schemaless mode by default.
    schema = {
        "name": "movies",
        "fields": [
            {"name": "title", "type": "string"},
            {"name": "director", "type": "string", "facet": True},
            {"name": "year", "type": "int32"},
            {"name": "genre", "type": "string", "facet": True},
            {"name": "rating", "type": "float"},
        ],
    }
    # Drop any collection left over from a previous run, then recreate.
    request("DELETE", f"{TYPESENSE_URL}/collections/movies", headers=headers)
    request("POST", f"{TYPESENSE_URL}/collections", headers=headers, body=schema)

    # Typesense wants a string "id" field if you supply your own id.
    jsonl_lines = []
    for movie in movies:
        doc = dict(movie)
        doc["id"] = str(doc["id"])
        jsonl_lines.append(json.dumps(doc))
    body = ("\n".join(jsonl_lines)).encode()

    import_headers = dict(headers)
    import_headers["Content-Type"] = "text/plain"
    result = request(
        "POST",
        f"{TYPESENSE_URL}/collections/movies/documents/import?action=upsert",
        headers=import_headers, body=body, expect_json=False,
    )
    lines = result.decode().strip().splitlines()
    failures = [l for l in lines if '"success":true' not in l]
    print(f"  imported {len(lines) - len(failures)}/{len(lines)} documents")


def query_meilisearch(q):
    headers = {
        "Authorization": f"Bearer {MEILI_KEY}",
        "Content-Type": "application/json",
    }
    result = request("POST", f"{MEILI_URL}/indexes/movies/search",
                      headers=headers, body={"q": q, "limit": 3})
    print(f"\n[Meilisearch] query={q!r} processingTimeMs={result.get('processingTimeMs')}")
    for hit in result.get("hits", []):
        print(f"  - {hit['title']} ({hit['year']}, {hit['genre']})")


def query_typesense(q):
    headers = {"X-TYPESENSE-API-KEY": TYPESENSE_KEY}
    params = f"q={urllib.parse.quote(q)}&query_by=title&per_page=3"
    result = request("GET", f"{TYPESENSE_URL}/collections/movies/documents/search?{params}",
                      headers=headers)
    print(f"\n[Typesense] query={q!r} search_time_ms={result.get('search_time_ms')}")
    for hit in result.get("hits", []):
        doc = hit["document"]
        print(f"  - {doc['title']} ({doc['year']}, {doc['genre']})")


if __name__ == "__main__":
    movies = load_movies()
    setup_meilisearch(movies)
    setup_typesense(movies)

    print("\n--- Same typo'd query against both engines ---")
    query_meilisearch(TYPO_QUERY)
    query_typesense(TYPO_QUERY)
