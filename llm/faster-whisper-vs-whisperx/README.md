# Faster-Whisper vs WhisperX

Two transcription scripts for the same audio file:

- `transcribe_fw.py`: Faster-Whisper alone. Segments and word timestamps from `word_timestamps=True`, no speaker labels.
- `transcribe_wx.py`: the WhisperX pipeline. Batched transcription, wav2vec2 forced alignment, pyannote diarization, then `assign_word_speakers`. Prints each segment with its speaker and per-word timings.

Write-up: https://sumguy.com/faster-whisper-vs-whisperx/

## Prerequisites and tested versions

- Python 3.12 (WhisperX 3.8.6 requires `>=3.10,<3.14`)
- WhisperX 3.8.6, faster-whisper 1.2.1, torch 2.8.0
- `ffmpeg` on your `PATH` (WhisperX decodes audio through the `ffmpeg` binary)
- For diarization: a Hugging Face read token, and the access conditions accepted on
  https://huggingface.co/pyannote/speaker-diarization-community-1 while logged in
- A CUDA GPU is the intended target. CPU works with `DEVICE=cpu COMPUTE_TYPE=int8`, slowly.

**PyAV trap:** faster-whisper 1.2.1 fails on file paths with PyAV 19
(`TypeError: open() got an unexpected keyword argument 'metadata_errors'`).
The fix is merged upstream (SYSTRAN/faster-whisper#1589) but not released as of
November 2026. Pin `av<19` for the Faster-Whisper script.

## What was tested

Both scripts ran on CPU (`DEVICE=cpu COMPUTE_TYPE=int8 MODEL=tiny.en`) against
`tests/data/jfk.flac` from the faster-whisper repo: transcription and wav2vec2
alignment for WhisperX, transcription and word timestamps for Faster-Whisper
(with `av<19`). The diarization step was not run for this release: it needs a
Hugging Face token with the pyannote terms accepted. Without `HF_TOKEN` the
WhisperX script skips diarization and prints `UNKNOWN` as the speaker.

## Run

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt

# Faster-Whisper only
python transcribe_fw.py /data/audio/interview.wav

# WhisperX with speaker labels
HF_TOKEN=hf_xxx MIN_SPEAKERS=2 MAX_SPEAKERS=3 python transcribe_wx.py /data/audio/interview.wav

# CPU, small model
DEVICE=cpu COMPUTE_TYPE=int8 MODEL=small python transcribe_wx.py /data/audio/interview.wav
```

Environment variables: `MODEL` (default `large-v3`), `DEVICE` (default `cuda`),
`COMPUTE_TYPE` (default `float16`), `BATCH_SIZE` (WhisperX only, default 16),
`HF_TOKEN`, `MIN_SPEAKERS`, `MAX_SPEAKERS`.

## CLI equivalent

```bash
whisperx /data/audio/interview.wav --model large-v3 --diarize --hf_token hf_xxx \
  --min_speakers 2 --max_speakers 3 --highlight_words True --output_format srt \
  --output_dir /data/out
```
