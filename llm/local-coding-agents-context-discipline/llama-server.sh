#!/usr/bin/env bash
# Launch llama.cpp's server for agentic coding with a capped context and an
# unquantized KV cache.
#
# Usage:
#   ./llama-server.sh /path/to/qwen3.6-27b-instruct-q5_k_m.gguf
#
# Requires: llama.cpp built with server support (llama-server on PATH).

set -euo pipefail

MODEL="${1:?usage: $0 /path/to/model.gguf}"
PORT="${PORT:-8080}"

# Context budget. Deliberately far below the model's advertised maximum.
# Bump it only when a task genuinely will not fit, and drop it back afterwards.
CTX="${CTX:-32768}"

exec llama-server \
  --model "$MODEL" \
  --ctx-size "$CTX" \
  --port "$PORT" \
  --n-gpu-layers 99 \
  --cache-type-k f16 \
  --cache-type-v f16 \
  --temp 0.2 \
  --top-p 0.9
#
# --cache-type-k / --cache-type-v (short forms -ctk / -ctv) set the KV cache data
# type. f16 is already the default; they are spelled out here so that nobody
# "optimizes" this script later by setting them to q8_0 or q4_0. That trade is
# fine for single-turn chat and bad for a thirty-turn agentic session, where the
# small numerical errors compound.
#
# --n-gpu-layers 99 offloads everything it can to the GPU. Lower it if the model
# does not fit in VRAM at this context size.
