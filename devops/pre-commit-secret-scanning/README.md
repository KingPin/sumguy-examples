# Pre-Commit Hooks That Catch Secrets

Working files for the post
[Pre-Commit Hooks That Catch Secrets](https://sumguy.com/pre-commit-secret-scanning/)
on SumGuy's Ramblings.

## What it does

Blocks a `git commit` that contains a credential, on your own machine, before
the commit object exists. Uses the [pre-commit](https://pre-commit.com)
framework with:

- [gitleaks](https://github.com/gitleaks/gitleaks): fast offline regex gate
  (the default pick)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog): live
  verification against vendor APIs, reports verified hits only
- a few basics from `pre-commit-hooks` (`detect-private-key`,
  `check-added-large-files`, `end-of-file-fixer`)

## Files

| File | Purpose |
|---|---|
| `.pre-commit-config.yaml` | hook pins for gitleaks v8.30.1, TruffleHog v3.99.0, pre-commit-hooks v6.0.0 |
| `.gitleaks.toml` | extends the built-in gitleaks rules and allowlists one marker string under `docs/` |
| `leak-test.sh` | makes a throwaway repo, stages a fake GitHub-shaped token, proves the hook blocks the commit |
| `renovate.json` | enables Renovate's `pre-commit` manager so the `rev:` pins stay current |

## Prerequisites

Tested 2026-10-07 with:

- pre-commit 4.6.2 (`pipx install pre-commit`)
- network access on first run: the `gitleaks` and `trufflehog` hook ids build
  from source with `go install`, and pre-commit bootstraps Go itself if none is
  installed. Expect the first run to take a few minutes. Use `gitleaks-system`
  or `gitleaks-docker` to skip the build.
- git

## How to run

```bash
# in your own repo
cp .pre-commit-config.yaml .gitleaks.toml /path/to/your/repo/
cd /path/to/your/repo
pre-commit install
pre-commit run --all-files

# prove the hook blocks a commit (uses a temp repo, leaves yours alone)
bash leak-test.sh
```

Expected output ends with `OK: the hook blocked the commit`. The token in
`leak-test.sh` is fake. It has the shape of a GitHub token and authenticates
nowhere, so TruffleHog under `--results=verified` will ignore it by design;
gitleaks is the hook that fails the commit.

## Notes

- Hooks only run where `pre-commit install` was run. Add the same scan to CI as
  a backstop.
- If a real secret ever reaches `git push`, rotate it. History rewrites do not
  un-leak anything that was already cloned.
