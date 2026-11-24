"""Faster-Whisper alone: segments plus word timestamps, no speaker labels.

Usage: python transcribe_fw.py /data/audio/interview.wav
Env:   MODEL (default large-v3), DEVICE (default cuda), COMPUTE_TYPE (default float16)
"""
import os
import sys

from faster_whisper import WhisperModel

model = WhisperModel(
    os.environ.get("MODEL", "large-v3"),
    device=os.environ.get("DEVICE", "cuda"),
    compute_type=os.environ.get("COMPUTE_TYPE", "float16"),
)

segments, info = model.transcribe(sys.argv[1], word_timestamps=True)

for segment in segments:
    for word in segment.words:
        print(f"[{word.start:.2f}s -> {word.end:.2f}s] {word.word}")
