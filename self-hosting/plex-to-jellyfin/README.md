# Plex to Jellyfin Migration Kit

A working Docker Compose stack for running Jellyfin alongside an existing Plex server during migration. No media files get moved — both servers point at the same read-only media mount.

📖 **Full article:** [Plex Pass Hits $749. Time for Jellyfin.](https://sumguy.com/posts/plex-price-hike-jellyfin-migration/)

## What This Is

A base Jellyfin Compose file plus two hardware-acceleration overrides:

| File | Purpose |
|---|---|
| `docker-compose.yml` | Base Jellyfin service, read-only media mount, healthcheck |
| `docker-compose.qsv.yml` | Intel Quick Sync / VAAPI override (iGPU transcoding) |
| `docker-compose.nvidia.yml` | NVIDIA NVENC override (discrete GPU transcoding) |
| `Caddyfile.snippet` | Reverse-proxy snippet for exposing Jellyfin over HTTPS |

You don't need both override files — pick the one that matches your hardware. If you don't need hardware transcoding (low-bitrate libraries, fast CPU, single user), the base file works on its own.

## Prerequisites

- Docker and Docker Compose v2
- A media library already on disk somewhere your host can read
- ~1 GB free RAM for Jellyfin itself
- Port `8096` available (or accept `network_mode: host`)
- Tested on Debian 12 / Ubuntu 24.04 with Docker 27.x and Jellyfin 10.10

For hardware transcoding:
- **Intel:** an iGPU from roughly 2015 onward (anything Skylake-era or newer, including N100/N305 mini PCs)
- **NVIDIA:** consumer or pro card with NVENC, nvidia-container-toolkit installed, runtime configured in Docker

## How to Run

1. Clone or copy this directory:

   ```bash
   git clone https://github.com/KingPin/sumguy-examples.git
   cd sumguy-examples/self-hosting/plex-to-jellyfin
   ```

2. Edit `docker-compose.yml`:
   - Update `/mnt/media:/media:ro` to point at your actual media directory (use the same paths Plex uses).
   - Update `JELLYFIN_PublishedServerUrl` to your server's LAN IP.
   - Update `TZ` to your timezone.
   - Confirm `user: 1000:1000` matches a user on your host that can read your media.

3. Bring it up — pick one of the three modes:

   **Software transcoding only (base):**
   ```bash
   docker compose up -d
   ```

   **Intel QSV / VAAPI hardware transcoding:**
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.qsv.yml up -d
   ```

   **NVIDIA NVENC hardware transcoding:**
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.nvidia.yml up -d
   ```

4. Open `http://<your-server-ip>:8096` in a browser and run the first-time setup wizard. Point libraries at `/media/<your-folders>`.

5. Verify hardware transcoding (if applicable):

   ```bash
   # Intel/AMD
   docker exec -it jellyfin vainfo

   # NVIDIA
   docker exec -it jellyfin nvidia-smi
   ```

   Then in the Jellyfin UI: **Dashboard → Playback → Transcoding** and pick your acceleration method.

## Running Alongside Plex

The whole point: you don't need to stop Plex to use this. Both servers can read the same media files simultaneously since the mount is read-only. Run them in parallel for a week or two, switch household members over gradually, then sunset Plex when nobody complains anymore.

## Remote Access

The base Compose doesn't expose Jellyfin to the internet. Recommended options:

- **Tailscale / Headscale** — install on every device, hit the tailnet IP. Zero port-forwarding, end-to-end encrypted.
- **Reverse proxy** — see `Caddyfile.snippet` for a working Caddy config with HTTPS, security headers, and trusted-proxy setup for real client IPs.
- **Raw port-forward on 8096** — don't.

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| Jellyfin can't read media files | The `user:` UID in the compose doesn't have read permission on `/mnt/media`. Fix permissions or change the UID. |
| `vainfo` fails inside the container | Render group GID mismatch. Run `getent group render` on the host and update `group_add:` in `docker-compose.qsv.yml`. |
| Transcoding stays on CPU even after enabling QSV | Restart the container after enabling hardware accel in the UI. Codec must also be in the "decode" list. |
| NVIDIA card invisible to container | Verify `nvidia-container-toolkit` is installed and Docker daemon is configured with the NVIDIA runtime. |
| DLNA discovery doesn't work | `network_mode: host` is required for cleanest DLNA behavior. Bridge networks need explicit multicast handling. |

## Related

- [Headscale: Self-Hosted Tailscale](https://sumguy.com/posts/headscale-self-hosted-tailscale/) — for remote access
- [Overseerr vs Jellyseerr](https://sumguy.com/posts/overseerr-vs-jellyseerr/) — request system replacement
- [Plex Meta Manager: Posters, Collections, Sanity](https://sumguy.com/posts/plex-meta-manager-posters-collections/) — works with Jellyfin too via the Kometa fork

## License

MIT. Use it, fork it, ship it.
