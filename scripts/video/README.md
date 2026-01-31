# Video Scripts

This directory contains scripts for video processing and editing tasks.

## Contents

- **video-ocr.sh** - OCR pipeline for searching text in videos
- **detect-silence.sh** - Detect silent parts in videos for easier editing
- **fcp/** - Final Cut Pro specific scripts (see [fcp/README.md](fcp/README.md))

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

```bash
# macOS installation
brew install ffmpeg
```

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

Comma-separated values, perfect for spreadsheets or further analysis:

```csv
Start,End,Duration,Start (seconds),End (seconds),Duration (seconds)
00:01:23.450,00:01:25.320,00:00:01.870,83.450,85.320,1.870
00:05:42.100,00:05:43.500,00:00:01.400,342.100,343.500,1.400
```

#### Plain Text Format

Human-readable report with summary:

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
  2. Start: 00:05:42.100  End: 00:05:43.500  Duration: 00:00:01.400
  ...

==========================================
Total silence duration: 00:00:28.150
==========================================
```

#### JSON Format

Structured data for programmatic processing:

```json
{
  "video": "video.mp4",
  "threshold": "-30dB",
  "minDuration": 0.5,
  "date": "2026-01-28T15:30:45Z",
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

### Common Use Cases

**1. Edit Detection for Interviews/Podcasts**
```bash
./detect-silence.sh podcast.mp4 -t -35dB -d 1.0
```
Find natural break points longer than 1 second.

**2. Remove Dead Air from Screencasts**
```bash
./detect-silence.sh screencast.mp4 -t -40dB -d 0.5 -F
```
Identify pauses that could be trimmed, with visual previews in `screencast_silence_output/frames/`.

**3. Visual Review Before Editing**
```bash
./detect-silence.sh video.mp4 -t -45dB -F
# Check generated screenshots in video_silence_output/frames/
# Verify which silences are worth removing
```

**4. Quality Check Recordings**
```bash
./detect-silence.sh recording.mp4 -t -30dB -f txt
```
Verify audio is present throughout the video.

**5. Batch Processing Multiple Videos**
```bash
for video in *.mp4; do
    ./detect-silence.sh "$video" -f csv -F
done
```

**6. Preview Clips Before Committing to Edits**
```bash
./detect-silence.sh video.mp4 -t -45dB -V
# Review clips in video_silence_output/videos/ directory
# Decide which sections to actually edit out
```

**7. Integration with Editing Software**
```bash
./detect-silence.sh video.mp4 -f json | jq '.silentPeriods[].start'
```
Extract timestamps for automated editing workflows.

### Tips

1. **Start with defaults**: The default -30dB threshold works well for most content

2. **Adjust for noisy environments**: Use -35dB or -40dB for recordings with background noise

3. **Filter short silences**: Increase `-d` to ignore brief pauses between words

4. **Use frames for quick preview**: `-F` flag generates screenshots to verify before committing to edits

5. **Two-step workflow**: Generate CSV first, review it, then use `-c` to extract frames/videos without re-analyzing

6. **CSV for spreadsheets**: Use CSV format to sort, filter, and analyze in Excel/Numbers

7. **JSON for automation**: Use JSON format for scripting or integration with other tools

8. **Preview clips for accuracy**: Use `-V` to generate actual video clips when you need to see/hear context

9. **Distinguish background noise**: If your editor shows background noise at -39dB and silence at -48dB, use `-t -45dB`

10. **Combine with video-ocr.sh**: Use both scripts to find editing points (silence + text changes)

### Environment Variables

All options can be set via environment variables:

- `SILENCE_THRESHOLD` - Silence threshold (e.g., "-30dB")
- `SILENCE_DURATION` - Minimum duration in seconds (e.g., "0.5")
- `OUTPUT_FORMAT` - Output format: csv, txt, or json

### Workflow Example

**Basic Workflow** - Quick detection:
```bash
# 1. Detect silences
./detect-silence.sh interview.mp4 -t -35dB -d 1.0 -f csv

# 2. Open CSV in spreadsheet
open silence_interview.csv

# 3. Review and mark sections to edit out

# 4. Use timestamps in your video editor
# Import markers or manually jump to timestamps
```

**Advanced Workflow** - Visual verification:
```bash
# 1. First pass: Generate CSV and screenshots
./detect-silence.sh interview.mp4 -t -45dB -d 1.0 -F

# 2. Review screenshots in Finder/file browser
open interview_silence_output/frames/

# 3. Identify which silences to keep/remove

# 4. Optionally generate video clips for closer inspection
./detect-silence.sh interview.mp4 -c interview_silence_output/silence_interview.csv -V

# 5. Review video clips
open interview_silence_output/videos/

# 6. Use CSV timestamps in your video editor to make cuts
```

**Iterative Workflow** - Fine-tune settings:
```bash
# 1. Quick test with different thresholds
./detect-silence.sh video.mp4 -t -40dB  # Check count
./detect-silence.sh video.mp4 -t -45dB  # Adjust if needed

# 2. Once satisfied, generate previews from best CSV
./detect-silence.sh video.mp4 -c silence_video.csv -F -V

# 3. Verify previews and proceed with editing
```

### Troubleshooting

**No silences detected**:
- Try a less strict threshold (e.g., -25dB instead of -30dB)
- Reduce minimum duration (e.g., 0.3 instead of 0.5)
- Check if video actually has audio (`ffmpeg -i video.mp4` will show streams)

**Too many silences detected**:
- Use a stricter threshold (e.g., -40dB)
- Increase minimum duration (e.g., 1.0 or 2.0 seconds)

**Processing takes too long**:
- This is normal for long videos - ffmpeg must analyze the entire file
- Consider processing a shorter clip first to test settings
- Monitor progress via ffmpeg's real-time output

**False positives in noisy recordings**:
- Use stricter threshold (-40dB or -50dB)
- Some background noise may be detected as silence with default settings
- Use `-F` to generate screenshots and visually verify what's being detected

**Output directories not created**:
- Directories are only created when using `-F` or `-V` flags
- Check that you have write permissions in the current directory

**Frames/videos not extracting from CSV**:
- Ensure CSV format matches expected structure (6 columns with headers)
- Video file must still be present and accessible
- Use `-f csv` when generating the initial report

### Integration with Video Editors

**Final Cut Pro**: 
- Use CSV data to create markers at silence points
- Review generated screenshots to decide which sections to cut

**DaVinci Resolve**: 
- Import CSV as EDL markers for automated editing
- Use video clips to preview context before making cuts

**Premiere Pro**: 
- Convert timestamps to markers using scripts or extensions
- Import frames as reference images alongside timeline

**Workflow Tip**: Generate frames first (`-F`), review them in your file browser, then manually navigate to those timestamps in your editor for precise cuts.

### Exit Codes

- `0` - Success
- `1` - Error (file not found, invalid arguments, ffmpeg not installed)

---

## video-ocr.sh

A powerful OCR (Optical Character Recognition) pipeline for searching text patterns in videos. The script extracts frames from a video, performs OCR on each frame, searches for specified text patterns, and outputs timestamps where the text appears.

### Features

- **Frame Extraction**: Extract frames from video at configurable frame rates
- **OCR Processing**: Uses Tesseract OCR with customizable language and PSM modes
- **Pattern Matching**: Search for multiple text patterns using regex (pipe-separated)
- **Time Range Support**: Process only specific segments of a video
- **Deduplication**: Automatically removes duplicate hits within a configurable threshold
- **Matched Frames Only**: Option to keep only frames where text matches were found
- **Clip Extraction**: Extract video clips around each OCR match with configurable padding
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

**Keep only matched frames** - Save frames where text was found:
```bash
./video-ocr.sh video.mp4 -s "error|warning" --keep-matched-frames
# Creates video_output/matched_frames/ directory with only frames containing matches
```

**Extract video clips** - Get video segments around each match:
```bash
./video-ocr.sh video.mp4 -s "signature" --extract-clips
# Creates video_output/clips/ directory with 4-second clips (2s before + 2s after each match)
```

**Custom clip timing** - More context before/after matches:
```bash
./video-ocr.sh video.mp4 -s "takedown" --extract-clips --clip-before 5 --clip-after 3
# Each clip includes 5 seconds before and 3 seconds after the match
```

**Both screenshots and clips** - Visual verification options:
```bash
./video-ocr.sh video.mp4 -s "error" --keep-matched-frames --extract-clips
# Creates both video_output/matched_frames/ (screenshots) and video_output/clips/ (video segments)
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

The script generates all output in a video-specific directory (default: `<video_name>_ocr_output/`):

1. **Timestamps file** (default or specified with `-o`):
   - Auto-generated filenames include time range or timestamp
   - Format: `video_00-05-00_to_00-10-00.txt` or `video_2026-01-28_14-30-45.txt`
   - Contains deduplicated timestamps in HH:MM:SS format
   - Located in: `<video_name>_ocr_output/`

2. **Intermediate directories** (kept by default):
   - `<video_name>_ocr_output/frames/` - Extracted frame images (PNG)
   - `<video_name>_ocr_output/ocr/` - OCR text output files (TXT)
   - Use `--clean` to remove after completion

3. **Matched frames directory** (when using `--keep-matched-frames`):
   - `<video_name>_ocr_output/matched_frames/` - Only frames where text matches were found
   - Perfect for visual verification of OCR results
   - Automatically cleans up non-matching frames

4. **Video clips directory** (when using `--extract-clips`):
   - `<video_name>_ocr_output/clips/` (or custom directory) - Video segments around each match
   - Clips named by timestamp: `clip_HH-MM-SS.mp4`
   - Includes configurable padding before/after the match
   - Fast extraction using codec copy when possible

**Example output structure:**
```
video_ocr_output/
├── video_2026-01-30_14-25-00.txt    # Timestamps of matches
├── frames/                           # All extracted frames
│   ├── frame_00001.png
│   ├── frame_00002.png
│   └── ...
├── ocr/                             # OCR text files
│   ├── frame_00001.txt
│   ├── frame_00002.txt
│   └── ...
├── matched_frames/                  # Only frames with matches (if --keep-matched-frames)
│   └── frame_00042.png
└── clips/                           # Video clips (if --extract-clips)
    ├── clip_00-01-23.mp4
    └── clip_00-05-42.mp4
```

### Environment Variables

All options can be set via environment variables:

- `FPS` - Frames per second
- `SEARCH_TERMS` - Search terms (pipe-separated)
- `LANGUAGE` - OCR language
- `PSM_MODE` - Tesseract PSM mode
- `DEDUP_THRESHOLD` - Deduplication threshold in seconds
- `OUTPUT_DIR` - Parent output directory (default: `<video_name>_ocr_output`)
- `FRAMES_DIR` - Frames subdirectory name (default: `frames`, relative to OUTPUT_DIR)
- `OCR_DIR` - OCR subdirectory name (default: `ocr`, relative to OUTPUT_DIR)
- `OUTPUT_FILE` - Output filename
- `KEEP_INTERMEDIATES` - Keep intermediate files (default: `true`)
- `KEEP_MATCHED_FRAMES` - Keep only matched frames (default: `false`)
- `EXTRACT_CLIPS` - Extract video clips around matches (default: `false`)
- `CLIP_BEFORE` - Seconds before match in clips (default: `2`)
- `CLIP_AFTER` - Seconds after match in clips (default: `2`)
- `CLIPS_DIR` - Clips subdirectory name (default: `clips`, relative to OUTPUT_DIR)
- `CLIP_FORMAT` - Clip format: mp4, webm, mov (default: `mp4`)
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

6. **Visual verification of matches**: Use `--keep-matched-frames` to review what the OCR actually detected:
   ```bash
   ./video-ocr.sh video.mp4 -s "pattern" --keep-matched-frames
   open video_ocr_output/matched_frames/  # Review frames with matches
   ```

7. **Save space with matched frames**: When processing large videos, keep only relevant frames:
   ```bash
   ./video-ocr.sh long_video.mp4 -f 2 -s "error" --keep-matched-frames
   # Only matched frames are saved, rest are deleted
   ```

8. **Context with clips**: Extract video segments to see motion and hear audio around matches:
   ```bash
   ./video-ocr.sh video.mp4 -s "pattern" --extract-clips
   # Review video_ocr_output/clips/ directory to see context around each match
   ```

9. **Adjust clip timing**: Customize padding for different use cases:
   ```bash
   # Short clips for quick review
   ./video-ocr.sh video.mp4 -s "text" --extract-clips --clip-before 1 --clip-after 1
   
   # Longer clips for full context
   ./video-ocr.sh video.mp4 -s "text" --extract-clips --clip-before 10 --clip-after 5
   ```

10. **Create highlight reels**: Extract clips of important moments automatically:
    ```bash
    ./video-ocr.sh game.mp4 -s "VICTORY|DEFEAT" --extract-clips --clip-before 3 --clip-after 2
    # All clips can be reviewed or combined into a highlight reel
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
- Use `--keep-matched-frames` with a broad search to see what OCR is detecting

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
