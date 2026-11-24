"""WhisperX pipeline: batched transcription, wav2vec2 alignment, pyannote diarization.

Usage: HF_TOKEN=hf_xxx python transcribe_wx.py /data/audio/interview.wav
Env:   MODEL (default large-v3), DEVICE (default cuda), COMPUTE_TYPE (default float16),
       BATCH_SIZE (default 16), MIN_SPEAKERS / MAX_SPEAKERS (default 2 / 3).
       Without HF_TOKEN the diarization step is skipped and words get no speaker.
"""
import gc
import os
import sys

import whisperx
from whisperx.diarize import DiarizationPipeline

device = os.environ.get("DEVICE", "cuda")
audio_file = sys.argv[1]
batch_size = int(os.environ.get("BATCH_SIZE", "16"))  # lower it if you run out of VRAM
compute_type = os.environ.get("COMPUTE_TYPE", "float16")  # "int8" if VRAM is tight
hf_token = os.environ.get("HF_TOKEN")

# 1. Batched transcription (faster-whisper under the hood)
model = whisperx.load_model(os.environ.get("MODEL", "large-v3"), device, compute_type=compute_type)
audio = whisperx.load_audio(audio_file)
result = model.transcribe(audio, batch_size=batch_size)

# Free memory before loading the next model
del model
gc.collect()

# 2. Forced alignment with a wav2vec2 model for the detected language
model_a, metadata = whisperx.load_align_model(language_code=result["language"], device=device)
result = whisperx.align(
    result["segments"], model_a, metadata, audio, device,
    return_char_alignments=False,
)

# 3. Diarization (needs a Hugging Face read token and the accepted model terms)
if hf_token:
    diarize_model = DiarizationPipeline(token=hf_token, device=device)
    diarize_segments = diarize_model(
        audio,
        min_speakers=int(os.environ.get("MIN_SPEAKERS", "2")),
        max_speakers=int(os.environ.get("MAX_SPEAKERS", "3")),
    )
    # 4. Attach speakers to segments and words
    result = whisperx.assign_word_speakers(diarize_segments, result)

for seg in result["segments"]:
    print(seg.get("speaker", "UNKNOWN"), f"{seg['start']:.2f}", seg["text"].strip())
    for w in seg.get("words", []):
        if "start" in w:
            print(f"    [{w['start']:.2f}s -> {w['end']:.2f}s] {w['word']}")
