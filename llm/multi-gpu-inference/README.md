# Multi-GPU LLM inference on consumer cards

Companion files for [Multi-GPU LLM Inference on Consumer Cards](https://sumguy.com/multi-gpu-inference-consumer-gpus/).

## What it does

- `llamacpp/compose.yaml`: llama.cpp server with `--split-mode layer` and a `--tensor-split` ratio (default `2,1` for a 24 GB + 12 GB pair).
- `vllm/compose.yaml`: vLLM OpenAI-compatible server with `--tensor-parallel-size` (default 2) and `ipc: host`.
- `check-gpus.sh`: prints PCIe link generation and width, VRAM, topology, and the P2P capability matrix.
- `.env.example`: every variable the compose files read.

## Prerequisites and tested versions

- Docker Engine with Compose v2 and the NVIDIA Container Toolkit.
- Two or more NVIDIA GPUs. vLLM needs matching cards.
- Image versions checked against upstream on 2026-10-20: llama.cpp release `v0.7.0` (image `ghcr.io/ggml-org/llama.cpp:server-cuda`), vLLM release `v0.32.0` (image `vllm/vllm-openai`; the compose file uses `latest`, pin the tag for anything permanent).

Honest status: the compose files are validated with `docker compose config`. They were not run on a multi-GPU machine. The model repos named in `.env.example` were confirmed to exist on Hugging Face, but no weights were loaded.

## How to run

```bash
cp .env.example .env        # edit paths, split ratio, TP size
./check-gpus.sh

# llama.cpp
docker compose --env-file .env -f llamacpp/compose.yaml up -d

# vLLM (use one or the other on the same GPUs)
docker compose --env-file .env -f vllm/compose.yaml up -d
```

llama.cpp listens on `127.0.0.1:8080`, vLLM on `127.0.0.1:8000`. Both speak the OpenAI chat API.

Put the GGUF file in `MODELS_DIR` first. vLLM downloads its model into `HF_CACHE_DIR`.
