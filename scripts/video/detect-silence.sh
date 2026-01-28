#!/bin/bash

# =========================================
# Video Silence Detection Script
# Detect silent parts in video files for easier editing
# =========================================

set -eo pipefail

# Default configuration
SILENCE_THRESHOLD="${SILENCE_THRESHOLD:--30dB}" # Volume threshold for silence
SILENCE_DURATION="${SILENCE_DURATION:-0.5}"     # Minimum silence duration in seconds
OUTPUT_FORMAT="${OUTPUT_FORMAT:-csv}"           # Output format: csv, txt, json
OUTPUT_FRAMES=false                             # Generate screenshot frames
OUTPUT_VIDEO=false                              # Generate video clips
FROM_CSV=""                                     # Read from existing CSV file

# Usage function
usage() {
  cat <<EOF
Usage: $0 <video_file> [options]

Detect silent parts in video files and generate a report.

Options:
  -t, --threshold <dB>     Silence threshold in dB (default: -30dB)
  -d, --duration <sec>     Minimum silence duration in seconds (default: 0.5)
  -f, --format <format>    Output format: csv, txt, json (default: csv)
  -o, --output <file>      Output filename (default: silence_<video_name>.<format>)
  -F, --output-frames      Generate screenshot frames at start/end of each silence
  -V, --output-video       Generate video clips for each silent period
  -c, --from-csv <file>    Read from existing CSV instead of analyzing video
  -h, --help               Show this help message

Environment Variables:
  SILENCE_THRESHOLD   Silence threshold (default: -30dB)
  SILENCE_DURATION    Minimum silence duration (default: 0.5)
  OUTPUT_FORMAT       Output format (default: csv)

Examples:
  # Basic detection
  $0 video.mp4
  $0 video.mp4 -t -40dB -d 1.0
  
  # With screenshot frames
  $0 video.mp4 -F
  $0 video.mp4 --output-frames -t -45dB
  
  # With video clips
  $0 video.mp4 -V
  $0 video.mp4 --output-video --output-frames
  
  # Using existing CSV (skip analysis)
  $0 video.mp4 --from-csv silence_video.csv -F
  $0 video.mp4 -c silence_video.csv -V

Threshold Guide:
  -20dB  : Very quiet (catches almost everything)
  -30dB  : Moderate silence (default, good for most videos)
  -40dB  : Only truly silent parts
  -45dB  : Very quiet parts (good for distinguishing from background noise)
  -50dB  : Nearly absolute silence

EOF
  exit 0
}

# Convert seconds to HH:MM:SS.xx format
seconds_to_timecode() {
  local seconds="$1"
  awk -v s="$seconds" 'BEGIN {
        h = int(s/3600)
        m = int((s%3600)/60)
        sec = s%60
        printf "%02d:%02d:%06.3f", h, m, sec
    }'
}

# Parse arguments
VIDEO=""
OUTPUT_FILE=""
AUTO_OUTPUT=true

while [[ $# -gt 0 ]]; do
  case $1 in
    -t | --threshold)
      SILENCE_THRESHOLD="$2"
      shift 2
      ;;
    -d | --duration)
      SILENCE_DURATION="$2"
      shift 2
      ;;
    -f | --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      AUTO_OUTPUT=false
      shift 2
      ;;
    -F | --output-frames)
      OUTPUT_FRAMES=true
      shift
      ;;
    -V | --output-video)
      OUTPUT_VIDEO=true
      shift
      ;;
    -c | --from-csv)
      FROM_CSV="$2"
      shift 2
      ;;
    -h | --help) usage ;;
    -*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      VIDEO="$1"
      shift
      ;;
  esac
done

# Validate inputs
if [[ -z "$VIDEO" ]]; then
  echo "❌ Error: No video file specified"
  usage
fi

if [[ ! -f "$VIDEO" ]]; then
  echo "❌ Error: Video file not found: $VIDEO"
  exit 1
fi

# Validate from-csv option
if [[ -n "$FROM_CSV" ]] && [[ ! -f "$FROM_CSV" ]]; then
  echo "❌ Error: CSV file not found: $FROM_CSV"
  exit 1
