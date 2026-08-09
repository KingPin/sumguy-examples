#!/usr/bin/env python3
"""Structure a prompt so Anthropic's cache actually hits.

The rule: everything that never changes goes first and gets a cache breakpoint.
Everything that changes per call goes after it. Interleave a timestamp or a
request ID into the static block and you invalidate the cache on every call.

Usage:
    export ANTHROPIC_API_KEY=sk-ant-...
    python3 cacheable_prompt.py path/to/change.diff
"""

import pathlib
import sys

import anthropic

client = anthropic.Anthropic()

MODEL = "claude-sonnet-5"

# This block never changes between calls. System role, house style guide, and
# any few-shot examples belong here, ahead of the cache breakpoint.
SYSTEM_PROMPT = """You are a code reviewer. Follow these rules:
1. Flag only correctness bugs and security issues.
2. Never restate code that did not change.
3. One bullet per finding, file and line number first.
"""

STYLE_GUIDE_PATH = pathlib.Path(__file__).with_name("STYLE_GUIDE.md")
STYLE_GUIDE = STYLE_GUIDE_PATH.read_text()


def review_diff(diff_text):
    """One API call. Only `diff_text` differs between invocations."""
    return client.messages.create(
        model=MODEL,
        max_tokens=512,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT + STYLE_GUIDE,
                # Everything up to this marker is cached. Default TTL is
                # 5 minutes; pass {"type": "ephemeral", "ttl": "1h"} for the
                # extended cache if your calls are spread further apart.
                "cache_control": {"type": "ephemeral"},
            }
        ],
        # The diff changes call to call, so it lives after the breakpoint.
        messages=[{"role": "user", "content": f"Review this diff:\n\n{diff_text}"}],
    )


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <diff-file>")

    resp = review_diff(pathlib.Path(sys.argv[1]).read_text())

    print(resp.content[0].text)

    # The cache is only doing its job if these move the way you expect: a big
    # creation number on the first call, a big read number on every one after.
    u = resp.usage
    print(
        "\n--- usage ---\n"
        f"input (uncached):   {u.input_tokens}\n"
        f"cache creation:     {getattr(u, 'cache_creation_input_tokens', 0)}\n"
        f"cache read:         {getattr(u, 'cache_read_input_tokens', 0)}\n"
        f"output:             {u.output_tokens}",
    )


if __name__ == "__main__":
    main()
