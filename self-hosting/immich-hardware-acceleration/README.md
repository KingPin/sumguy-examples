# Immich Hardware Acceleration

Working compose snippets for accelerating Immich's video transcoding and ML
inference on Intel iGPU (QSV + OpenVINO), NVIDIA (NVENC + CUDA), and AMD
(VAAPI + ROCm).

Companion code for the article:
**[Immich Hardware Acceleration: Stop Cooking Your CPU](https://sumguy.com/immich-hardware-acceleration/)**

## What's here

- `intel/` — QSV transcoding + OpenVINO ML using a single Intel iGPU. The
  cheap home-lab path (works great on an N100).
- `nvidia/` — NVENC transcoding + CUDA ML on a discrete NVIDIA card.
- `amd/` — VAAPI transcoding + ROCm ML on a discrete AMD card.

Each folder contains:

- `docker-compose.yml` — the main Immich stack
- `hwaccel.transcoding.yml` — the device passthrough fragment
- `.env.example` — copy to `.env` and fill in

## Prerequisites

- Docker + Docker Compose v2
- For NVIDIA: NVIDIA Container Toolkit installed and `nvidia-smi` working
  from a `--gpus all` container
- For Intel/AMD: `getent group video render` to find your real GIDs; drop
  them into `.env` (they vary by distro)

## Running

```bash
cp .env.example .env
# edit .env — set passwords, library path, group IDs
docker compose up -d
```

Then go to **Administration → System Settings** in the Immich UI and:

1. Set **Video Transcoding → Hardware Acceleration** to match your path
   (QSV / NVENC / VAAPI).
2. Set **Machine Learning → Execution Provider** to match
   (OpenVINO / CUDA / ROCm).

## Verifying it works

- Intel: `sudo intel_gpu_top` — Video + Render/3D engines should light up
- NVIDIA: `watch -n 1 nvidia-smi` — see Immich processes + GPU util
- AMD: `radeontop` or `rocm-smi`

If the GPU shows 0% utilization during a transcode or smart-search job,
the container fell back to CPU — usually a wrong group ID or a mismatch
between the ML image tag and the execution provider.

## License

MIT. Use as you like.
