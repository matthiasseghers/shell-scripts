#!/usr/bin/env bash
# Requires bash 4+ (macOS default is 3.x — install via: brew install bash)
# Requires ffprobe (brew install ffmpeg) and ImageMagick (brew install imagemagick)

# Usage:
#   ./sidebar-check.sh [options] video.mp4 [image.png]
#
# Options:
#   --editor WxH        Timeline/canvas dimensions (default: 3840x2160)
#                       e.g. --editor 3840x2160
#
#   --scale fit         Account for editor scaling mode. "fit" scales the
#                       video to fill the timeline while maintaining aspect
#                       ratio (FCP Spatial Conform: Fit). Sidebar calculations
#                       are based on the scaled dimensions, not raw pixels.
#
#   --cropdetect        Analyse frames to detect real content area inside any
#                       baked-in letterbox/pillarbox bars, and show layout
#                       options for both the container and the content crop.
#
# Examples:
#   # Basic — how much space is left beside the video on a 4K timeline?
#   ./sidebar-check.sh --editor 3840x2160 video.mp4
#
#   # With FCP "Fit" scaling — what does the editor actually render?
#   ./sidebar-check.sh --editor 3840x2160 --scale fit video.mp4
#
#   # Full check — detect baked-in bars, account for FCP scaling, check image
#   ./sidebar-check.sh --editor 3840x2160 --scale fit --cropdetect video.mp4 sidebar.png

set -e
trap 'echo "❌ Error on line $LINENO — exiting." >&2' ERR

# ===========================================================================
# Table library
# ===========================================================================

declare -a _TBL_HEADERS=()
declare -a _TBL_ROWS=()
declare -a _TBL_WIDTHS=()

table_init() {
  _TBL_HEADERS=("$@")
  _TBL_ROWS=()
  _TBL_WIDTHS=()
}
table_row() { _TBL_ROWS+=("$@"); }

