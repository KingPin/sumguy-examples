# polkit rule vs sudoers: restart one service

Two ways to let group `oncall` run `systemctl restart demo-web.service` without a password and refuse everything else: a polkit JavaScript rule, and a sudoers `NOPASSWD` drop-in. A `test.sh` proves both, inside a Debian container with systemd as PID 1.

Article: https://sumguy.com/polkit-restart-one-service/

## What is in here

| File | Purpose |
| --- | --- |
| `50-oncall-restart.rules` | polkit rule: action id + unit + verb + group |
| `50-oncall-sudoers` | the same job as a sudoers.d drop-in |
| `00-log-verbs.rules` | debug rule that `polkit.log()`s the unit and verb of every manage-units check |
| `demo-web.service`, `demo-other.service` | two `sleep infinity` services |
| `Dockerfile` | Debian trixie with systemd, dbus, polkitd, sudo; users `alice` (in `oncall`) and `bob` |
| `test.sh` | runs inside the container, five phases |
| `output.txt` | captured output of the run below |

## Prerequisites and tested versions

Docker with permission to run a privileged container. Tested on Docker 29.9.2 with `debian:trixie`:

- polkitd 126-2 (`pkaction --version` reports 126)
- systemd 257.13-1~deb13u1
- sudo 1.9.16p2-3+deb13u2

The article author also checked the `pkaction` defaults on polkit 128 / systemd 262.1 (Arch).

## Run it

```bash
docker build -t polkit-restart-test .
docker run -d --name prt --privileged --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw polkit-restart-test
sleep 6
docker exec prt /test.sh
docker rm -f prt
```

Exit code is 0 when every check passes. Nothing touches the host: the rules are installed inside the container.

## What the phases check

1. No rule: `alice` is refused (`Interactive authentication required`).
2. Rule installed: `alice` restarts `demo-web`; `stop`, `restart demo-other` and `enable` are refused; `bob` is refused.
3. `pkcheck` run as root against `alice`'s process: `restart` returns 0, `stop` returns 2.
4. `polkit.log()` is silent under the stock `--no-debug` unit. A drop-in removes the flag and the verbs systemctl sends appear.
5. sudoers drop-in: `sudo -n systemctl restart demo-web.service` works for `alice` only, for that one command only.

## Real output

See `output.txt`.