fi

# If using from-csv, format must be csv or will be ignored
if [[ -n "$FROM_CSV" ]] && [[ "$OUTPUT_FORMAT" != "csv" ]]; then
  echo "⚠️  Warning: --from-csv only works with CSV format, ignoring format option"
  OUTPUT_FORMAT="csv"
fi

# Validate format
if [[ ! "$OUTPUT_FORMAT" =~ ^(csv|txt|json)$ ]]; then
  echo "❌ Error: Invalid format '$OUTPUT_FORMAT'. Use: csv, txt, or json"
  exit 1
fi

# Check for ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "❌ Error: ffmpeg not found"
  echo "   Install with: brew install ffmpeg"
  exit 1
fi

# Auto-generate output filename if not specified
if [[ "$AUTO_OUTPUT" == "true" ]]; then
  VIDEO_BASE=$(basename "$VIDEO" | sed 's/\.[^.]*$//')
  OUTPUT_FILE="silence_${VIDEO_BASE}.${OUTPUT_FORMAT}"
fi

# Setup output directories for frames/videos
if [[ "$OUTPUT_FRAMES" == "true" ]]; then
  FRAMES_DIR="silence_${VIDEO_BASE}_frames"
  mkdir -p "$FRAMES_DIR"
fi

if [[ "$OUTPUT_VIDEO" == "true" ]]; then
  VIDEOS_DIR="silence_${VIDEO_BASE}_videos"
  mkdir -p "$VIDEOS_DIR"
fi

# Create temporary file for ffmpeg output
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Display configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔇 Silence Detection Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Video:           $VIDEO"
if [[ -z "$FROM_CSV" ]]; then
  echo "Threshold:       $SILENCE_THRESHOLD"
  echo "Min Duration:    ${SILENCE_DURATION}s"
else
  echo "Reading from:    $FROM_CSV"
fi
echo "Output Format:   $OUTPUT_FORMAT"
echo "Output File:     $OUTPUT_FILE"
if [[ "$OUTPUT_FRAMES" == "true" ]]; then
  echo "Frames Output:   $FRAMES_DIR/"
fi
if [[ "$OUTPUT_VIDEO" == "true" ]]; then
  echo "Videos Output:   $VIDEOS_DIR/"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Parse silence data from CSV or analyze video
SILENCE_STARTS=()
SILENCE_ENDS=()
SILENCE_DURATIONS=()

if [[ -n "$FROM_CSV" ]]; then
  # Read from existing CSV file
  echo "➡ Reading silence data from CSV..."

  # Skip header line and parse CSV
  tail -n +2 "$FROM_CSV" | while IFS=',' read -r start_tc end_tc duration_tc start_sec end_sec duration_sec; do
    SILENCE_STARTS+=("$start_sec")
    SILENCE_ENDS+=("$end_sec")
    SILENCE_DURATIONS+=("$duration_sec")
  done

  # Re-read to populate arrays (subshell issue workaround)
  mapfile -t lines < <(tail -n +2 "$FROM_CSV")
  for line in "${lines[@]}"; do
    IFS=',' read -r start_tc end_tc duration_tc start_sec end_sec duration_sec <<<"$line"
    SILENCE_STARTS+=("$start_sec")
    SILENCE_ENDS+=("$end_sec")
    SILENCE_DURATIONS+=("$duration_sec")
  done

  echo "   Loaded ${#SILENCE_ENDS[@]} silent period(s) from CSV"
else
  # Run ffmpeg with silencedetect filter
  echo "➡ Analyzing video for silent parts..."
  echo "   This may take a while depending on video length..."
  echo ""

  ffmpeg -i "$VIDEO" \
    -af "silencedetect=noise=${SILENCE_THRESHOLD}:d=${SILENCE_DURATION}" \
    -f null - 2>&1 | tee "$TEMP_FILE"

  echo ""
  echo "➡ Processing results..."

  # Parse the output and extract silence information
  while IFS= read -r line; do
    if [[ "$line" =~ silence_start:\ ([0-9.]+) ]]; then
      SILENCE_STARTS+=("${BASH_REMATCH[1]}")
    fi
    if [[ "$line" =~ silence_end:\ ([0-9.]+)\ \|\ silence_duration:\ ([0-9.]+) ]]; then
      SILENCE_ENDS+=("${BASH_REMATCH[1]}")
      SILENCE_DURATIONS+=("${BASH_REMATCH[2]}")
    fi
  done <"$TEMP_FILE"
