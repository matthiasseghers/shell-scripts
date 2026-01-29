#!/bin/bash

# =========================================
# Video OCR Pipeline
# Extract frames from video and search for text patterns using OCR
# =========================================

set -eo pipefail # Exit on errors and pipe failures (but allow interrupts)

# Trap Ctrl+C to clean up gracefully
trap 'echo ""; echo "⚠️  Interrupted by user. Cleaning up..."; cleanup_and_exit' INT

# Temp files (will be set after mktemp)
HITS_FILE=""
TIMESTAMPS_FILE=""

cleanup_and_exit() {
  if [[ "$KEEP_INTERMEDIATES" == "false" ]]; then
    rm -rf "$FRAMES_DIR" "$OCR_DIR"
  fi
  [[ -n "$HITS_FILE" ]] && rm -f "$HITS_FILE"
  [[ -n "$TIMESTAMPS_FILE" ]] && rm -f "$TIMESTAMPS_FILE"
  exit 130
}

# -----------------------------
# Dependency Check
# -----------------------------
check_dependencies() {
  local missing=()

  command -v ffmpeg >/dev/null 2>&1 || missing+=("ffmpeg")
  command -v ffprobe >/dev/null 2>&1 || missing+=("ffprobe")
  command -v tesseract >/dev/null 2>&1 || missing+=("tesseract")
  command -v grep >/dev/null 2>&1 || missing+=("grep")
  command -v awk >/dev/null 2>&1 || missing+=("awk")
  command -v sed >/dev/null 2>&1 || missing+=("sed")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Error: Missing required dependencies:"
    for tool in "${missing[@]}"; do
      echo "   - $tool"
    done
    echo ""
    echo "Please install missing tools:"
    [[ " ${missing[*]} " =~ " ffmpeg " ]] || [[ " ${missing[*]} " =~ " ffprobe " ]] &&
      echo "  • ffmpeg & ffprobe: brew install ffmpeg"
    [[ " ${missing[*]} " =~ " tesseract " ]] &&
      echo "  • tesseract: brew install tesseract"
    exit 1
  fi
}

# -----------------------------
# Helper Functions
# -----------------------------
# Convert HH:MM:SS or seconds to seconds
time_to_seconds() {
  local time="$1"
  if [[ "$time" =~ ^[0-9]+$ ]]; then
    echo "$time"
  else
    awk -v t="$time" 'BEGIN {split(t,a,":"); print a[1]*3600+a[2]*60+a[3]}'
  fi
}

# Convert seconds to HH:MM:SS format
seconds_to_time() {
  local seconds="$1"
  awk -v d="$seconds" 'BEGIN {h=int(d/3600); m=int((d%3600)/60); s=int(d%60); printf "%02d:%02d:%02d", h, m, s}'
}

# -----------------------------
# Configuration Section
# -----------------------------
FPS="${FPS:-2}"                                     # Frames per second (default: 2)
SEARCH_TERMS="${SEARCH_TERMS:-}"                    # Terms to search (pipe-separated)
PSM_MODE="${PSM_MODE:-6}"                           # Tesseract PSM mode (default: 6)
LANGUAGE="${LANGUAGE:-eng}"                         # OCR language (default: eng)
DEDUP_THRESHOLD="${DEDUP_THRESHOLD:-1}"             # Seconds gap to consider unique (default: 1)
FRAMES_DIR="${FRAMES_DIR:-frames}"                  # Output directory for frames
OCR_DIR="${OCR_DIR:-ocr}"                           # Output directory for OCR results
OUTPUT_FILE="${OUTPUT_FILE:-}"                      # Output file name (auto-generated if not set)
KEEP_INTERMEDIATES="${KEEP_INTERMEDIATES:-true}"    # Keep frames/ocr dirs after completion (default: true)
KEEP_MATCHED_FRAMES="${KEEP_MATCHED_FRAMES:-false}" # Keep only frames with matches (default: false)
START_TIME="${START_TIME:-}"                        # Start time (HH:MM:SS or seconds)
END_TIME="${END_TIME:-}"                            # End time (HH:MM:SS or seconds)
CLEAN_START="${CLEAN_START:-true}"                  # Clean existing frames/OCR before starting
EXTRACT_CLIPS="${EXTRACT_CLIPS:-false}"             # Extract video clips around matches (default: false)
CLIP_BEFORE="${CLIP_BEFORE:-2}"                     # Seconds before match (default: 2)
CLIP_AFTER="${CLIP_AFTER:-2}"                       # Seconds after match (default: 2)
CLIPS_DIR="${CLIPS_DIR:-clips}"                     # Output directory for clips (default: clips)
CLIP_FORMAT="${CLIP_FORMAT:-mp4}"                   # Clip output format (default: mp4)

