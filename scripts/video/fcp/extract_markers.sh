#!/bin/bash

# Script to extract markers from FCPXML files with timeline positions
# Usage: ./extract_markers.sh <fcpxml_file> [output_format] [marker_type]
# Output formats: csv (default), json, text
# Marker types: all (default), marker, chapter-marker

FCPXML_FILE="$1"
OUTPUT_FORMAT="${2:-csv}"
MARKER_TYPE="${3:-all}"

# Check if file exists
if [[ ! -f "$FCPXML_FILE" ]]; then
  echo "Error: File '$FCPXML_FILE' not found"
  echo "Usage: $0 <fcpxml_file> [csv|json|text] [all|marker|chapter-marker]"
  exit 1
fi

# Validate marker type
if [[ ! "$MARKER_TYPE" =~ ^(all|marker|chapter-marker)$ ]]; then
  echo "Error: Invalid marker type '$MARKER_TYPE'"
  echo "Supported types: all, marker, chapter-marker"
  exit 1
fi

# Function to convert timecode fraction to seconds
fraction_to_seconds() {
  local fraction="$1"
  # Handle both "123/456s" and "123s" and "123/456" formats
  if [[ "$fraction" =~ ^([0-9]+)s$ ]]; then
    # Simple seconds format like "0s"
    echo "${match[1]}"
  elif [[ "$fraction" =~ ^([0-9]+)/([0-9]+)s?$ ]]; then
    # Fraction format like "220889/60s"
    local numerator="${match[1]}"
    local denominator="${match[2]}"
    echo "scale=6; $numerator / $denominator" | bc
  else
    echo "0"
  fi
}

# Function to format seconds as timecode HH:MM:SS:FF (with frames at 60fps for NDF)
seconds_to_timecode() {
  local seconds="$1"
  local fps=60 # FCPXML default frame rate for NDF

  local hours=$(echo "scale=0; $seconds / 3600" | bc)
  local remainder=$(echo "scale=6; $seconds - ($hours * 3600)" | bc)
  local minutes=$(echo "scale=0; $remainder / 60" | bc)
  local secs_remainder=$(echo "scale=6; $remainder - ($minutes * 60)" | bc)
  local secs=$(echo "scale=0; $secs_remainder" | bc)
  local frames=$(echo "scale=0; ($secs_remainder - $secs) * $fps" | bc)

  printf "%02d:%02d:%02d:%02d" "$hours" "$minutes" "$secs" "$frames"
}

# Extract markers with their timeline positions by parsing asset-clip elements
extract_markers_with_positions() {
  # Read the file line by line, tracking asset-clip context
  local current_offset=""
  local in_asset_clip=0

  while IFS= read -r line; do
    # Check if this is an asset-clip opening tag with offset
    if [[ "$line" =~ \<asset-clip.*offset=\"([^\"]+)\" ]]; then
      current_offset="${match[1]}"
      in_asset_clip=1
    fi

    # Check if this line contains a marker
    if [[ "$line" =~ \<(marker|chapter-marker) ]] && [[ $in_asset_clip -eq 1 ]] && [[ -n "$current_offset" ]]; then
      # Determine marker type
      local marker_type="marker"
      if [[ "$line" =~ \<chapter-marker ]]; then
        marker_type="chapter-marker"
      fi

      # Extract attributes
      local value=""
      local start=""
      local duration=""
      local posterOffset=""

      if [[ "$line" =~ value=\"([^\"]+)\" ]]; then
        value="${match[1]}"
      fi

      if [[ "$line" =~ start=\"([^\"]+)\" ]]; then
        start="${match[1]}"
      fi

      if [[ "$line" =~ duration=\"([^\"]+)\" ]]; then
        duration="${match[1]}"
      fi

      if [[ "$line" =~ posterOffset=\"([^\"]+)\" ]]; then
        posterOffset="${match[1]}"
      fi

      # Output: type|offset|start|value|duration|posterOffset
      echo "$marker_type|$current_offset|$start|$value|$duration|$posterOffset"
    fi

    # Check if this is a closing asset-clip tag
    if [[ "$line" =~ \</asset-clip\> ]]; then
      in_asset_clip=0
      current_offset=""
    fi
  done <"$FCPXML_FILE"
}

# Filter markers by type
should_include_marker() {
  local type="$1"

  case "$MARKER_TYPE" in
    all)
      return 0
      ;;
    marker)
      if [[ "$type" == "marker" ]]; then
        return 0
      else
        return 1
      fi
      ;;
    chapter-marker)
      if [[ "$type" == "chapter-marker" ]]; then
        return 0
      else
        return 1
      fi
      ;;
  esac
}

# Parse markers and output in specified format
output_csv() {
  echo "Type,Name,Timeline Position,Position (Seconds),Duration"

  extract_markers_with_positions | while IFS='|' read -r type offset start value duration posterOffset; do
    if should_include_marker "$type"; then
      # Convert offset to seconds (timeline position)
      local offset_seconds=$(fraction_to_seconds "$offset")

      # Convert to timecode
      local timecode=$(seconds_to_timecode "$offset_seconds")

      echo "$type,\"$value\",$timecode,$offset_seconds,$duration"
    fi
  done
}

output_json() {
  echo "["
  local first=true

  extract_markers_with_positions | while IFS='|' read -r type offset start value duration posterOffset; do
    if should_include_marker "$type"; then
      # Convert offset to seconds (timeline position)
      local offset_seconds=$(fraction_to_seconds "$offset")

      # Convert to timecode
      local timecode=$(seconds_to_timecode "$offset_seconds")

      # Print comma for all but first entry
      if [[ "$first" = false ]]; then
        echo ","
      fi
      first=false

      echo "  {"
      echo "    \"type\": \"$type\","
      echo "    \"name\": \"$value\","
      echo "    \"timelineOffset\": \"$offset\","
      echo "    \"timelineSeconds\": $offset_seconds,"
      echo "    \"timecode\": \"$timecode\","
      echo "    \"duration\": \"$duration\""
      if [[ -n "$posterOffset" ]]; then
        echo "    ,\"posterOffset\": \"$posterOffset\""
      fi
      echo -n "  }"
    fi
  done
  echo ""
  echo "]"
}

output_text() {
  echo "=== Markers from: $FCPXML_FILE ==="
  echo ""

  extract_markers_with_positions | while IFS='|' read -r type offset start value duration posterOffset; do
    if should_include_marker "$type"; then
      # Convert offset to seconds (timeline position)
      local offset_seconds=$(fraction_to_seconds "$offset")

      # Convert to timecode
      local timecode=$(seconds_to_timecode "$offset_seconds")

      # Determine marker type label
      local type_label="MARKER"
      if [[ "$type" == "chapter-marker" ]]; then
        type_label="CHAPTER"
      fi

      printf "[%s] %s - %s\n" "$type_label" "$timecode" "$value"
    fi
  done
}

# Output based on format
case "$OUTPUT_FORMAT" in
  csv)
    output_csv
    ;;
  json)
    output_json
    ;;
  text | txt)
    output_text
    ;;
  *)
    echo "Error: Unknown output format '$OUTPUT_FORMAT'"
    echo "Supported formats: csv, json, text"
    exit 1
    ;;
esac