table_print() {
  local ncols=${#_TBL_HEADERS[@]}
  local nrows=$((${#_TBL_ROWS[@]} / ncols))
  for ((c = 0; c < ncols; c++)); do _TBL_WIDTHS[$c]=${#_TBL_HEADERS[$c]}; done
  for ((r = 0; r < nrows; r++)); do
    for ((c = 0; c < ncols; c++)); do
      local val="${_TBL_ROWS[$((r * ncols + c))]}"
      ((${#val} > _TBL_WIDTHS[c])) && _TBL_WIDTHS[$c]=${#val}
    done
  done
  _tbl_divider
  _tbl_cells "${_TBL_HEADERS[@]}"
  _tbl_divider
  for ((r = 0; r < nrows; r++)); do
    local -a row=()
    for ((c = 0; c < ncols; c++)); do row+=("${_TBL_ROWS[$((r * ncols + c))]}"); done
    _tbl_cells "${row[@]}"
  done
  _tbl_divider
}

_tbl_divider() {
  local ncols=${#_TBL_HEADERS[@]}
  local line="+"
  for ((c = 0; c < ncols; c++)); do
    line+="$(printf '%*s' "$((_TBL_WIDTHS[c] + 2))" '' | tr ' ' '-')+"
  done
  echo "$line"
}

_tbl_cells() {
  local ncols=${#_TBL_HEADERS[@]}
  local line="|"
  for ((c = 0; c < ncols; c++)); do
    local val="${1}"
    shift
    line+=" $(printf "%-${_TBL_WIDTHS[$c]}s" "$val") |"
  done
  echo "$line"
}

# ===========================================================================
# Layout table helper
# ===========================================================================

print_layout_table() {
  local content_w=$1 content_h=$2 editor_w=$3 editor_h=$4
  local diff_w=$((editor_w - content_w))
  local diff_h=$((editor_h - content_h))

  if ((diff_w < 0 || diff_h < 0)); then
    echo "  ⚠️   Content is larger than editor canvas — no sidebar space available."
    return
  fi
  if ((diff_w == 0 && diff_h == 0)); then
    echo "  ✅  Content fills the editor canvas exactly."
    return
  fi

  table_init "Layout" "Dimensions" "Area"
  table_row "Single sidebar" "${diff_w}x${editor_h}px" "$((diff_w * editor_h))px²"
  table_row "Split sidebars" "$((diff_w / 2))x${editor_h}px each" "N/A"
  table_row "Letterbox strips" "${editor_w}x$((diff_h / 2))px each" "$((editor_w * diff_h))px²"
  table_print
}

# ===========================================================================
# Fit-scale helper
# Scales content_w x content_h the same way an editor "fit" mode would when
# placing a container_w x container_h source on an editor_w x editor_h canvas.
# Uses integer arithmetic only.
# ===========================================================================

apply_fit_scale() {
  local content_w=$1 content_h=$2
  local container_w=$3 container_h=$4
  local editor_w=$5 editor_h=$6

  # Determine constraining dimension:
  #   scale = min(editor_w/container_w, editor_h/container_h)
  #   width-constrained when editor_w/container_w <= editor_h/container_h
  #                      i.e. editor_w * container_h <= editor_h * container_w
  if ((editor_w * container_h <= editor_h * container_w)); then
    echo "$((content_w * editor_w / container_w)) $((content_h * editor_w / container_w))"
  else
    echo "$((content_w * editor_h / container_h)) $((content_h * editor_h / container_h))"
  fi
}

# ===========================================================================
# Argument parsing
# ===========================================================================

CROPDETECT=false
SCALE_MODE=""
EDITOR_W=3840
EDITOR_H=2160
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cropdetect)
      CROPDETECT=true
      shift
      ;;
    --scale)
      SCALE_MODE="${2:-}"
      if [[ "$SCALE_MODE" != "fit" ]]; then
        echo "❌ Unknown --scale mode: '${SCALE_MODE}'. Supported: fit"
        exit 1
      fi
      shift 2
      ;;
    --editor)
      if [[ -z "${2:-}" || ! "${2}" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "❌ --editor requires a WxH value, e.g. --editor 3840x2160"
        exit 1
      fi
      EDITOR_W="${2%%x*}"
      EDITOR_H="${2##*x}"
      shift 2
      ;;
    --help | -h)
      sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \{0,1\}//p; }' "$0"
      exit 0
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "   Run $0 --help for usage."
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

VIDEO="${POSITIONAL[0]:-}"
IMAGE="${POSITIONAL[1]:-}"

# ===========================================================================
# Validation
# ===========================================================================

if [ -z "$VIDEO" ]; then
  echo "Usage: $0 [--editor WxH] [--scale fit] [--cropdetect] video.mp4 [image.png]"
  echo "       $0 --help  for full usage"
  exit 1
fi

if [ ! -f "$VIDEO" ]; then
  echo "❌ Video file not found: $VIDEO"
  exit 1
fi

if [ -n "$IMAGE" ] && [ ! -f "$IMAGE" ]; then
  echo "❌ Image file not found: $IMAGE"
  exit 1
fi

# ===========================================================================
# Dependency checks
# ===========================================================================

for tool in ffprobe ffmpeg; do
  if ! command -v "$tool" &>/dev/null; then
    echo "❌ Required tool not found: $tool  (brew install ffmpeg)"
    exit 1
  fi
done

if command -v magick &>/dev/null; then
  IDENTIFY=(magick identify)
elif command -v identify &>/dev/null; then
  IDENTIFY=(identify)
else
  if [ -n "$IMAGE" ]; then
    echo "❌ ImageMagick not found  (brew install imagemagick)"
    exit 1
  fi
  IDENTIFY=()
fi

# ===========================================================================
# Get container dimensions
# ===========================================================================

read -r VID_W VID_H < <(
  ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height \
    -of csv=p=0 "$VIDEO" | tr ',' ' '
)

if [ -z "$VID_W" ] || [ -z "$VID_H" ]; then
  echo "❌ Could not read video dimensions from: $VIDEO"
  exit 1
fi

# ===========================================================================
# Video info table
# ===========================================================================

echo ""
echo "🎬  Video"
table_init "Property" "Value"
table_row "File" "$VIDEO"
table_row "Container size" "${VID_W}x${VID_H}"
table_row "Editor canvas" "${EDITOR_W}x${EDITOR_H}"
[ -n "$SCALE_MODE" ] && table_row "Scale mode" "${SCALE_MODE}  (FCP Spatial Conform: Fit)"
$CROPDETECT && table_row "Crop detect" "enabled"
table_print

# ===========================================================================
# Container layout (raw pixels, no scaling)
# ===========================================================================

DIFF_W=$((EDITOR_W - VID_W))
DIFF_H=$((EDITOR_H - VID_H))

if ((DIFF_W < 0 || DIFF_H < 0)); then
  echo "⚠️   Video container is larger than the editor canvas — nothing to do."
  echo ""
  exit 1
fi

if ((DIFF_W == 0 && DIFF_H == 0)) && ! $CROPDETECT && [ -z "$SCALE_MODE" ]; then
  echo "✅  Video container already fills the editor canvas exactly."
  echo ""
  exit 0
fi

if ((DIFF_W > 0 || DIFF_H > 0)); then
  echo "📐  Layout Options  (based on container: ${VID_W}x${VID_H} on ${EDITOR_W}x${EDITOR_H} canvas)"
  print_layout_table "$VID_W" "$VID_H" "$EDITOR_W" "$EDITOR_H"
fi

# ===========================================================================
# Crop detection
# ===========================================================================

CROP_W="" CROP_H="" CROP_X="" CROP_Y=""

if $CROPDETECT; then
  echo "🔍  Detecting content crop..."
  CROP_RAW=$(ffmpeg -i "$VIDEO" \
    -vf "cropdetect=limit=24:round=2:skip=0" \
    -frames:v 100 -f null - 2>&1 |
    grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' |
    sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$CROP_RAW" ]; then
    echo "  ✅  No baked-in bars detected — content fills the full container."
    echo ""
  else
    CROP_W=$(echo "$CROP_RAW" | cut -d= -f2 | cut -d: -f1)
    CROP_H=$(echo "$CROP_RAW" | cut -d= -f2 | cut -d: -f2)
    CROP_X=$(echo "$CROP_RAW" | cut -d= -f2 | cut -d: -f3)
    CROP_Y=$(echo "$CROP_RAW" | cut -d= -f2 | cut -d: -f4)

    if ((CROP_W == VID_W && CROP_H == VID_H)); then
      echo "  ✅  No baked-in bars detected — content fills the full container."
      echo ""
      CROP_W="" CROP_H=""
    else
      echo ""
      echo "🎬  Content Crop  (real content inside the container)"
      table_init "Property" "Value"
      table_row "Detected crop" "${CROP_W}x${CROP_H} at offset ${CROP_X},${CROP_Y}"
      table_row "Container size" "${VID_W}x${VID_H}"
      table_row "Baked-in bars" "$((VID_W - CROP_W))px horizontal, $((VID_H - CROP_H))px vertical"
      table_row "Editor canvas" "${EDITOR_W}x${EDITOR_H}"
      table_print

      echo "📐  Layout Options  (based on crop: ${CROP_W}x${CROP_H} on ${EDITOR_W}x${EDITOR_H} canvas)"
      print_layout_table "$CROP_W" "$CROP_H" "$EDITOR_W" "$EDITOR_H"
    fi
  fi
fi

# ===========================================================================
# Editor scale layout
# Shows what the editor actually renders after applying the scale mode
# ===========================================================================

SCALED_W="" SCALED_H=""

if [ -n "$SCALE_MODE" ]; then
  echo "🖥️   Editor Scale  (${SCALE_MODE} — ${EDITOR_W}x${EDITOR_H} canvas)"

  if [ -n "$CROP_W" ]; then
    # Scale the crop content using the container as the reference frame
    read -r SCALED_W SCALED_H < <(
      apply_fit_scale "$CROP_W" "$CROP_H" "$VID_W" "$VID_H" "$EDITOR_W" "$EDITOR_H"
    )
    SCALE_SOURCE="crop ${CROP_W}x${CROP_H} inside container ${VID_W}x${VID_H}"
  else
    read -r SCALED_W SCALED_H < <(
      apply_fit_scale "$VID_W" "$VID_H" "$VID_W" "$VID_H" "$EDITOR_W" "$EDITOR_H"
    )
    SCALE_SOURCE="container ${VID_W}x${VID_H}"
  fi

  SCALE_FACTOR_NUM=$((EDITOR_W * 1000 / VID_W))
  SCALE_FACTOR_LEN=${#SCALE_FACTOR_NUM}
  SCALE_FACTOR="${SCALE_FACTOR_NUM:0:$((SCALE_FACTOR_LEN - 3))}.${SCALE_FACTOR_NUM:$((SCALE_FACTOR_LEN - 3))}"

  table_init "Property" "Value"
  table_row "Source" "$SCALE_SOURCE"
  table_row "Scale factor" "${SCALE_FACTOR}x  (${VID_W}px → ${EDITOR_W}px)"
  table_row "Scaled to" "${SCALED_W}x${SCALED_H}px"
  table_row "Remaining space" "$((EDITOR_W - SCALED_W))px wide, $((EDITOR_H - SCALED_H))px tall"
  table_print

  echo "📐  Layout Options  (based on scaled: ${SCALED_W}x${SCALED_H} on ${EDITOR_W}x${EDITOR_H} canvas)"
  print_layout_table "$SCALED_W" "$SCALED_H" "$EDITOR_W" "$EDITOR_H"
fi

# ===========================================================================
# Image comparison
# Priority for sidebar reference: scaled > crop > container
# ===========================================================================

if [ -n "$IMAGE" ]; then
  read -r IMG_W IMG_H < <("${IDENTIFY[@]}" -format "%w %h" "$IMAGE") || true

  if [ -n "$SCALED_W" ]; then
    SIDEBAR_W=$((EDITOR_W - SCALED_W))
    SIDEBAR_H=$EDITOR_H
    CMP_LABEL="scaled (${SCALE_MODE})"
  elif [ -n "$CROP_W" ]; then
    SIDEBAR_W=$((EDITOR_W - CROP_W))
    SIDEBAR_H=$EDITOR_H
    CMP_LABEL="crop"
  else
    SIDEBAR_W=$((EDITOR_W - VID_W))
    SIDEBAR_H=$EDITOR_H
    CMP_LABEL="container"
  fi

  if ((IMG_W > SIDEBAR_W || IMG_H > SIDEBAR_H)); then
    FIT_STATUS="❌  Too large"
  elif ((IMG_W == SIDEBAR_W && IMG_H == SIDEBAR_H)); then
    FIT_STATUS="✅  Fits perfectly"
  else
    FIT_STATUS="⚠️   Fits with slack"
  fi

  echo "🖼️   Image  (compared against ${CMP_LABEL} sidebar: ${SIDEBAR_W}x${SIDEBAR_H}px)"
  table_init "Property" "Value"
  table_row "File" "$IMAGE"
  table_row "Resolution" "${IMG_W}x${IMG_H}"
  table_row "Sidebar space" "${SIDEBAR_W}x${SIDEBAR_H}px"
  table_row "Fit" "$FIT_STATUS"

  ((IMG_W > SIDEBAR_W)) && table_row "Width overflow" "$((IMG_W - SIDEBAR_W))px  (image: ${IMG_W}px, sidebar: ${SIDEBAR_W}px)"
  ((IMG_H > SIDEBAR_H)) && table_row "Height overflow" "$((IMG_H - SIDEBAR_H))px  (image: ${IMG_H}px, sidebar: ${SIDEBAR_H}px)"
  ((IMG_W < SIDEBAR_W)) && table_row "Width slack" "$((SIDEBAR_W - IMG_W))px  (image: ${IMG_W}px, sidebar: ${SIDEBAR_W}px)"
  ((IMG_H < SIDEBAR_H)) && table_row "Height slack" "$((SIDEBAR_H - IMG_H))px  (image: ${IMG_H}px, sidebar: ${SIDEBAR_H}px)"

  table_print
fi