# -----------------------------
# Parse Arguments
# -----------------------------
usage() {
  local exit_code=${1:-0}
  cat <<EOF
Usage: $0 <video_file> [options]

Options:
  -f, --fps <num>          Frames per second (default: 2)
  -s, --search <terms>     Search terms, pipe-separated (required)
  -l, --language <lang>    OCR language (default: eng)
  -p, --psm <mode>         Tesseract PSM mode (default: 6)
  -d, --dedup <seconds>    Deduplication threshold in seconds (default: 1)
  -o, --output <file>      Output file name (default: auto-generated with time range/timestamp)
  --clean                  Remove intermediate frames and OCR files after completion
  --keep-matched-frames    Keep only frames that had OCR matches (saves to matched_frames/)
  --extract-clips          Extract video clips around each OCR match
  --clip-before <seconds>  Seconds before match to include in clip (default: 2)
  --clip-after <seconds>   Seconds after match to include in clip (default: 2)
  --clips-dir <directory>  Output directory for clips (default: clips/)
  --clip-format <format>   Clip format: mp4, webm, mov (default: mp4)
  --start <time>           Start time (HH:MM:SS or seconds, e.g., 00:05:30 or 330)
  --end <time>             End time (HH:MM:SS or seconds)
  --resume                 Resume from existing frames (skip extraction if frames exist)
  --no-clean               Don't clean existing frames/OCR before starting
  -h, --help               Show this help message

Environment Variables:
  You can also set: FPS, SEARCH_TERMS, LANGUAGE, PSM_MODE, DEDUP_THRESHOLD,
  FRAMES_DIR, OCR_DIR, OUTPUT_FILE, KEEP_INTERMEDIATES, KEEP_MATCHED_FRAMES,
  START_TIME, END_TIME, CLEAN_START, EXTRACT_CLIPS, CLIP_BEFORE, CLIP_AFTER,
  CLIPS_DIR, CLIP_FORMAT

Examples:
  $0 video.mp4 -s "signature|takedown"
  $0 video.mp4 -f 1 -s "error|warning" -o results.txt
  $0 video.mp4 -s "crash" --start 00:05:00 --end 00:10:00
  $0 video.mp4 -s "loading" --start 300 --end 600 --clean
  $0 video.mp4 -s "text" --resume         # Skip frame extraction, use existing frames
  $0 video.mp4 -s "pattern" --no-clean    # Keep and overwrite existing frames
  $0 video.mp4 -s "error" --keep-matched-frames  # Save only frames with matches
  $0 video.mp4 -s "takedown" --extract-clips --clip-before 5 --clip-after 3
  $0 video.mp4 -s "signature" --extract-clips --keep-matched-frames
  FPS=4 SEARCH_TERMS="crash" $0 video.mp4

Output Files:
  By default, output filenames are auto-generated to prevent overwrites:
  - With time range: video_00-05-00_to_00-10-00.txt
  - Without time range: video_2026-01-28_14-30-45.txt
  Use -o/--output to specify a custom filename.
EOF
  exit $exit_code
}

