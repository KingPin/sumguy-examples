# Adversarial test review prompt

Use this in a **fresh session** with a clean context, never in the session that
wrote the test. An agent grading its own test will approve it, because it is
checking the work against the same assumptions that produced it.

Paste the function and the test in place of the placeholders.

---

```text
Here is a function and a test that claims to cover it. Review this adversarially.

Answer these four questions separately and concretely:

1. Does the test actually verify the function's stated behaviour, or does it just
   assert that the code does whatever it currently does?
2. Would this test still pass if I introduced a bug in the core logic? Name a
   specific one-line change to the function that the test would NOT catch.
3. List at least one input this test does not cover: an edge case, an empty or
   zero value, a boundary, or an error path.
4. Is the test asserting on an implementation detail that would break during a
   harmless refactor? If so, which line.

Do not suggest rewrites yet. Do not tell me the test looks good unless you have
worked through all four questions and found nothing.

Function:
<paste function>

Test:
<paste test>
```

---

## Why the questions are split out

A single "review this test" prompt gets you a paragraph of praise. Asking for a
specific undetectable bug (question 2) forces the model to actually simulate a
failure, and that is where it either finds a real gap or demonstrates that the
test is sound. The instruction not to suggest rewrites keeps the response short
enough to read, and keeps a half-baked rewrite out of your context.
