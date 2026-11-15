# NVMe temperature alert

Companion kit for [When Your NVMe Falls Off the PCIe Bus](https://sumguy.com/nvme-falls-off-pcie-bus/).

`nvme-temp-alert` sends a desktop notification when any NVMe drive's composite
temperature reaches a limit (70°C by default). `nvme-temp-alert.service` runs it as a
systemd user service inside your graphical session.

How it works:

- Reads temperatures straight from `/sys/class/hwmon`. No `lm_sensors` parsing.
- Finds NVMe sensors by their `name` file, not by `hwmonN` number, because the number
  can change between boots. A newly installed drive is picked up automatically.
- Sends a critical notification, repeats it every 5 minutes while the drive stays hot,
  and resets when the drive cools.
- Needs no root. Alerts also go to the user journal.

## Prerequisites

- Linux with the `nvme` hwmon driver (any modern kernel)
- Bash 4+ (associative arrays) and `notify-send` (libnotify)
- A desktop session that runs `graphical-session.target` (KDE Plasma and GNOME do)

Tested with Bash 5.3.20 and systemd 262 on KDE Plasma 6 (Wayland).

## Run it

```bash
install -m 755 nvme-temp-alert ~/.local/bin/nvme-temp-alert
install -m 644 nvme-temp-alert.service ~/.config/systemd/user/nvme-temp-alert.service
systemctl --user daemon-reload
systemctl --user enable --now nvme-temp-alert.service
```

One-shot test without the service. A limit of 1 forces an alert:

```bash
ONCE=1 LIMIT=1 ./nvme-temp-alert
```

## Settings

| Variable   | Default | Meaning                                  |
|------------|---------|------------------------------------------|
| `LIMIT`    | 70      | Alert threshold in °C                    |
| `INTERVAL` | 10      | Seconds between checks                   |
| `REPEAT`   | 300     | Seconds between repeat alerts while hot  |
| `ONCE`     | unset   | Check once and exit                      |

Change the limit for the service:

```bash
systemctl --user edit nvme-temp-alert
# add under [Service]:
# Environment=LIMIT=65
```

View alerts:

```bash
journalctl --user -u nvme-temp-alert
```
