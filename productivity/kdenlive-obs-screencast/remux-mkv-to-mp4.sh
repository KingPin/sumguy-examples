#!/usr/bin/env bash
# remux-mkv-to-mp4.sh
# Remux an OBS MKV recording to MP4 without re-encoding.
#
# Use this when:
#   - OBS crashed and left a broken/incomplete MKV
#   - You want to share the recording before editing
#   - Your editor refuses to import MKV directly
#
# What this does NOT do:
#   - Re-encode video or audio (zero quality loss)
#   - Trim or edit the footage
#   - Fix corrupted video streams (only the container is repaired)
#
# Requirements: ffmpeg (install via your package manager)
#
# Usage:
#   ./remux-mkv-to-mp4.sh input.mkv [output.mp4]
#
#   If output filename is omitted, the script uses the same name
#   as the input with .mp4 extension.
#
# Examples:
#   ./remux-mkv-to-mp4.sh 2026-05-20_obs_recording.mkv
#   ./remux-mkv-to-mp4.sh crash.mkv recovered.mp4

set -euo pipefail

# ── Argument handling ────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input.mkv> [output.mp4]" >&2
  exit 1
fi

INPUT="$1"

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input file not found: $INPUT" >&2
  exit 1
fi

if [[ $# -ge 2 ]]; then
  OUTPUT="$2"
else
  # Replace extension: foo.mkv → foo.mp4
  OUTPUT="${INPUT%.mkv}.mp4"
fi

if [[ "$INPUT" == "$OUTPUT" ]]; then
  echo "Error: input and output paths are the same." >&2
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "Warning: output file already exists: $OUTPUT"
  read -rp "Overwrite? [y/N] " confirm
  [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }
fi

# ── Sanity check: verify ffmpeg is available ─────────────────────────────────

if ! command -v ffmpeg &>/dev/null; then
  echo "Error: ffmpeg not found. Install it with:" >&2
  echo "  sudo apt install ffmpeg     # Debian/Ubuntu" >&2
  echo "  sudo dnf install ffmpeg     # Fedora/RHEL" >&2
  echo "  sudo pacman -S ffmpeg       # Arch/Manjaro" >&2
  exit 1
fi

# ── Probe input briefly ───────────────────────────────────────────────────────

echo "Input:  $INPUT"
echo "Output: $OUTPUT"
echo ""

DURATION=$(ffprobe -v quiet -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null || echo "unknown")

if [[ "$DURATION" != "unknown" ]]; then
  # Convert seconds to HH:MM:SS
  printf "Duration: %02d:%02d:%02d\n" \
    $((${DURATION%.*} / 3600)) \
    $(((${DURATION%.*} % 3600) / 60)) \
    $((${DURATION%.*} % 60))
fi

echo ""
echo "Remuxing (no re-encode, this will be fast)..."
echo ""

# ── Remux ────────────────────────────────────────────────────────────────────
#
# Flags:
#   -i "$INPUT"           Input file
#   -c copy               Copy all streams without re-encoding
#   -movflags +faststart  Move MP4 index to start (web-friendly)
#   -y                    Overwrite output without prompting (we already asked)
#
ffmpeg \
  -i "$INPUT" \
  -c copy \
  -movflags +faststart \
  -y \
  "$OUTPUT"

echo ""
echo "Done: $OUTPUT"

# Print output file size for sanity check
if command -v du &>/dev/null; then
  SIZE=$(du -sh "$OUTPUT" 2>/dev/null | cut -f1)
  echo "Size: $SIZE"
fi
