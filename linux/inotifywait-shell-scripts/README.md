# inotifywait: Shell Scripts That React to File Changes

Companion files for the post [inotifywait: Scripts That React to Files](https://sumguy.com/inotifywait-shell-scripts/).

## What is in here

| File | What it does |
| --- | --- |
| `watch-inbox.sh` | Watch-folder processor. Reacts to `close_write` and `moved_to`, handles spaces and newlines in names, sweeps files that were already waiting. |
| `debounce.sh` | Runs a command once after a burst of changes goes quiet. |
| `rebuild.sh` | Stand-in for "the thing you want to rerun". |
| `gotchas.sh` | Reproduces each gotcha from the post (half-written files, rename saves, exit codes, `%T`, `--exclude`, NUL output). |
| `entr-demo.sh` | `entr` basics: rerun, `-r` restart, `-d` exit on new file, the loop fix. |
| `run-tests.sh` | Runs everything above and prints the package versions. |
| `Dockerfile`, `compose.yaml` | Throwaway Debian container with both tools installed. |

## Prerequisites and tested versions

- Docker (any recent version). Nothing is installed on the host.
- Tested on `debian:trixie-slim` with `inotify-tools` 4.23.9.0-2+b1 and `entr` 5.7-1 (Debian packages), on a Linux 7.3 host kernel. The container read `fs.inotify.max_user_watches` as 524288.
- As of 2026-11-08 upstream shows inotify-tools 4.26.272 and entr 5.9. The scripts only use flags that exist in the tested versions.

## How to run

```bash
# run every demo once
docker compose run --rm kit

# or get a shell and play
docker build -t inw-kit .
docker run --rm -it inw-kit
```

Inside the shell, try `INBOX=/tmp/in DONE=/tmp/done ./watch-inbox.sh &` and then drop files into `/tmp/in` from a second shell (`docker exec -it <container> bash`).

The demos use `sleep` for timing, so a slow machine can reorder output. Re-run if a section looks empty.

Everything here uses temporary directories inside the container. Nothing touches your files.
