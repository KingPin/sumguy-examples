#!/usr/bin/env python3
"""Treat a 429 as Tuesday, not as a crisis.

Exponential backoff with jitter, honouring Retry-After when the provider sends
one. This is the single-script answer. Once you are juggling more than one
provider, put a router in front of them instead (see litellm-config.yaml) rather
than hand-rolling this per provider.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 retry_with_backoff.py "your prompt here"
"""

import random
import sys
import time

from anthropic import Anthropic, RateLimitError

client = Anthropic()


def call_with_backoff(**kwargs):
    max_retries = 5
    base_delay = 1.0
    for attempt in range(max_retries):
        try:
            return client.messages.create(**kwargs)
        except RateLimitError as exc:
            if attempt == max_retries - 1:
                raise
            # Honour a Retry-After header when the provider sends one. It lives
            # on the HTTP response, not on the exception object: there is no
            # `exc.retry_after` attribute, so a getattr() fallback here would
            # silently make this branch unreachable.
            retry_after = exc.response.headers.get("retry-after")
            delay = int(retry_after) if retry_after else base_delay * (2**attempt)
            # Jitter so a fleet of workers does not all retry in lockstep.
            delay += random.uniform(0, delay * 0.5)
            print(f"429; sleeping {delay:.1f}s (attempt {attempt + 1})", file=sys.stderr)
            time.sleep(delay)


def main():
    prompt = " ".join(sys.argv[1:]) or "Say hello in five words."
    resp = call_with_backoff(
        model="claude-sonnet-5",
        max_tokens=128,
        messages=[{"role": "user", "content": prompt}],
    )
    print(resp.content[0].text)


if __name__ == "__main__":
    main()
