# kdenlive-obs-screencast

Companion files for the **Kdenlive + OBS Studio: Screencast Pipeline** article
on [sumguy.com](https://sumguy.com/kdenlive-obs-studio-screencast-pipeline/).

This is the open-source screencast pipeline: record with OBS using crash-safe
settings and separate audio tracks, edit in Kdenlive, ship 1080p MP4 to the web.
No subscriptions, no Adobe tax, no DaVinci MP4/AAC paywall on Linux.

---

## Files

### `obs-recording-settings.md`

OBS Studio recording settings reference. Covers:

- Container (MKV — not MP4), encoder choices (NVENC, VAAPI, x264), bitrate
- The critical multi-track audio setup (mic on Track 1, desktop on Track 2)
- What settings to leave at defaults

Use this as a checklist when configuring OBS for the first time or after a fresh install.

### `kdenlive-render-preset.xml`

Custom Kdenlive render preset: H.264, CRF 21, AAC 192k, `+faststart`.

**Installation:**

```bash
# Option A: drop it in the profiles directory directly
cp kdenlive-render-preset.xml ~/.config/kdenlive/kdenliverenderingprofiles/

# Option B: merge into existing customprofiles.xml
# Copy the <profile ...> element into your existing file's <profiles> block
```

Restart Kdenlive after copying. The preset appears as **"SumGuy Web 1080p H.264 CRF21"**
under Project → Render → Custom presets.

Adjust `crf=` in the XML if you want different quality:
- `18`–`20`: near-lossless archival
- `21`–`22`: high-quality web delivery (default)
- `23`–`25`: smaller files, acceptable quality for previews

### `remux-mkv-to-mp4.sh`

Remuxes an OBS MKV recording to MP4 without re-encoding. Use this when OBS crashed
mid-recording (MP4 would be corrupt; MKV is recoverable) or when you need an MP4
before editing.

**Prerequisites:** `ffmpeg` installed and on your PATH.

**Usage:**

```bash
chmod +x remux-mkv-to-mp4.sh

# Output filename derived from input (replaces .mkv with .mp4)
./remux-mkv-to-mp4.sh 2026-05-20_obs_recording.mkv

# Explicit output filename
./remux-mkv-to-mp4.sh crash.mkv recovered.mp4
```

The script:
- Checks for ffmpeg and exits cleanly if missing
- Prints duration of the source file
- Runs `ffmpeg -c copy -movflags +faststart` (no re-encode, fast)
- Confirms output size when done

---

## Prerequisites

- **OBS Studio** 30.x+ (from your distro or [obsproject.com](https://obsproject.com))
- **Kdenlive** 23.x+ ([kdenlive.org](https://kdenlive.org))
- **ffmpeg** for the remux script and any final-mile trimming

On Debian/Ubuntu:
```bash
sudo apt install obs-studio kdenlive ffmpeg
```

On Arch/Manjaro:
```bash
sudo pacman -S obs-studio kdenlive ffmpeg
```

---

## Related

- Article: [Kdenlive + OBS Studio: Screencast Pipeline](https://sumguy.com/kdenlive-obs-studio-screencast-pipeline/)
- [OBS Studio docs](https://obsproject.com/wiki/)
- [Kdenlive docs](https://docs.kdenlive.org/)