VIDEO=""
RESUME_MODE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -f | --fps)
      FPS="$2"
      shift 2
      ;;
    -s | --search)
      SEARCH_TERMS="$2"
      shift 2
      ;;
    -l | --language)
      LANGUAGE="$2"
      shift 2
      ;;
    -p | --psm)
      PSM_MODE="$2"
      shift 2
      ;;
    -d | --dedup)
      DEDUP_THRESHOLD="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --clean)
      KEEP_INTERMEDIATES=false
      shift
      ;;
    --keep-matched-frames)
      KEEP_MATCHED_FRAMES=true
      shift
      ;;
    --extract-clips)
      EXTRACT_CLIPS=true
      shift
      ;;
    --clip-before)
      CLIP_BEFORE="$2"
      CLIP_BEFORE_SET=true
      shift 2
      ;;
    --clip-after)
      CLIP_AFTER="$2"
      CLIP_AFTER_SET=true
      shift 2
      ;;
    --clips-dir)
      CLIPS_DIR="$2"
      shift 2
      ;;
    --clip-format)
      CLIP_FORMAT="$2"
      shift 2
      ;;
    --start)
      START_TIME="$2"
      shift 2
      ;;
    --end)
      END_TIME="$2"
      shift 2
      ;;
    --resume)
      RESUME_MODE=true
      shift
      ;;
    --no-clean)
      CLEAN_START=false
      shift
      ;;
    -h | --help) usage 0 ;;
    -*)
      echo "Unknown option: $1"
      usage 1
      ;;
    *)
      VIDEO="$1"
      shift
      ;;
  esac
done

if [[ -z "$VIDEO" ]]; then
  echo "❌ Error: No video file specified"
  usage 1
fi

if [[ ! -f "$VIDEO" ]]; then
  echo "❌ Error: Video file not found: $VIDEO"
  exit 1
fi

if [[ -z "$SEARCH_TERMS" ]]; then
  echo "❌ Error: No search terms specified. Use -s/--search or set SEARCH_TERMS environment variable"
  usage 1
fi

# -----------------------------
# Validate Input Parameters
# -----------------------------
validate_positive_number() {
  local value="$1"
  local name="$2"
  if ! [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] || [[ $(awk -v v="$value" 'BEGIN {print (v <= 0)}') -eq 1 ]]; then
    echo "❌ Error: $name must be a positive number, got: $value"
    exit 1
  fi
}

validate_non_negative_integer() {
  local value="$1"
  local name="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "❌ Error: $name must be a non-negative integer, got: $value"
    exit 1
  fi
}

# Validate numeric parameters
validate_positive_number "$FPS" "FPS"
validate_non_negative_integer "$PSM_MODE" "PSM mode"
validate_positive_number "$DEDUP_THRESHOLD" "Deduplication threshold"
validate_positive_number "$CLIP_BEFORE" "Clip before duration"
validate_positive_number "$CLIP_AFTER" "Clip after duration"

# Validate PSM mode range (0-13 for Tesseract)
if [[ $PSM_MODE -lt 0 ]] || [[ $PSM_MODE -gt 13 ]]; then
  echo "❌ Error: PSM mode must be between 0 and 13, got: $PSM_MODE"
  exit 1
fi

# Validate clip format
case "$CLIP_FORMAT" in
  mp4 | webm | mov) ;;
  *)
    echo "❌ Error: Invalid clip format '$CLIP_FORMAT'. Supported: mp4, webm, mov"
    exit 1
    ;;
esac

