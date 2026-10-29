# coredumpctl: debugging a crash-looping service

Companion files for [coredumpctl: Debug a Crash-Looping Service](https://sumguy.com/coredumpctl-crash-loop/).
It builds a small C program that segfaults two seconds after start, runs it as a user unit that restarts itself, and shows how to pull the crash out with `coredumpctl` and gdb.

## Files

| File | What it is |
|---|---|
| `crashy.c` | Segfaults on purpose: `main()` calls `load_settings()`, which passes a NULL pointer to `parse_config()` |
| `crashy.service` | A user unit with `Restart=on-failure`, `RestartSec=3`, `StartLimitBurst=3`, and `LimitCORE=infinity` |
| `coredump.conf.d/50-homelab.conf` | Example drop-in for `/etc/systemd/coredump.conf.d/` (storage, size caps, `MaxUse=`, `KeepFree=`) |
| `test.sh` | Builds the program, links the unit from a temp dir, waits for the crash, prints `coredumpctl list` and a batch gdb backtrace, then cleans up |

## Prerequisites

- systemd with `systemd-coredump` set as the kernel `core_pattern` handler (check with `cat /proc/sys/kernel/core_pattern`)
- `gcc` and `gdb`
- A normal user account with a running user manager. No sudo needed.
- Listing your own cores works without privileges. If `COREFILE` shows `inaccessible`, run `coredumpctl` as root or add your user to the `systemd-journal` group.

Tested on systemd 262 (Arch Linux), gcc, and gdb with debuginfod URLs configured.

## Run it safely

```bash
./test.sh
```

The script compiles into `mktemp -d`, links a throwaway `crashy-demo.service` into your user manager, and removes it at the end. The crash itself stays in the journal and in `/var/lib/systemd/coredump/` until normal retention removes it.

## Installing the coredump drop-in for real

1. `sudo cp coredump.conf.d/50-homelab.conf /etc/systemd/coredump.conf.d/`
2. `sudo systemctl reload systemd-coredumpd.service`
3. Check the merged result: `systemd-analyze cat-config systemd/coredump.conf`
