# Recyclarr + TRaSH Guides Kit

A working Docker Compose service and config that syncs TRaSH Guides quality profiles, custom formats, quality sizes, and naming into an existing Sonarr and Radarr. Nothing gets clicked by hand, and guide updates arrive on a daily schedule.

📖 **Full article:** [Recyclarr: TRaSH Guides for Sonarr/Radarr](https://sumguy.com/recyclarr-trash-guides-sonarr-radarr/)

## What This Is

| File | Purpose |
|---|---|
| `docker-compose.yml` | Recyclarr in cron mode, joined to the network your Sonarr and Radarr already use |
| `config/recyclarr.yml` | One Sonarr instance (`WEB-1080p`) and one Radarr instance (`Remux + WEB 1080p`), with one score override |
| `.env.example` | URLs and API keys, read by the config through `!env_var` |

The config uses guide-backed quality profiles: one `trash_id` per profile pulls the qualities, custom formats, and scores from the TRaSH Guides. The only hand-written scoring is a single override that sets `x265 (HD)` to `0` on the Sonarr profile (the guide default is `-10000`).

## Prerequisites

- Docker and Docker Compose v2
- A running Sonarr and Radarr, reachable from Docker by name on a shared network (the compose file expects an external network called `media`)
- The API key from each app (Settings, General, Security)
- Written for Recyclarr v8.8.1, Sonarr v4.0.20, and Radarr v7.0.3. The config parses and `sync --preview` runs on Recyclarr v8.8.1; it was not synced against a live Sonarr or Radarr for this kit

## How to Run

1. Copy the files and set your values:

   ```bash
   git clone https://github.com/KingPin/sumguy-examples.git
   cd sumguy-examples/self-hosting/recyclarr-trash-guides-sonarr-radarr
   cp .env.example .env
   ```

2. Edit `.env` with your URLs and API keys. Edit `docker-compose.yml` if your shared network is not named `media`.

3. Preview first. This reads from Sonarr and Radarr but changes nothing:

   ```bash
   docker compose run --rm recyclarr sync --preview
   ```

4. Read the preview, then run the real sync:

   ```bash
   docker compose run --rm recyclarr sync
   ```

5. Start the scheduled container. It syncs at 04:00 daily (`CRON_SCHEDULE`):

   ```bash
   docker compose up -d
   ```

## Things to Know

- **`delete_old_custom_formats: true`** deletes custom formats that Recyclarr created earlier and that you later remove from the config. It never touches custom formats you made by hand.
- **`reset_unmatched_scores`** sets the score to `0` for every custom format in that profile that Recyclarr does not manage. Custom formats you scored manually get zeroed unless you list them under `except`.
- **`media_naming`** turns on file renaming and sets the naming formats. Remove that block if you want to keep your current naming.
- **Pin the major version.** The image tag is `:8`. Recyclarr publishes no `latest` tag. The unreleased v9 changelog lists the removal of `CRON_SCHEDULE` from the Docker image, so upgrade on purpose.
- The first sync creates the custom formats and the profiles. The next syncs only apply differences.

## Finding Other Profiles and Custom Formats

```bash
docker compose run --rm recyclarr list quality-profiles sonarr
docker compose run --rm recyclarr list custom-format-groups radarr
docker compose run --rm recyclarr list custom-formats radarr
docker compose run --rm recyclarr list naming radarr
```

## Related

- Blog post: https://sumguy.com/recyclarr-trash-guides-sonarr-radarr/
- Recyclarr docs: https://recyclarr.dev
- TRaSH Guides: https://trash-guides.info
