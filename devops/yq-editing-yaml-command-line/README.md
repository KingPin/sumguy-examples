# yq: Editing YAML From the Command Line

Sample files and a runnable demo for the post
[yq: Editing YAML From the Command Line](https://sumguy.com/yq-editing-yaml-command-line/).

The demo uses mikefarah/yq (the Go binary), not the Python `yq` from kislyuk.

## What is in here

| File | Used for |
| --- | --- |
| `samples/compose.yml` | Reading values, bumping image tags, adding env vars, anchors |
| `samples/k8s.yml` | Multi-document manifest: `select(.kind == ...)`, `document_index` |
| `samples/base.yml`, `samples/override.yml` | Merging with `eval-all` and `*` / `*+` |
| `samples/comments.yml` | What happens to comments and blank lines |
| `samples/anchors.yml` | Anchors, merge keys, `explode` |
| `samples/post.md` | Markdown with YAML front matter |
| `demo.sh` | Runs the main commands from the post against a scratch copy |

## Prerequisites

- Docker. Nothing else. The script pulls `mikefarah/yq:4.54.2`.
- Tested with mikefarah/yq 4.54.2 and Docker on Linux.

## Run it

```bash
./demo.sh
```

The script copies `samples/` to a temp directory, runs every step there with
`docker run --user "$(id -u):$(id -g)"`, and deletes the copy on exit. The files in
`samples/` are never modified.

## Notes

- Environment variables only reach yq inside the container when you pass them with
  `-e NAME`. The script does this for `NEWTAG` and `PORT`.
- `compose.yml` uses a merge key (`<<: *defaults`), so yq 4.54.2 prints a deprecation
  warning on stderr about `--yaml-fix-merge-anchor-to-spec`. The script hides it with
  `2>/dev/null`.