fi

# Count silent periods
SILENCE_COUNT=${#SILENCE_ENDS[@]}

if [[ $SILENCE_COUNT -eq 0 ]]; then
  echo "⚠️  No silent periods detected"
  if [[ -z "$FROM_CSV" ]]; then
    echo "   Try adjusting the threshold (use -t with a higher value like -25dB)"
    echo "   or reducing minimum duration (use -d with a lower value like 0.3)"
  fi
  exit 0
fi

# Extract frames if requested
if [[ "$OUTPUT_FRAMES" == "true" ]]; then
  echo ""
  echo "➡ Extracting screenshot frames..."

  for i in "${!SILENCE_ENDS[@]}"; do
    start="${SILENCE_STARTS[i]}"
    end="${SILENCE_ENDS[i]}"

    # Format index with leading zeros
    idx=$(printf "%02d" $((i + 1)))

    # Extract start frame
    ffmpeg -y -ss "$start" -i "$VIDEO" -frames:v 1 -q:v 2 \
      "${FRAMES_DIR}/silence_${idx}_start.jpg" 2>/dev/null

    # Extract end frame
    ffmpeg -y -ss "$end" -i "$VIDEO" -frames:v 1 -q:v 2 \
      "${FRAMES_DIR}/silence_${idx}_end.jpg" 2>/dev/null

    echo "   ✓ Extracted frames for silence #$idx"
  done

  echo "   📸 Saved ${#SILENCE_ENDS[@]} frame pairs to: $FRAMES_DIR/"
fi

# Extract video clips if requested
if [[ "$OUTPUT_VIDEO" == "true" ]]; then
  echo ""
  echo "➡ Extracting video clips..."

  for i in "${!SILENCE_ENDS[@]}"; do
    start="${SILENCE_STARTS[i]}"
    duration="${SILENCE_DURATIONS[i]}"

    # Format index with leading zeros
    idx=$(printf "%02d" $((i + 1)))

    # Extract video clip
    ffmpeg -y -ss "$start" -i "$VIDEO" -t "$duration" \
      -c:v libx264 -preset fast -crf 23 -c:a aac \
      "${VIDEOS_DIR}/silence_${idx}.mp4" 2>/dev/null

    echo "   ✓ Extracted clip for silence #$idx"
  done

  echo "   🎥 Saved ${#SILENCE_ENDS[@]} video clips to: $VIDEOS_DIR/"
fi

# Generate output based on format (skip if reading from existing CSV)
if [[ -n "$FROM_CSV" ]]; then
  echo ""
  echo "ℹ️  Skipping CSV generation (using existing file: $FROM_CSV)"
else
  case "$OUTPUT_FORMAT" in
    csv)
      # CSV format
      {
        echo "Start,End,Duration,Start (seconds),End (seconds),Duration (seconds)"
        for i in "${!SILENCE_ENDS[@]}"; do
          start="${SILENCE_STARTS[i]}"
          end="${SILENCE_ENDS[i]}"
          duration="${SILENCE_DURATIONS[i]}"

          start_tc=$(seconds_to_timecode "$start")
          end_tc=$(seconds_to_timecode "$end")
          duration_tc=$(seconds_to_timecode "$duration")

          echo "$start_tc,$end_tc,$duration_tc,$start,$end,$duration"
        done
      } >"$OUTPUT_FILE"
      ;;

    txt)
      # Plain text format
      {
        echo "=========================================="
        echo "Silence Detection Report"
        echo "=========================================="
        echo "Video:      $VIDEO"
        echo "Threshold:  $SILENCE_THRESHOLD"
        echo "Min Duration: ${SILENCE_DURATION}s"
        echo "Date:       $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""
        echo "Found $SILENCE_COUNT silent period(s):"
        echo ""

        for i in "${!SILENCE_ENDS[@]}"; do
          start="${SILENCE_STARTS[i]}"
          end="${SILENCE_ENDS[i]}"
          duration="${SILENCE_DURATIONS[i]}"

          start_tc=$(seconds_to_timecode "$start")
          end_tc=$(seconds_to_timecode "$end")
          duration_tc=$(seconds_to_timecode "$duration")

          printf "%3d. Start: %s  End: %s  Duration: %s\n" \
            $((i + 1)) "$start_tc" "$end_tc" "$duration_tc"
        done

        echo ""
        echo "=========================================="

        # Calculate total silence duration
        total_silence=$(awk 'BEGIN {sum=0} {sum+=$1} END {print sum}' <<<"$(printf '%s\n' "${SILENCE_DURATIONS[@]}")")
        total_silence_tc=$(seconds_to_timecode "$total_silence")
        echo "Total silence duration: $total_silence_tc"
        echo "=========================================="
      } >"$OUTPUT_FILE"
      ;;

    json)
      # JSON format
      {
        echo "{"
        echo "  \"video\": \"$VIDEO\","
        echo "  \"threshold\": \"$SILENCE_THRESHOLD\","
        echo "  \"minDuration\": $SILENCE_DURATION,"
        echo "  \"date\": \"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\","
        echo "  \"silentPeriods\": ["

        for i in "${!SILENCE_ENDS[@]}"; do
          start="${SILENCE_STARTS[i]}"
          end="${SILENCE_ENDS[i]}"
          duration="${SILENCE_DURATIONS[i]}"

          start_tc=$(seconds_to_timecode "$start")
          end_tc=$(seconds_to_timecode "$end")
          duration_tc=$(seconds_to_timecode "$duration")

          echo "    {"
          echo "      \"index\": $((i + 1)),"
          echo "      \"start\": \"$start_tc\","
          echo "      \"end\": \"$end_tc\","
          echo "      \"duration\": \"$duration_tc\","
          echo "      \"startSeconds\": $start,"
          echo "      \"endSeconds\": $end,"
          echo "      \"durationSeconds\": $duration"

          if [[ $i -eq $((SILENCE_COUNT - 1)) ]]; then
            echo "    }"
          else
            echo "    },"
          fi
        done

        echo "  ],"

        # Calculate total silence duration
        total_silence=$(awk 'BEGIN {sum=0} {sum+=$1} END {print sum}' <<<"$(printf '%s\n' "${SILENCE_DURATIONS[@]}")")
        total_silence_tc=$(seconds_to_timecode "$total_silence")

        echo "  \"totalSilenceDuration\": \"$total_silence_tc\","
        echo "  \"totalSilenceSeconds\": $total_silence"
        echo "}"
      } >"$OUTPUT_FILE"
      ;;
  esac
