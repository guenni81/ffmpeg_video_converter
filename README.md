# macOS Video Conversion Script

## Overview
This script converts videos to **HEVC (MP4)**, followed by an **MKV Annex-B remux**, while preserving selected audio and subtitle tracks.

It leverages Apple’s hardware-accelerated encoder `hevc_videotoolbox` and lets you customize resolution, bit depth, frame rate, audio formats, subtitles, and languages.

All processed files are saved in a user-defined output directory.

---

## Installation

1. Save the script, for example as `convert_videos.sh`.  
2. Make it executable:
   ```bash
   chmod +x convert_videos.sh
   ```
3. Place your source videos in a folder, e.g. `./input`.

---

## Running the Script

```bash
bash convert_videos.sh
```

The script will walk you through each setting step by step.

---

## Options Overview

| Option | Description | Default | Example |
|--------|--------------|----------|----------|
| **Resolution** | Target video resolution | 1080p | `1=1080p, 2=4K` |
| **Input Folder** | Folder containing source videos | `./input` | `./my_videos` |
| **Output Folder** | Folder for converted videos | `./output` | `./converted` |
| **Framerate (FPS)** | Target frame rate. Leave blank to keep original | Original | `30` |
| **Bit Depth** | Video color depth | `8bit` | `10bit` |
| **Quality (Q)** | HEVC Videotoolbox quality factor (lower = better quality) | `65` | `50` |
| **Languages (Audio & Subtitles)** | Language filter for tracks (comma-separated) | `ger` | `ger,eng` |
| **Audio Format(s)** | Audio format conversion/passthrough (comma-separated) | `ac3` | `aac,ac3,eac3` |

---

## How It Works

### 1. MKV Creation
- The video is encoded to MKV using `hevc_videotoolbox`.  
- Audio tracks are either passed through or converted based on your settings.  
- Missing tracks are automatically generated if needed.

### 2. MKV Annex-B Remux
- Combines the encoded MP4 video with audio and subtitles from the original file.  
- Subtitles in selected languages are preserved, including `default` and `forced` flags.  
- Applies the HEVC Annex-B filter for maximum compatibility.

### 3. Output
- All finished files are saved in the specified output directory.  
- Filenames follow this pattern:  
  ```
  <original_name>_HEVC.mkv
  ```

---

## Multiple Languages and Audio Formats

- Example for multiple languages:  
  ```
  ger,eng,fre
  ```
- Example for multiple audio formats:  
  ```
  aac,ac3,eac3
  ```

---

## Notes

- Only the audio formats **aac**, **ac3**, and **eac3** are directly supported for passthrough.  
- If you leave the **Framerate** blank, the script keeps the source frame rate.  
- 10-bit HEVC videos are correctly encoded as 10-bit output.  
- The script is optimized for **macOS** and **Apple Silicon** hardware acceleration.

