# Video Scripts

This directory contains scripts for video processing tasks.

## video-ocr.sh

A powerful OCR (Optical Character Recognition) pipeline for searching text patterns in videos. The script extracts frames from a video, performs OCR on each frame, searches for specified text patterns, and outputs timestamps where the text appears.

### Features

- **Frame Extraction**: Extract frames from video at configurable frame rates
- **OCR Processing**: Uses Tesseract OCR with customizable language and PSM modes
- **Pattern Matching**: Search for multiple text patterns using regex (pipe-separated)
- **Time Range Support**: Process only specific segments of a video
- **Deduplication**: Automatically removes duplicate hits within a configurable threshold
- **Resume Mode**: Skip frame extraction and use existing frames for faster re-runs
- **Parallel Processing**: Automatically uses GNU parallel if available for faster OCR
- **Clean Output**: Auto-generates timestamped output filenames to prevent overwrites
- **Progress Tracking**: Shows progress for frame extraction and OCR processing

### Prerequisites

The script requires the following tools to be installed:

```bash
# macOS installation
brew install ffmpeg tesseract

# The following are typically pre-installed:
# - grep, awk, sed
```

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

**Custom frame rate and output** - Extract 1 frame per second:
```bash
./video-ocr.sh video.mp4 -f 1 -s "error|warning" -o results.txt
```

**Time range** - Process only specific segment (5 to 10 minutes):
```bash
./video-ocr.sh video.mp4 -s "crash" --start 00:05:00 --end 00:10:00
```

**Time range with seconds** - Start at 5 minutes (300s), end at 10 minutes (600s):
```bash
./video-ocr.sh video.mp4 -s "loading" --start 300 --end 600 --clean
```

**Resume mode** - Reuse existing frames with different search pattern:
```bash
./video-ocr.sh video.mp4 -s "text" --resume
```

**Environment variables** - Configure via environment:
```bash
FPS=4 SEARCH_TERMS="crash" ./video-ocr.sh video.mp4
```

**Multiple language OCR** - Use German language model:
```bash
./video-ocr.sh video.mp4 -l deu -s "Fehler|Warnung"
```

### Output

The script generates:

1. **Timestamps file** (default or specified with `-o`):
   - Auto-generated filenames include time range or timestamp
   - Format: `video_00-05-00_to_00-10-00.txt` or `video_2026-01-28_14-30-45.txt`
   - Contains deduplicated timestamps in HH:MM:SS format

2. **Intermediate directories** (kept by default):
   - `frames/` - Extracted frame images (PNG)
   - `ocr/` - OCR text output files (TXT)
   - Use `--clean` to remove after completion

### Environment Variables

All options can be set via environment variables:

- `FPS` - Frames per second
- `SEARCH_TERMS` - Search terms (pipe-separated)
- `LANGUAGE` - OCR language
- `PSM_MODE` - Tesseract PSM mode
- `DEDUP_THRESHOLD` - Deduplication threshold in seconds
- `FRAMES_DIR` - Frames output directory (default: `frames`)
- `OCR_DIR` - OCR output directory (default: `ocr`)
- `OUTPUT_FILE` - Output filename
- `KEEP_INTERMEDIATES` - Keep intermediate files (default: `true`)
- `START_TIME` - Start time
- `END_TIME` - End time
- `CLEAN_START` - Clean existing files before starting (default: `true`)

### Tesseract PSM Modes

Common Page Segmentation Modes:

- `3` - Fully automatic page segmentation (no OSD)
- `4` - Assume a single column of text
- `6` - Assume a single uniform block of text (default)
- `7` - Treat the image as a single text line
- `11` - Sparse text. Find as much text as possible

### Tips

1. **Resume mode for iterative searching**: Extract frames once, then search multiple times with different patterns:
   ```bash
   ./video-ocr.sh video.mp4 -s "first_pattern"
   ./video-ocr.sh video.mp4 -s "second_pattern" --resume
   ./video-ocr.sh video.mp4 -s "third_pattern" --resume
   ```

2. **Higher FPS for fast-changing text**: Increase FPS if text appears briefly:
   ```bash
   ./video-ocr.sh video.mp4 -f 5 -s "quick_flash"
   ```

3. **Lower FPS for performance**: Reduce FPS for long videos with static text:
   ```bash
   ./video-ocr.sh video.mp4 -f 0.5 -s "static_text"
   ```

4. **Time ranges for long videos**: Process specific segments to save time:
   ```bash
   ./video-ocr.sh long_video.mp4 -s "pattern" --start 01:30:00 --end 02:00:00
   ```

5. **GNU parallel for speed**: Install GNU parallel for faster OCR processing:
   ```bash
   brew install parallel
   ```

### Interrupt Handling

The script handles Ctrl+C gracefully:
- Stops current processing
- Cleans up temporary files
- Preserves intermediate frames/OCR if `KEEP_INTERMEDIATES=true`

### Troubleshooting

**No matches found**:
- Verify the text appears clearly in the video
- Try different PSM modes (`-p 3`, `-p 7`, etc.)
- Increase FPS to capture more frames
- Check OCR language setting matches video language

**Slow processing**:
- Install GNU parallel for faster OCR
- Reduce FPS for long videos
- Use time ranges to process only relevant segments
- Use `--resume` mode to skip frame extraction on reruns

**Memory issues**:
- Use `--clean` to remove intermediate files
- Process video in smaller time segments
- Reduce FPS

### Exit Codes

- `0` - Success (even if no matches found)
- `1` - Error (missing dependencies, file not found, invalid arguments)
- `130` - Interrupted by user (Ctrl+C)