fi

# Display summary
echo ""
echo "✅ Analysis complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Found: $SILENCE_COUNT silent period(s)"
if [[ -z "$FROM_CSV" ]]; then
  echo "Report saved to: $OUTPUT_FILE"
fi
if [[ "$OUTPUT_FRAMES" == "true" ]]; then
  echo "Frames saved to: $FRAMES_DIR/"
fi
if [[ "$OUTPUT_VIDEO" == "true" ]]; then
  echo "Videos saved to: $VIDEOS_DIR/"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show preview of results
echo ""
echo "Preview of silent periods:"
for i in "${!SILENCE_ENDS[@]}"; do
  if [[ $i -lt 5 ]]; then # Show first 5
    start="${SILENCE_STARTS[i]}"
    end="${SILENCE_ENDS[i]}"
    duration="${SILENCE_DURATIONS[i]}"

    start_tc=$(seconds_to_timecode "$start")
    end_tc=$(seconds_to_timecode "$end")
    duration_tc=$(seconds_to_timecode "$duration")

    printf "  %2d. %s - %s (duration: %s)\n" \
      $((i + 1)) "$start_tc" "$end_tc" "$duration_tc"
  fi
done

if [[ $SILENCE_COUNT -gt 5 ]]; then
  echo "  ... and $((SILENCE_COUNT - 5)) more (see $OUTPUT_FILE)"
fi

echo ""
