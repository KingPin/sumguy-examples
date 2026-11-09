# systemd path units: run a job when a file appears

Companion files for [systemd Path Units: React to New Files](https://sumguy.com/systemd-path-units/).
It is a drop-folder processor: a `.path` unit watches a directory, and a oneshot `.service` moves every file out of it.

## Files

| File | What it is |
|---|---|
| `inbox.path` | Path unit using `DirectoryNotEmpty=` with `MakeDirectory=` and `DirectoryMode=` |
| `inbox.service` | The oneshot service the path unit activates (same name, so no `Unit=` needed) |
| `process-inbox.sh` | Loops over every regular file in the inbox and moves each one to a done directory |
| `test.sh` | Installs `sgtest-` user units pointed at a temp dir, drops files, forces the retrigger loop, recovers, cleans up |

## Prerequisites

- systemd with user units (`TRIGGER_UNIT` needs 252, `TriggerLimitIntervalSec=` needs 250)
- bash, `find`, `journalctl`
- A normal user account. No sudo needed.

Tested on systemd 262, November 2026.

## Run it safely

```bash
./test.sh
```

The script copies the units to `~/.config/systemd/user/` as `sgtest-inbox.*`, with `%h` paths replaced by a `mktemp -d` directory. It checks that:

1. A burst of 3 files is fully processed.
2. The service sees `TRIGGER_UNIT`.
3. A dotfile is ignored and a rename into place is processed.
4. A subdirectory in the inbox (never moved out) makes the path unit fail with `unit-start-limit-hit`.
5. `reset-failed` plus `start` recovers it.

A trap stops and deletes every `sgtest-inbox.*` unit and the temp dir on exit.

## Installing for real

1. `mkdir -p ~/.config/systemd/user ~/.local/bin`
2. `cp inbox.path inbox.service ~/.config/systemd/user/` and `cp process-inbox.sh ~/.local/bin/`
3. `systemctl --user daemon-reload && systemctl --user enable --now inbox.path`
4. Drop files into `~/inbox`. Output goes to `~/processed`. Logs: `journalctl --user -t process-inbox` (the identifier set in `inbox.service`).

User units run only while you are logged in unless you run `loginctl enable-linger`.
