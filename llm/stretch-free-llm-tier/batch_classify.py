#!/usr/bin/env python3
"""Classify many short strings in one call instead of one call per string.

Ten separate calls pay the fixed overhead ten times: system prompt, round trip,
and one slot off your rate limit regardless of how small each question was.
One structured call pays it once.

Batching backfires in two places, both handled here:
  1. A single bad item can cost you the whole batch's output, so batches stay
     small and a failed batch retries item by item.
  2. Structured output is worthless if you trust it without parsing it, so the
     response is validated against the input before it is returned.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 batch_classify.py            # runs the built-in sample
    python3 batch_classify.py lines.txt  # one log line per file line
"""

import json
import pathlib
import sys

import anthropic

client = anthropic.Anthropic()

MODEL = "claude-sonnet-5"
CATEGORIES = ["network", "storage", "auth", "other"]

# Small enough that redoing a failed batch is cheap. Raising this past ~25 buys
# very little extra efficiency and makes each failure hurt more.
BATCH_SIZE = 10

SAMPLE = [
    "broken pipe error",
    "disk full warning",
    "auth token expired",
    "connection reset by peer",
    "no space left on device",
    "invalid signature on bearer token",
    "unexpected EOF from upstream",
    "quota exceeded for volume",
]


def _classify_batch(items):
    """One call for the whole batch. Raises ValueError if the reply is unusable."""
    prompt = (
        f"Classify each log line below into exactly one of: {', '.join(CATEGORIES)}.\n"
        'Return only a JSON array of {"line": "...", "category": "..."} objects,\n'
        "one per input line, in the same order. No prose, no code fence.\n\n"
        f"Lines:\n{json.dumps(items, indent=2)}\n"
    )

    resp = client.messages.create(
        model=MODEL,
        # Capped: the answer has a known shape, so the model cannot ramble into
        # your remaining quota even if a confused generation tries to.
        max_tokens=64 * len(items) + 128,
        messages=[{"role": "user", "content": prompt}],
    )

    raw = resp.content[0].text.strip()
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"reply was not JSON: {raw[:200]}") from exc

    # Validate against the input before trusting any of it. A dropped or
    # reordered item is the common failure mode, and it is silent otherwise.
    if not isinstance(parsed, list) or len(parsed) != len(items):
        raise ValueError(f"expected {len(items)} objects, got {len(parsed)}")
    for item, obj in zip(items, parsed):
        if obj.get("line") != item:
            raise ValueError(f"line mismatch: sent {item!r}, got {obj.get('line')!r}")
        if obj.get("category") not in CATEGORIES:
            raise ValueError(f"unknown category {obj.get('category')!r} for {item!r}")

    return parsed


def classify(items):
    """Batch where it is cheap, fall back to per-item only where a batch failed."""
    results = []
    for start in range(0, len(items), BATCH_SIZE):
        batch = items[start : start + BATCH_SIZE]
        try:
            results.extend(_classify_batch(batch))
        except ValueError as exc:
            print(f"batch at offset {start} failed ({exc}); retrying individually",
                  file=sys.stderr)
            for item in batch:
                try:
                    results.extend(_classify_batch([item]))
                except ValueError:
                    results.append({"line": item, "category": None})
    return results


def main():
    if len(sys.argv) > 2:
        sys.exit(f"usage: {sys.argv[0]} [lines-file]")

    if len(sys.argv) == 2:
        items = [ln for ln in pathlib.Path(sys.argv[1]).read_text().splitlines() if ln.strip()]
    else:
        items = SAMPLE

    for row in classify(items):
        print(f"{str(row['category'] or 'FAILED'):<8} {row['line']}")


if __name__ == "__main__":
    main()
