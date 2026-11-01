# sudo vs doas vs run0: companion kit

Rules for the same job in three tools: let members of group `svc` run one command as root without a password, and refuse everything else.

Article: https://sumguy.com/sudo-vs-doas-vs-run0/

## What is in here

| File | Tool | Purpose |
| --- | --- | --- |
| `sudoers.d/50-svc` | sudo, sudo-rs | one-command NOPASSWD drop-in |
| `doas.conf` | OpenDoas | same rule in doas syntax |
| `50-run0-homelab.rules` | polkit (run0, systemctl) | passwordless `restart` of `nginx.service` for group `svc` |
| `Dockerfile` | | Debian trixie with sudo, doas, sudo-rs, polkitd, users `alice` (in `svc`) and `bob` |
| `test.sh` | | proves the sudo, sudo-rs and doas rules |

## Prerequisites and tested versions

Docker. Tested on Docker 29 with `debian:trixie`:

- sudo 1.9.16p2-3+deb13u2 (Debian's patched build; CVE-2025-32463 fix is backported in the deb13u packages)
- doas (OpenDoas) 6.8.2-1+b1
- sudo-rs 0.2.5-5+deb13u1
- polkitd 126-2 (installed only so the rules file has a home; never executed)

## Run it

```bash
docker build -t sdr-test .
docker run --rm sdr-test
```

Exit code is 0 when every check passes.

## Real output

```text
Sudo version 1.9.16p2
doas (OpenDoas) 6.8.2-1+b1
sudo-rs 0.2.5

PASS  visudo -c validates the drop-in
        /etc/sudoers: parsed OK
        /etc/sudoers.d/50-svc: parsed OK
        /etc/sudoers.d/README: parsed OK
PASS  doas -C validates doas.conf
PASS  doas -C rejects a broken config
        doas: syntax error at line 1
PASS  sudo: alice runs allowed cmd
        restarting web (demo stub) as uid 0
PASS  sudo: alice refused on other cmd
        sudo: a password is required
PASS  sudo: bob refused on allowed cmd
        sudo: a password is required
PASS  doas: alice runs allowed cmd
        restarting web (demo stub) as uid 0
PASS  doas: alice refused on other cmd
        doas: Operation not permitted
PASS  doas: bob refused on allowed cmd
        doas: Operation not permitted
PASS  sudo-rs: alice runs allowed cmd
        restarting web (demo stub) as uid 0
PASS  sudo-rs: alice refused on other cmd
        sudo-rs: I'm sorry alice. I'm afraid I can't do that

```

## What the container cannot test: run0

run0 asks PID 1 (systemd) over D-Bus to start a transient service unit, and asks polkitd to authorize it. A normal container has no systemd as PID 1 and no polkitd, so `run0` cannot run there. The polkit rules file is therefore not validated by this kit. Test it on a real systemd host:

```bash
sudo cp 50-run0-homelab.rules /etc/polkit-1/rules.d/
# as a member of svc, no password prompt expected:
systemctl restart nginx.service
```

The rule matches `unit` and `verb` details that systemctl sends. Based on reading the systemd and polkit docs, a transient unit started by run0 carries no such details, so this rule does not narrow what run0 can run. That claim was not tested.
