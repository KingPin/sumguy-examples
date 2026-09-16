# coding-agent-cant-draw

Companion files for the **Your Coding Agent Can't Draw** article on
[sumguy.com](https://sumguy.com/coding-agent-cant-draw/).

A worked `assets.yml` plus the CI job that enforces it. The idea: declare the
images a project needs once, let the agent fill them in, and let CI fail the
build when a declared image goes missing or drifts from its prompt.

---

## Prerequisites

Tested on 2026-09-16 with:

| Component | Version |
|---|---|
| `subpixel` | 0.3.0 |
| Node.js | 24.x (24 or newer is required) |
| `@openai/codex` | current, used once for `codex login` |
| `sharp` | optional, only for `--exact-size`, `--transparent`, `--variants`, `spx icons` |

Authentication comes from the Codex CLI, not from an image API key:

```bash
npm install -g @openai/codex
codex login
```

`subpixel` reads the `auth.json` that login writes, at `$CODEX_HOME/auth.json` if
that variable is set and `~/.codex/auth.json` otherwise.

> **Terms of service.** `subpixel` drives the undocumented
> `chatgpt.com/backend-api/codex` endpoint using your personal ChatGPT
> subscription. Do not use it to power a public facing service: no web
> endpoints, no bots, no serving generated images to third parties. The endpoint
> is undocumented and can change or stop working without notice.

---

## Files

### `assets.yml`

Three declared images: a hero banner, a social card, and an empty state
illustration. Each entry names an `id`, a `prompt`, an output path, and a size.

```bash
npm install -g subpixel

spx doctor          # check credentials, driver model, optional deps. Exit 1 = not logged in
spx sync            # generate whatever is missing or out of date
spx sync --check    # report drift, exit 6, make no network calls
```

Run `spx sync` from this directory. Generated files land in `public/`.

A generation takes about 30 seconds on the HTTP backend and up to 6 minutes on
the `codex-exec` backend. If a run looks stuck, check `public/` before starting
another one. Results are cached by content, so repeating an identical prompt
returns the same file rather than spending a second generation, but a *changed*
prompt is a new image and a new charge.

### `.github/workflows/assets-check.yml`

Runs `spx sync --check` on every pull request. The `--check` form calls nothing
and spends nothing, so the job needs no secrets. It exits 6 when a declared
image is missing or out of date, which fails the build.

**Commit your generated images first.** `--check` compares what is on disk
against `assets.yml`. A checkout with an empty `public/` counts as drift, so the
job exits 6 on every run until the images and their `.json` manifests are in the
repository. This example does not ship the generated binaries, so the order is:
run `spx sync`, commit `public/`, then enable the workflow.

This is the part worth stealing even if you never generate a single image with
`subpixel`: a repository that declares its own visual assets can tell you when
one goes stale, the same way a lockfile tells you when a dependency does.

---

## Notes

- `--size` and `--quality` are best effort on the subscription backend. When a
  dimension is a hard requirement, use `--exact-size WxH`, which crops and
  resizes locally and needs `sharp`.
- Every generated image gets a manifest beside it. `public/hero.png` is written
  with a `public/hero.png.json` recording the prompt, the model, and the
  settings. `spx regen public/hero.png` rebuilds from that manifest.
- `public/` is intentionally not committed in this example repo, because the
  generated images are binaries specific to one run. In a real project you do
  commit them, which is what makes the CI check above meaningful.

## Links

- Article: <https://sumguy.com/coding-agent-cant-draw/>
- `subpixel` on npm: <https://www.npmjs.com/package/subpixel>
- `subpixel` source: <https://github.com/KingPin/SubPixel>