# Validate time formats if provided
validate_time_format() {
  local time="$1"
  local name="$2"
  if [[ -n "$time" ]]; then
    # Check if it's seconds (just digits) or HH:MM:SS format
    if ! [[ "$time" =~ ^[0-9]+$ ]] && ! [[ "$time" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
      echo "❌ Error: $name must be in HH:MM:SS format or seconds, got: $time"
      exit 1
    fi
  fi
}

validate_time_format "$START_TIME" "Start time"
validate_time_format "$END_TIME" "End time"

# Auto-set CLEAN_START=false when in resume mode
if [[ "$RESUME_MODE" == "true" ]] && [[ "$CLEAN_START" == "true" ]]; then
  echo "⚠️  Note: --resume mode enabled, automatically disabling cleanup to preserve existing frames"
  CLEAN_START=false
fi

# Ask user if they want to enable clip extraction when duration flags are set
if [[ "$EXTRACT_CLIPS" == "false" ]] && { [[ -n "${CLIP_BEFORE_SET:-}" ]] || [[ -n "${CLIP_AFTER_SET:-}" ]]; }; then
  echo "⚠️  You specified --clip-before and/or --clip-after but didn't enable --extract-clips."
  echo "   Clip extraction is currently disabled, so these settings will be ignored."
  echo ""
  read -p "   Do you want to enable clip extraction? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    EXTRACT_CLIPS=true
    echo "✅ Clip extraction enabled (${CLIP_BEFORE}s before + ${CLIP_AFTER}s after each match)"
    echo ""
  else
    echo "⏭️  Continuing without clip extraction..."
    echo ""
  fi
fi

# Check for required dependencies
check_dependencies

# Auto-generate output filename if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
  # Use video filename base for output
  VIDEO_BASE=$(basename "$VIDEO" | sed 's/\.[^.]*$//')
  if [[ -n "$START_TIME" ]] && [[ -n "$END_TIME" ]]; then
    # Format time range for filename
    START_FMT=$(echo "$START_TIME" | tr ':' '-')
    END_FMT=$(echo "$END_TIME" | tr ':' '-')
    OUTPUT_FILE="${VIDEO_BASE}_${START_FMT}_to_${END_FMT}.txt"
  else
    # Use timestamp
    OUTPUT_FILE="${VIDEO_BASE}_$(date +%Y-%m-%d_%H-%M-%S).txt"
  fi
fi

# Create temporary files
HITS_FILE=$(mktemp)
TIMESTAMPS_FILE=$(mktemp)

# -----------------------------
# Display Configuration
# -----------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 OCR Pipeline Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Video:          $VIDEO"
[[ -n "$START_TIME" ]] && echo "Start time:     $START_TIME"
[[ -n "$END_TIME" ]] && echo "End time:       $END_TIME"
echo "FPS:            $FPS"
echo "Search terms:   $SEARCH_TERMS"
echo "OCR language:   $LANGUAGE"
echo "PSM mode:       $PSM_MODE"
echo "Dedup threshold: $DEDUP_THRESHOLD seconds"
echo "Output file:    $OUTPUT_FILE"
echo "Keep files:     $KEEP_INTERMEDIATES"
[[ "$KEEP_MATCHED_FRAMES" == "true" ]] && echo "Matched frames: Will be saved to matched_frames/"
[[ "$EXTRACT_CLIPS" == "true" ]] && echo "Extract clips:  Yes (${CLIP_BEFORE}s before + ${CLIP_AFTER}s after) → $CLIPS_DIR/"
[[ "$RESUME_MODE" == "true" ]] && echo "Mode:           Resume (skip extraction)"
[[ "$CLEAN_START" == "false" ]] && echo "Clean start:    No"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# -----------------------------
# Create directories
# -----------------------------
mkdir -p "$FRAMES_DIR" "$OCR_DIR"

# -----------------------------
# Cleanup existing files if needed
# -----------------------------
if [[ "$CLEAN_START" == "true" ]] && [[ "$RESUME_MODE" == "false" ]]; then
  EXISTING_FRAMES=$(find "$FRAMES_DIR" -name "*.png" -type f 2>/dev/null | wc -l)
  EXISTING_OCR=$(find "$OCR_DIR" -name "*.txt" -type f 2>/dev/null | wc -l)

  if [[ $EXISTING_FRAMES -gt 0 ]] || [[ $EXISTING_OCR -gt 0 ]]; then
    echo "➡ Cleaning existing intermediate files..."
    [[ $EXISTING_FRAMES -gt 0 ]] && echo "   Removing $EXISTING_FRAMES frames from $FRAMES_DIR/"
    [[ $EXISTING_OCR -gt 0 ]] && echo "   Removing $EXISTING_OCR OCR files from $OCR_DIR/"
    rm -f "$FRAMES_DIR"/*.png 2>/dev/null || true
    rm -f "$OCR_DIR"/*.txt 2>/dev/null || true
  fi
fi

# -----------------------------
# Step 1: Extract frames
# -----------------------------
# Check if frames already exist when in resume mode
EXISTING_FRAME_COUNT=$(find "$FRAMES_DIR" -name "*.png" -type f 2>/dev/null | wc -l)

if [[ "$RESUME_MODE" == "true" ]] && [[ $EXISTING_FRAME_COUNT -gt 0 ]]; then
  echo "➡ Resuming: Found $EXISTING_FRAME_COUNT existing frames, skipping extraction"
  FRAME_COUNT=$EXISTING_FRAME_COUNT
else
  echo "➡ Extracting frames at $FPS fps..."

  # Build ffmpeg command with optional start/end times
  FFMPEG_CMD="ffmpeg"
  [[ -n "$START_TIME" ]] && FFMPEG_CMD="$FFMPEG_CMD -ss $START_TIME"
  FFMPEG_CMD="$FFMPEG_CMD -i \"$VIDEO\""

  # Calculate duration if we have start/end times
  if [[ -n "$START_TIME" ]] && [[ -n "$END_TIME" ]]; then
    # Convert times to seconds
    START_SEC=$(time_to_seconds "$START_TIME")
    END_SEC=$(time_to_seconds "$END_TIME")

    EXTRACT_DURATION=$(awk -v end="$END_SEC" -v start="$START_SEC" 'BEGIN {print end - start}')
    FFMPEG_CMD="$FFMPEG_CMD -t $EXTRACT_DURATION"
  elif [[ -n "$END_TIME" ]]; then
    # Only end time specified, use -to
    FFMPEG_CMD="$FFMPEG_CMD -to $END_TIME"
  fi

  FFMPEG_CMD="$FFMPEG_CMD -vf fps=$FPS \"$FRAMES_DIR/frame_%06d.png\" -hide_banner -loglevel warning -stats"

  # Get video duration for progress estimation
  if [[ -n "$START_TIME" ]] || [[ -n "$END_TIME" ]]; then
    # For partial extraction, calculate the segment duration
    FULL_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")

    # Convert start/end times to seconds if needed
    START_SEC=0
    [[ -n "$START_TIME" ]] && START_SEC=$(time_to_seconds "$START_TIME")

    END_SEC=$FULL_DURATION
    [[ -n "$END_TIME" ]] && END_SEC=$(time_to_seconds "$END_TIME")

    DURATION=$(awk -v end="$END_SEC" -v start="$START_SEC" 'BEGIN {print end - start}')
  else
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
  fi

  EXPECTED_FRAMES=$(awk -v dur="$DURATION" -v fps="$FPS" 'BEGIN {printf "%d", dur * fps}')
  echo "   Segment duration: $(seconds_to_time "$DURATION") (~$EXPECTED_FRAMES frames expected)"

  # Run ffmpeg with progress output
  # Note: If interrupted, ffmpeg may leave partial frames - script will continue with what's available
  eval "$FFMPEG_CMD" || {
    echo ""
    echo "⚠️  FFmpeg was interrupted. Continuing with extracted frames..."
  }

  FRAME_COUNT=$(find "$FRAMES_DIR" -name "*.png" -type f 2>/dev/null | wc -l)
  echo "   Extracted $FRAME_COUNT frames"

  if [[ $FRAME_COUNT -eq 0 ]]; then
    echo "❌ Error: No frames extracted"
    exit 1
  fi
fi

# -----------------------------
# Step 2: Run OCR
# -----------------------------
echo "➡ Running OCR on frames..."

# Check if GNU parallel is available for faster processing
if command -v parallel >/dev/null 2>&1; then
  echo "   Using GNU parallel for faster processing..."
  find "$FRAMES_DIR" -name "*.png" -type f |
    parallel -j+0 --bar "tesseract {} $OCR_DIR/{/.} -l $LANGUAGE --psm $PSM_MODE 2>&1 | grep -v 'Tesseract Open Source' | grep -v '^$' || true"
  PROCESSED=$FRAME_COUNT
else
  # Fallback to serial processing
  PROCESSED=0
  for f in "$FRAMES_DIR"/*.png; do
    tesseract "$f" "$OCR_DIR/$(basename "$f" .png)" -l "$LANGUAGE" --psm "$PSM_MODE" 2>&1 | grep -v "Tesseract Open Source" | grep -v "^$" || true
    ((PROCESSED++))
    if ((PROCESSED % 20 == 0)); then
      echo "   Processed $PROCESSED/$FRAME_COUNT frames..."
    fi
  done
fi
echo "   Completed $PROCESSED frames"

# -----------------------------
# Step 3: Search for terms
# -----------------------------
echo "➡ Searching for terms: $SEARCH_TERMS"
grep -ril -E "$SEARCH_TERMS" "$OCR_DIR/" >"$HITS_FILE" 2>/dev/null || true

HIT_COUNT=$(wc -l <"$HITS_FILE")
echo "   Found $HIT_COUNT matching frames"

if [[ $HIT_COUNT -eq 0 ]]; then
  echo "⚠️  No matches found. Exiting."
  rm -f "$HITS_FILE" "$TIMESTAMPS_FILE"
  [[ "$KEEP_INTERMEDIATES" == "false" ]] && rm -rf "$FRAMES_DIR" "$OCR_DIR"
  exit 0
fi

# -----------------------------
# Save matched frames if requested
# -----------------------------
if [[ "$KEEP_MATCHED_FRAMES" == "true" ]]; then
  echo "➡ Saving matched frames..."
  MATCHED_FRAMES_DIR="matched_frames"
  mkdir -p "$MATCHED_FRAMES_DIR"

  # Extract frame names from OCR hits and copy corresponding PNG files
  while read -r ocr_file; do
    frame_name=$(basename "$ocr_file" .txt)
    frame_file="$FRAMES_DIR/${frame_name}.png"
    if [[ -f "$frame_file" ]]; then
      cp "$frame_file" "$MATCHED_FRAMES_DIR/"
    fi
  done <"$HITS_FILE"

  SAVED_COUNT=$(find "$MATCHED_FRAMES_DIR" -name "*.png" -type f 2>/dev/null | wc -l)
  echo "   Saved $SAVED_COUNT matched frames to $MATCHED_FRAMES_DIR/"
fi

# -----------------------------
# Step 4: Convert to timestamps
# -----------------------------
echo "➡ Converting frame numbers to HH:MM:SS timestamps..."
# Calculate frame interval using awk (bc may not be installed on macOS by default)
FRAME_INTERVAL=$(awk -v fps="$FPS" 'BEGIN {printf "%.6f", 1/fps}')

# Calculate offset if start time was specified
OFFSET_SECONDS=0
[[ -n "$START_TIME" ]] && OFFSET_SECONDS=$(time_to_seconds "$START_TIME")

while read -r f; do
  n=$(basename "$f" .txt | sed 's/frame_0*//')
  # Use awk instead of bc for better macOS compatibility, add offset for start time
  timestamp=$(awk -v n="$n" -v interval="$FRAME_INTERVAL" -v offset="$OFFSET_SECONDS" 'BEGIN {
        seconds = n * interval + offset
        h = int(seconds/3600)
        m = int((seconds%3600)/60)
        s = int(seconds%60)
        printf "%02d:%02d:%02d\n", h, m, s
    }')
  echo "$timestamp" >>"$TIMESTAMPS_FILE"
done <"$HITS_FILE"

# -----------------------------
# Step 5: Deduplicate
# -----------------------------
echo "➡ Deduplicating timestamps (threshold: ${DEDUP_THRESHOLD}s)..."
awk -v thresh="$DEDUP_THRESHOLD" '
NR==1 {print; prev=$0; next}
{
    split($0, a, ":")
    split(prev, b, ":")
    s1 = (a[1]*3600 + a[2]*60 + a[3])
    s2 = (b[1]*3600 + b[2]*60 + b[3])
    if (s1 - s2 > thresh) print
    prev = $0
}
' "$TIMESTAMPS_FILE" >"$OUTPUT_FILE"

UNIQUE_COUNT=$(wc -l <"$OUTPUT_FILE")
echo "   $UNIQUE_COUNT unique timestamps"

# -----------------------------
# Step 6: Extract clips (if requested)
# -----------------------------
CLIP_COUNT=0
if [[ "$EXTRACT_CLIPS" == "true" ]] && [[ $UNIQUE_COUNT -gt 0 ]]; then
  echo "➡ Extracting video clips around matches..."
  mkdir -p "$CLIPS_DIR"

  # Get video duration for boundary checks
  VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")

  while read -r timestamp; do
    # Convert timestamp to seconds
    TIME_SEC=$(time_to_seconds "$timestamp")

    # Calculate clip start and end times with boundaries
    CLIP_START=$(awk -v t="$TIME_SEC" -v before="$CLIP_BEFORE" 'BEGIN {s=t-before; print (s<0)?0:s}')
    CLIP_END=$(awk -v t="$TIME_SEC" -v after="$CLIP_AFTER" -v dur="$VIDEO_DURATION" 'BEGIN {e=t+after; print (e>dur)?dur:e}')
    CLIP_DURATION=$(awk -v start="$CLIP_START" -v end="$CLIP_END" 'BEGIN {print end-start}')

    # Format timestamp for filename (replace : with -)
    TIMESTAMP_FMT=$(echo "$timestamp" | tr ':' '-')
    CLIP_FILE="$CLIPS_DIR/clip_${TIMESTAMP_FMT}.$CLIP_FORMAT"

    # Extract clip using ffmpeg with copy codec for speed (re-encode if needed)
    ffmpeg -ss "$CLIP_START" -i "$VIDEO" -t "$CLIP_DURATION" \
      -c copy -avoid_negative_ts make_zero \
      "$CLIP_FILE" -hide_banner -loglevel error 2>&1 || {
      # Fallback to re-encoding if copy fails
      ffmpeg -ss "$CLIP_START" -i "$VIDEO" -t "$CLIP_DURATION" \
        "$CLIP_FILE" -hide_banner -loglevel error 2>&1
    }

    if [[ -f "$CLIP_FILE" ]]; then
      ((CLIP_COUNT++))
      echo "   Extracted clip $CLIP_COUNT/$UNIQUE_COUNT: $CLIP_FILE"
    fi
  done <"$OUTPUT_FILE"

  echo "   Saved $CLIP_COUNT clips to $CLIPS_DIR/"
fi

# -----------------------------
# Cleanup
# -----------------------------
rm -f "$HITS_FILE" "$TIMESTAMPS_FILE"

if [[ "$KEEP_INTERMEDIATES" == "false" ]]; then
  echo "➡ Cleaning up intermediate files..."
  rm -rf "$FRAMES_DIR" "$OCR_DIR"
elif [[ "$KEEP_MATCHED_FRAMES" == "true" ]]; then
  echo "➡ Cleaning up non-matching frames..."
  # Remove all frames and OCR files, keeping only the matched_frames directory
  rm -rf "$FRAMES_DIR" "$OCR_DIR"
  echo "   Matched frames preserved in matched_frames/"
else
  echo "➡ Keeping intermediate files in $FRAMES_DIR/ and $OCR_DIR/"
fi

# -----------------------------
# Summary
# -----------------------------
echo ""
echo "✅ Pipeline complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results saved to: $OUTPUT_FILE"
echo "Total unique timestamps: $UNIQUE_COUNT"
if [[ "$KEEP_MATCHED_FRAMES" == "true" ]]; then
  echo "Matched frames: matched_frames/ ($SAVED_COUNT frames)"
fi
if [[ "$EXTRACT_CLIPS" == "true" ]] && [[ $CLIP_COUNT -gt 0 ]]; then
  echo "Video clips: $CLIPS_DIR/ ($CLIP_COUNT clips)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
