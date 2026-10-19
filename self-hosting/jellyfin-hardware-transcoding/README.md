# Jellyfin hardware transcoding: prove it works

Two Compose files (Intel Quick Sync, NVIDIA NVENC) and a script that checks whether Jellyfin is really using the GPU.

Article: https://sumguy.com/jellyfin-hardware-transcoding/

## Files

| File | Purpose |
| --- | --- |
| `compose.intel.yml` | Official `jellyfin/jellyfin` image with `/dev/dri/renderD128` and the host render GID via `group_add` |
| `compose.nvidia.yml` | Same image with the GPU reserved through `deploy.resources.reservations.devices` |
| `check-hwaccel.sh` | Checks device access, render GID, `vainfo` or `nvidia-smi`, and the encoder named in the latest transcode log |

## Prerequisites

- Docker with the Compose plugin.
- Intel: a QSV-capable iGPU (Broadwell or newer) and a render node at `/dev/dri/renderD128` (check with `ls /dev/dri`).
- NVIDIA: the NVIDIA driver and the NVIDIA Container Toolkit on the host.
- Media at `/srv/media`, config at `/opt/jellyfin/config`, cache at `/opt/jellyfin/cache` (change in the compose file).

Tested against: Jellyfin server 12.2 (jellyfin-ffmpeg 8.1.x). Compose syntax validated with `docker compose config -q`. The script is syntax-checked with `bash -n`. The GPU paths need real hardware to exercise.

## Run

Intel:

```bash
export RENDER_GID=$(getent group render | cut -d: -f3)
docker compose -f compose.intel.yml up -d
```

NVIDIA:

```bash
docker compose -f compose.nvidia.yml up -d
```

Then in the Jellyfin web UI, open Dashboard > Playback > Transcoding, set "Hardware acceleration" to Intel Quicksync (QSV) or Nvidia NVENC, tick the codecs your GPU can decode, and tick "Enable hardware encoding".

Start a transcode from a client (force a lower bitrate in the player), then:

```bash
./check-hwaccel.sh jellyfin
```

Exit code is 0 when every check passes, 1 on a FAIL, 2 if the container does not exist.

On the host, also watch `sudo intel_gpu_top` (Video engine busy) or `nvidia-smi` (an ffmpeg process with VRAM in use).
