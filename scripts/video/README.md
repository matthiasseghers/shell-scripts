# Video Scripts

This directory contains scripts for video processing and editing tasks.

## Contents

- **ps5_convert.sh** - Convert PS5 .webm recordings to .mp4 (auto-detects SDR/HDR)
- **video-ocr.sh** - OCR pipeline for searching text in videos
- **detect-silence.sh** - Detect silent parts in videos for easier editing
- **sidebar-check.sh** - Calculate sidebar/letterbox space for overlaying images on a video timeline
- **fcp/** - Final Cut Pro specific scripts (see [fcp/README.md](fcp/README.md))

## Prerequisites

Install all dependencies at once from the repository root:

```bash
./install-deps.sh
```

Or install manually:

```bash
brew install ffmpeg imagemagick parallel tesseract
brew install bash  # sidebar-check.sh requires bash 4+ (macOS ships with 3.x)
```

---

## ps5_convert.sh

Convert PS5 Share capture `.webm` files to `.mp4`. Automatically detects whether each file is SDR or HDR and applies the appropriate encoding path.

| Source | `--mode sdr` (default) | `--mode hdr` |
|--------|------------------------|--------------|
| SDR (bt709) | re-encode → H.264 | re-encode → H.264 (warns no HDR possible) |
| HDR (smpte2084 / HLG) | tone-map → SDR H.264 | preserve HDR → HEVC H.265 |

> **Note:** PS5 Share captures are VP9 Profile 0, 8-bit, BT.709 SDR — not HDR — despite being 4K. The HDR path exists for future-proofing or other sources.

### Prerequisites

- `ffmpeg` with `libzimg` (`zscale`) for the HDR→SDR tone-mapping path
- `ffprobe` (included with ffmpeg)

```bash
brew install ffmpeg-full  # includes libzimg/zscale
```

### Usage

```bash
./ps5_convert.sh <directory> [--mode sdr|hdr] [--overwrite|--skip]
```

| Option | Description | Default |
|--------|-------------|---------|
| `--mode sdr` | Tone-map HDR→SDR; re-encode SDR as-is | ✓ |
| `--mode hdr` | Preserve HDR metadata, encode as HEVC H.265 | - |
| `--overwrite` | Always overwrite existing `.mp4` files without prompting | - |
| `--skip` | Always skip existing `.mp4` files without prompting | - |
| *(neither)* | Prompt per file when a `.mp4` already exists | ✓ |

### Examples

**Convert all .webm files to SDR .mp4 (default, prompt on conflict):**
```bash
./ps5_convert.sh ~/Movies/PS5/CREATE/Video\ Clips/Burnout\ Paradise\ Remastered
```

**Resume a partial run — skip already-converted files:**
```bash
./ps5_convert.sh ~/Movies/PS5/CREATE/Video\ Clips/Burnout\ Paradise\ Remastered --skip
```

**Re-encode everything, overwrite without prompting:**
```bash
./ps5_convert.sh ~/Movies/PS5/CREATE/Video\ Clips/Burnout\ Paradise\ Remastered --overwrite
```

**Preserve HDR, output HEVC:**
```bash
./ps5_convert.sh ~/Movies/PS5/CREATE/Video\ Clips/Astro\ Bot --mode hdr
```

### Behaviour

- On conflict (existing `.mp4`): prompts by default; use `--skip` to auto-skip or `--overwrite` to auto-overwrite
- `--overwrite` and `--skip` are mutually exclusive
- Each file is probed for `color_transfer` to detect HDR before encoding
- On failure, partial `.mp4` output is deleted automatically
- Prints a summary of converted / skipped / failed counts

---

## sidebar-check.sh

Calculate how much space is available beside or around a video when placed on an editor timeline. Useful for sizing overlay images (tracker UIs, lower thirds, branding) before you build them.

Supports baked-in bar detection via `cropdetect` and accounts for editor scaling modes like Final Cut Pro's **Spatial Conform: Fit**.

### Features

- **Container Analysis**: Reports raw pixel dimensions and available sidebar/letterbox space
- **Editor Canvas**: Set your timeline resolution with `--editor WxH` (default: 3840x2160)
- **Scale Mode**: Account for how the editor scales the video to fit the canvas (`--scale fit`)
- **Crop Detection**: Detect baked-in letterbox/pillarbox bars and calculate layout based on real content dimensions (`--cropdetect`)
- **Image Checking**: Pass a sidebar image to see if it fits, with exact overflow/slack amounts
- **Formatted Tables**: All output in aligned ASCII tables for easy reading

### Prerequisites

- bash 4+ — macOS ships with 3.x: `brew install bash`
- `ffmpeg` — provides ffprobe + ffmpeg
- `imagemagick` — required only for image checking

### Usage

```bash
./sidebar-check.sh [options] video.mp4 [image.png]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--editor WxH` | Timeline/canvas dimensions | `3840x2160` |
| `--scale fit` | Account for FCP Spatial Conform: Fit scaling | off |
| `--cropdetect` | Detect baked-in letterbox/pillarbox bars | off |
| `-h, --help` | Show full usage | - |

### Examples

**Basic** — how much space is beside this video on a 4K timeline?
```bash
./sidebar-check.sh --editor 3840x2160 video.mp4
```

**Custom canvas** — check against a 1080p timeline:
```bash
./sidebar-check.sh --editor 1920x1080 video.mp4
```

**Account for FCP scaling** — what does the editor actually render?
```bash
./sidebar-check.sh --editor 3840x2160 --scale fit video.mp4
```
> Use this when your FCP timeline is set to Spatial Conform: Fit. A 16:9 source
> on a 16:9 canvas will scale to fill it completely, leaving zero sidebar space
> — this flag makes that explicit rather than showing misleading raw pixel gaps.

**Detect baked-in bars** — is there letterboxing or pillarboxing inside the container?
```bash
./sidebar-check.sh --editor 3840x2160 --cropdetect video.mp4
```
Analyses up to 100 frames to find the most common crop. Reports layout options
for both the container and the real content area.

**Full check** — detect bars, account for FCP scaling, verify a sidebar image:
```bash
./sidebar-check.sh --editor 3840x2160 --scale fit --cropdetect video.mp4 sidebar.png
```

**Check a sidebar image without scaling**:
```bash
./sidebar-check.sh --editor 3840x2160 video.mp4 sidebar.png
```

### Output

The script prints up to four sections depending on which flags are set:

#### 🎬 Video
Always shown. Summarises the file, detected container size, editor canvas, and active flags.

```
🎬  Video
+----------------+-------------------------------------------------------+
| Property       | Value                                                 |
+----------------+-------------------------------------------------------+
| File           | /Movies/gameplay.mp4                                  |
| Container size | 3456x1944                                             |
| Editor canvas  | 3840x2160                                             |
| Scale mode     | fit  (FCP Spatial Conform: Fit)                       |
| Crop detect    | enabled                                               |
+----------------+-------------------------------------------------------+
```

#### 📐 Layout Options (container)
Always shown when the video is smaller than the canvas. Shows available space based on raw container dimensions.

```
📐  Layout Options  (based on container: 3456x1944 on 3840x2160 canvas)
+------------------+-----------------+-----------+
| Layout           | Dimensions      | Area      |
+------------------+-----------------+-----------+
| Single sidebar   | 384x2160px      | 829440px² |
| Split sidebars   | 192x2160px each | N/A       |
| Letterbox strips | 3840x108px each | 829440px² |
+------------------+-----------------+-----------+
```

#### 🎬 Content Crop + 📐 Layout Options (crop)
Shown when `--cropdetect` finds baked-in bars. Reports the real content dimensions and recalculates layout options.

```
🎬  Content Crop  (real content inside the container)
+----------------+--------------------------------+
| Property       | Value                          |
+----------------+--------------------------------+
| Detected crop  | 2592x1944 at offset 432,0      |
| Container size | 3456x1944                      |
| Baked-in bars  | 864px horizontal, 0px vertical |
| Editor canvas  | 3840x2160                      |
+----------------+--------------------------------+

📐  Layout Options  (based on crop: 2592x1944 on 3840x2160 canvas)
+------------------+-----------------+------------+
| Layout           | Dimensions      | Area       |
+------------------+-----------------+------------+
| Single sidebar   | 1248x2160px     | 2695680px² |
| Split sidebars   | 624x2160px each | N/A        |
| Letterbox strips | 3840x108px each | 829440px²  |
+------------------+-----------------+------------+
```

#### 🖥️ Editor Scale + 📐 Layout Options (scaled)
Shown when `--scale fit` is set. Calculates what the editor actually renders on the canvas after applying the scale transform. **This is the most accurate section for FCP users.**

```
🖥️   Editor Scale  (fit — 3840x2160 canvas)
+------------------+----------------------------------------------+
| Property         | Value                                        |
+------------------+----------------------------------------------+
| Source           | crop 2592x1944 inside container 3456x1944    |
| Scale factor     | 1.111x  (3456px → 3840px)                    |
| Scaled to        | 2880x2160px                                  |
| Remaining space  | 960px wide, 0px tall                         |
+------------------+----------------------------------------------+

📐  Layout Options  (based on scaled: 2880x2160 on 3840x2160 canvas)
+------------------+-----------------+-----------+
| Layout           | Dimensions      | Area      |
+------------------+-----------------+-----------+
| Single sidebar   | 960x2160px      | ...       |
| Split sidebars   | 480x2160px each | N/A       |
| Letterbox strips | 3840x0px each   | 0px²      |
+------------------+-----------------+-----------+
```

#### 🖼️ Image
Shown when an image path is provided. Compares the image against the most accurate sidebar reference available (scaled > crop > container) and reports fit status with exact overflow or slack per dimension.

```
🖼️   Image  (compared against scaled (fit) sidebar: 960x2160px)
+--------------+----------------------------------------------+
| Property     | Value                                        |
+--------------+----------------------------------------------+
| File         | /Desktop/sidebar.png                         |
| Resolution   | 605x1080                                     |
| Sidebar space| 960x2160px                                   |
| Fit          | ⚠️  Fits with slack                           |
| Width slack  | 355px  (image: 605px, sidebar: 960px)        |
| Height slack | 1080px  (image: 1080px, sidebar: 2160px)     |
+--------------+----------------------------------------------+
```

### Understanding Scale Mode

When FCP's Spatial Conform is set to **Fit**, the editor scales the video source uniformly so its longest edge fills the canvas while maintaining aspect ratio. This means:

- A **16:9 source on a 16:9 canvas** fills the frame completely — zero sidebar space regardless of resolution difference
- A **4:3 source on a 16:9 canvas** pillarboxes, leaving space on the sides
- Any baked-in bars in the source are scaled up along with the content

Without `--scale fit`, the script reports raw pixel gaps which won't match what you see in the editor. Use `--scale fit` whenever FCP's Spatial Conform is set to Fit.

### Understanding Cropdetect

`cropdetect` analyses video frames to find where the actual content starts and the black bars end. This is useful when:

- Your capture software records at one resolution but the actual gameplay/content doesn't fill the frame
- You've baked in letterbox or pillarbox bars during export

The script samples 100 frames and takes the most common crop result, making it robust against title cards or loading screens that may temporarily fill the full frame.

### Exit Codes

- `0` — Success
- `1` — Error (file not found, invalid arguments, missing dependencies)

---

## detect-silence.sh

Detect silent parts in video files and generate formatted reports. Perfect for identifying editing points, removing dead air, or analyzing audio gaps in your videos.

### Features

- **Customizable Threshold**: Adjust sensitivity from very quiet (-20dB) to absolute silence (-50dB)
- **Minimum Duration Filter**: Ignore brief silences, focus on meaningful gaps
- **Multiple Output Formats**: CSV, plain text, or JSON
- **Visual Preview**: Extract screenshot frames at silence start/end points
- **Video Clip Extraction**: Generate video clips of each silent period for review
- **CSV Reuse**: Read from existing CSV to skip re-analysis
- **Timecode Conversion**: Displays times in HH:MM:SS.mmm format
- **Progress Feedback**: Real-time ffmpeg output during analysis
- **Summary Statistics**: Total silence duration and period count
- **Auto-naming**: Generates `silence_<filename>.<format>` by default

### Prerequisites

- `ffmpeg`

### Usage

```bash
./detect-silence.sh <video_file> [options]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-t, --threshold <dB>` | Silence threshold in decibels | -30dB |
| `-d, --duration <sec>` | Minimum silence duration (seconds) | 0.5 |
| `-f, --format <format>` | Output format: csv, txt, json | csv |
| `-o, --output <file>` | Custom output filename | silence_<video>.<format> |
| `-F, --output-frames` | Generate screenshot frames at silence start/end | - |
| `-V, --output-video` | Generate video clips for each silent period | - |
| `-c, --from-csv <file>` | Read from existing CSV instead of analyzing | - |
| `-h, --help` | Show help message | - |

### Examples

**Basic usage** - Detect silences with default settings:
```bash
./detect-silence.sh video.mp4
# Creates: silence_video.csv
```

**More sensitive detection** - Catch quieter parts:
```bash
./detect-silence.sh video.mp4 -t -25dB
```

**Longer silences only** - Ignore brief pauses:
```bash
./detect-silence.sh video.mp4 -d 1.0
```

**Plain text report**:
```bash
./detect-silence.sh video.mp4 -f txt
# Creates: silence_video.txt
```

**JSON output**:
```bash
./detect-silence.sh video.mp4 -f json -o my_report.json
```

**Fine-tuned detection**:
```bash
./detect-silence.sh interview.mp4 -t -40dB -d 0.3 -f csv
```

**Environment variables**:
```bash
SILENCE_THRESHOLD=-25dB SILENCE_DURATION=1.0 ./detect-silence.sh video.mp4
```

**Extract screenshot frames for review**:
```bash
./detect-silence.sh video.mp4 -F
# Creates: video_silence_output/
#   ├── silence_video.csv
#   └── frames/
#       ├── silence_00-01-23-450_start.jpg
#       ├── silence_00-01-23-450_end.jpg
#       ├── silence_00-05-42-100_start.jpg
#       └── silence_00-05-42-100_end.jpg
```

**Extract video clips of silent periods**:
```bash
./detect-silence.sh video.mp4 -V
# Creates: video_silence_output/
#   ├── silence_video.csv
#   └── videos/
#       ├── silence_00-01-23-450.mp4
#       ├── silence_00-05-42-100.mp4
#       └── ...
```

**Both frames and videos**:
```bash
./detect-silence.sh video.mp4 -F -V -t -45dB
```

**Use existing CSV to extract frames (skip re-analysis)**:
```bash
# First run: analyze and generate CSV
./detect-silence.sh video.mp4 -t -45dB

# Later: use CSV to extract frames without re-analyzing
./detect-silence.sh video.mp4 --from-csv silence_video.csv -F
```

**Two-step workflow for fine-tuning**:
```bash
# Step 1: Experiment with thresholds, just generate CSV
./detect-silence.sh video.mp4 -t -40dB
# Review CSV, adjust if needed
./detect-silence.sh video.mp4 -t -45dB

# Step 2: Once satisfied, extract visual previews
./detect-silence.sh video.mp4 -c silence_video.csv -F -V
```

### Threshold Guide

| Threshold | Use Case |
|-----------|----------|
| **-20dB** | Very sensitive - catches almost everything, including quiet breathing |
| **-25dB** | Moderate - good for noisy recordings or finding quieter sections |
| **-30dB** | Default - balanced for most videos, catches meaningful silence |
| **-40dB** | Conservative - only truly silent parts |
| **-45dB** | Recommended for videos with background noise at -39dB |
| **-50dB** | Strict - nearly absolute silence only |

**Note**: When audio in your video editor shows background noise at -39dB and true silence at -48dB or lower, use `-45dB` threshold to effectively distinguish between the two.

### Output Formats

#### CSV Format

```csv
Start,End,Duration,Start (seconds),End (seconds),Duration (seconds)
00:01:23.450,00:01:25.320,00:00:01.870,83.450,85.320,1.870
00:05:42.100,00:05:43.500,00:00:01.400,342.100,343.500,1.400
```

#### Plain Text Format

```
==========================================
Silence Detection Report
==========================================
Video:      video.mp4
Threshold:  -30dB
Min Duration: 0.5s
Date:       2026-01-28 15:30:45
==========================================

Found 15 silent period(s):

  1. Start: 00:01:23.450  End: 00:01:25.320  Duration: 00:00:01.870
  ...

==========================================
Total silence duration: 00:00:28.150
==========================================
```

#### JSON Format

```json
{
  "video": "video.mp4",
  "threshold": "-30dB",
  "minDuration": 0.5,
  "silentPeriods": [
    {
      "index": 1,
      "start": "00:01:23.450",
      "end": "00:01:25.320",
      "duration": "00:00:01.870",
      "startSeconds": 83.450,
      "endSeconds": 85.320,
      "durationSeconds": 1.870
    }
  ],
  "totalSilenceDuration": "00:00:28.150",
  "totalSilenceSeconds": 28.150
}
```

### Exit Codes

- `0` - Success
- `1` - Error (file not found, invalid arguments, ffmpeg not installed)

---

## video-ocr.sh

A powerful OCR (Optical Character Recognition) pipeline for searching text patterns in videos. The script extracts frames from a video, performs OCR on each frame using GNU parallel, searches for specified text patterns, and outputs timestamps where the text appears.

### Features

- **Frame Extraction**: Extract frames from video at configurable frame rates
- **OCR Processing**: Uses Tesseract OCR with customizable language and PSM modes
- **Parallel Processing**: Uses GNU parallel for multi-core OCR — significantly faster on large videos
- **Pattern Matching**: Search for multiple text patterns using regex (pipe-separated)
- **Time Range Support**: Process only specific segments of a video
- **Deduplication**: Automatically removes duplicate hits within a configurable threshold
- **Matched Frames Only**: Option to keep only frames where text matches were found
- **Clip Extraction**: Extract video clips around each OCR match with configurable padding
- **Resume Mode**: Skip frame extraction and use existing frames for faster re-runs
- **Clean Output**: Auto-generates timestamped output filenames to prevent overwrites
- **Progress Tracking**: Shows progress for frame extraction and OCR processing

### Prerequisites

- `ffmpeg`
- `tesseract`
- `parallel` (required — install via `brew install parallel`)

### Usage

```bash
./video-ocr.sh <video_file> [options]
```

#### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-f, --fps <num>` | Frames per second to extract | 2 |
| `-s, --search <terms>` | Search terms (pipe-separated, required) | - |
| `-l, --language <lang>` | Tesseract OCR language | eng |
| `-p, --psm <mode>` | Tesseract Page Segmentation Mode | 6 |
| `-d, --dedup <seconds>` | Deduplication threshold | 1 |
| `-o, --output <file>` | Output filename | auto-generated |
| `--clean` | Remove intermediate files after completion | keep files |
| `--keep-matched-frames` | Keep only frames with OCR matches | false |
| `--extract-clips` | Extract video clips around each OCR match | false |
| `--clip-before <seconds>` | Seconds before match to include in clip | 2 |
| `--clip-after <seconds>` | Seconds after match to include in clip | 2 |
| `--clips-dir <directory>` | Output directory for clips | clips/ |
| `--clip-format <format>` | Clip format: mp4, webm, mov | mp4 |
| `--start <time>` | Start time (HH:MM:SS or seconds) | beginning |
| `--end <time>` | End time (HH:MM:SS or seconds) | end |
| `--resume` | Use existing frames (skip extraction) | false |
| `--no-clean` | Don't clean existing frames before starting | clean first |
| `-h, --help` | Show help message | - |

### Examples

**Basic usage** - Search for "signature" or "takedown":
```bash
./video-ocr.sh video.mp4 -s "signature|takedown"
```

**Custom frame rate and output**:
```bash
./video-ocr.sh video.mp4 -f 1 -s "error|warning" -o results.txt
```

**Time range** - Process only a specific segment:
```bash
./video-ocr.sh video.mp4 -s "crash" --start 00:05:00 --end 00:10:00
```

**Resume mode** - Reuse existing frames with a different pattern:
```bash
./video-ocr.sh video.mp4 -s "text" --resume
```

**Keep only matched frames**:
```bash
./video-ocr.sh video.mp4 -s "error|warning" --keep-matched-frames
```

**Extract video clips around each match**:
```bash
./video-ocr.sh video.mp4 -s "signature" --extract-clips
```

**Custom clip timing**:
```bash
./video-ocr.sh video.mp4 -s "takedown" --extract-clips --clip-before 5 --clip-after 3
```

### Output Structure

```
video_ocr_output/
├── video_2026-01-30_14-25-00.txt    # Timestamps of matches
├── frames/                           # All extracted frames
├── ocr/                             # OCR text files
├── matched_frames/                  # Only frames with matches (if --keep-matched-frames)
└── clips/                           # Video clips (if --extract-clips)
    ├── clip_00-01-23.mp4
    └── clip_00-05-42.mp4
```

### Tesseract PSM Modes

| Mode | Description |
|------|-------------|
| `3` | Fully automatic page segmentation |
| `4` | Single column of text |
| `6` | Single uniform block of text (default) |
| `7` | Single text line |
| `11` | Sparse text |

### Exit Codes

- `0` - Success (even if no matches found)
- `1` - Error (missing dependencies, file not found, invalid arguments)
- `130` - Interrupted by user (Ctrl+C)