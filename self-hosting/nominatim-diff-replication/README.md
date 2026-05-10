# nominatim-diff-replication

Keep a self-hosted Nominatim instance up to date with OSM diff files using the built-in `nominatim replication` subcommand and a systemd timer. No cron, no silent failures.

## Prerequisites

- Docker 27.x + Compose v2
- systemd (for the timer units)
- A working Nominatim container (initial import already complete)

## Run it

### 1. Start the stack (initial import)

```bash
cp .env.example .env   # edit NOMINATIM_PASSWORD
docker compose up -d
docker compose logs -f nominatim
```

First start downloads the PBF and runs the full import — budget several hours depending on extract size.

### 2. Initialise replication state

Run once after the import completes:

```bash
docker exec nominatim sudo -u nominatim nominatim replication --init
```

### 3. Test a one-shot update

```bash
docker exec nominatim sudo -u nominatim nominatim replication --once
```

### 4. Install the systemd timer

```bash
sudo cp scripts/nominatim-replication.service /etc/systemd/system/
sudo cp scripts/nominatim-replication.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nominatim-replication.timer

# Verify timer is scheduled
systemctl list-timers nominatim-replication.timer
```

### 5. Check replication lag

```bash
chmod +x scripts/check-replication-lag.sh
./scripts/check-replication-lag.sh
# Override defaults:
# NOMINATIM_HOST=http://nominatim.lan:8080 MAX_LAG_SECONDS=86400 ./scripts/check-replication-lag.sh
```

## Notes

- `RandomizedDelaySec=900` staggers startup by up to 15 min — avoids hammering Geofabrik at exactly 3 AM UTC with every other self-hosters.
- `Persistent=true` catches up on missed runs after a reboot.
- The `OnFailure=` directive in the service unit needs a `nominatim-replication-failure@.service` unit to send notifications — stub yours in with `ExecStart=/usr/bin/systemd-cat echo "Nominatim replication FAILED"` or wire it to a proper alerting service.
- For minutely updates, change `REPLICATION_URL` in the Compose file to `https://planet.openstreetmap.org/replication/minute/` and adjust the timer cadence. Hourly diffs are the sweet spot for most home labs.

[Read the article](https://sumguy.com/posts/nominatim-diff-replication/)
