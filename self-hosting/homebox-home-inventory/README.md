# Homebox home inventory

A single-container [Homebox](https://github.com/sysadminsmedia/homebox) (the maintained `sysadminsmedia` fork) plus a script that seeds it through the HTTP API: a location tree, items with asset IDs, warranty and purchase fields, receipt and warranty attachments, a maintenance entry, a QR code, and a printable label.

Companion to the post: https://sumguy.com/homebox-home-inventory/

## Files

- `compose.yaml`: Homebox pinned to `0.27.1`, data in a named volume, host port `3190`.
- `seed.sh`: registers `you@example.com`, builds Garage > Shelf A > Box 3, adds items, uploads attachments, and downloads `qr.jpg` and `label.png`.

## Prerequisites and tested versions

- Homebox v0.27.1 (`ghcr.io/sysadminsmedia/homebox:0.27.1`)
- Docker 29.9.2, Docker Compose 5.6.1
- `curl` and `jq` for `seed.sh`

## Run it

```bash
# 1. Edit HBOX_AUTH_API_KEY_PEPPER in compose.yaml (32+ bytes: openssl rand -base64 48)
docker compose up -d
# 2. Wait a few seconds, then seed demo data
./seed.sh
# 3. Open http://localhost:3190 and log in as you@example.com / correct-horse-battery
```

Tear down and delete the data volume:

```bash
docker compose down -v
```

## Notes

- Homebox refuses to start if the pepper is shorter than 32 bytes.
- `HBOX_OPTIONS_HOSTNAME` sets the base URL inside label QR codes. Include the scheme (`https://`); a bare hostname makes Homebox guess it from the request. Without the setting, an asset label fetched with `curl` encodes only a path such as `/a/000-004`.
- Set `HBOX_OPTIONS_ALLOW_REGISTRATION=false` after you create your accounts. Invitation tokens still work.
- The demo password is a placeholder. Do not expose this setup as is.
