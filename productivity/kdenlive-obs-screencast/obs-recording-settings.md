# OBS Recording Settings Cheatsheet

Reference settings for the OBS + Kdenlive screencast pipeline.
Tested with OBS Studio 30.x on Linux.

---

## Output → Recording

| Setting             | Value                              | Notes                                      |
|---------------------|------------------------------------|--------------------------------------------|
| Recording Format    | `MKV`                              | Crash-safe. Remux to MP4 with ffmpeg after. |
| Encoder (NVIDIA)    | `h264_nvenc`                       | Use `hevc_nvenc` if you want smaller files. |
| Encoder (AMD)       | `h264_vaapi`                       | Requires correct VAAPI setup on your distro. |
| Encoder (CPU)       | `libx264` preset `medium`          | Fine for terminal/UI screencasts.           |
| Rate Control        | `VBR`                              | With max bitrate cap (see below).           |
| Max Bitrate (1080p60) | `15000 kbps`                     | Drop to 10000 for 1080p30 or static content. |
| Keyframe Interval   | `2` seconds                        | Helps seek accuracy in Kdenlive.            |

---

## Video Settings

| Setting         | Value                   | Notes                                   |
|-----------------|-------------------------|-----------------------------------------|
| Base Resolution | `1920x1080`             | Match your monitor/capture resolution.  |
| Output Resolution | `1920x1080`           | Do NOT downscale at capture time.       |
| FPS             | `60` (tutorials/demos)  | Use `30` for talking-head only.         |
| Downscale Filter | `Lanczos`              | If you must downscale.                  |

---

## Audio: Multi-Track Setup (Critical)

Go to **Settings → Output → Recording → Audio Track** and enable:

- **Track 1:** Microphone / headset input
- **Track 2:** Desktop audio (system sounds, browser, etc.)

Then in the **Audio Mixer**, right-click each source and choose
**"Advanced Audio Properties"**. Assign:

| Source         | Track Assignment |
|----------------|-----------------|
| Mic/Headset    | Track 1          |
| Desktop Audio  | Track 2          |

MKV preserves multiple audio streams. Kdenlive will map them to separate
timeline tracks automatically, letting you mute/duck them independently.

---

## What to Leave Alone

- **Color Space / Color Format:** Leave at defaults (NV12, Rec.709). Don't touch these unless you know why.
- **Audio bitrate:** 160 kbps is fine for monitoring; the final quality comes from Kdenlive's render settings.
- **B-frames:** Default is fine for source footage. Don't optimize for streaming.
