# Final Cut Pro Scripts

This directory contains scripts for working with Final Cut Pro files.

## extract_markers.sh

Extract markers from Final Cut Pro XML (FCPXML) files with timeline positions. This script parses FCPXML files to extract markers and chapter markers, converting their positions to timecodes and various output formats.

### Features

- **Multiple Output Formats**: Export markers as CSV, JSON, or text
- **Marker Filtering**: Filter by marker type (all, markers only, or chapter markers only)
- **Timeline Positions**: Calculates and displays accurate timeline positions
- **Timecode Conversion**: Converts FCPXML fractions to HH:MM:SS:FF timecode format
- **Seconds Display**: Shows timeline positions in seconds for easy reference
- **Asset-Clip Context**: Properly tracks marker positions within asset clips

### Prerequisites

The script requires standard Unix tools (typically pre-installed on macOS):
- `bc` - Basic calculator for arithmetic operations
- `zsh` - Z shell (default on modern macOS)

### Usage

```bash
./extract_markers.sh <fcpxml_file> [output_format] [marker_type]
```

#### Arguments

| Argument | Description | Options | Default |
|----------|-------------|---------|---------|
| `fcpxml_file` | Path to the FCPXML file (required) | - | - |
| `output_format` | Output format | `csv`, `json`, `text` | `csv` |
| `marker_type` | Type of markers to extract | `all`, `marker`, `chapter-marker` | `all` |

### Examples

**Extract all markers as CSV** (default):
```bash
./extract_markers.sh project.fcpxml
```

**Extract all markers as JSON**:
```bash
./extract_markers.sh project.fcpxml json
```

**Extract only chapter markers as text**:
```bash
./extract_markers.sh project.fcpxml text chapter-marker
```

**Extract only standard markers as CSV**:
```bash
./extract_markers.sh project.fcpxml csv marker
```

### Output Formats

#### CSV Format

Comma-separated values with headers, suitable for spreadsheet applications:

```csv
Type,Name,Timeline Position,Position (Seconds),Duration
marker,"Introduction",00:00:05:30,5.5,0s
chapter-marker,"Chapter 1",00:01:30:00,90.0,0s
marker,"Important Note",00:02:15:45,135.75,0s
```

#### JSON Format

Structured JSON array with detailed marker information:

```json
[
  {
    "type": "marker",
    "name": "Introduction",
    "timelineOffset": "330/60s",
    "timelineSeconds": 5.5,
    "timecode": "00:00:05:30",
    "duration": "0s"
  },
  {
    "type": "chapter-marker",
    "name": "Chapter 1",
    "timelineOffset": "5400/60s",
    "timelineSeconds": 90.0,
    "timecode": "00:01:30:00",
    "duration": "0s",
    "posterOffset": "0s"
  }
]
```

#### Text Format

Human-readable text output:

```
=== Markers from: project.fcpxml ===

[MARKER] 00:00:05:30 - Introduction
[CHAPTER] 00:01:30:00 - Chapter 1
[MARKER] 00:02:15:45 - Important Note
```

### Timecode Format

Timecodes are displayed in `HH:MM:SS:FF` format (hours:minutes:seconds:frames) at 60fps, which is the standard for FCPXML Non-Drop Frame (NDF) format.

### Marker Types

- **marker**: Standard markers used for notes, reminders, or reference points
- **chapter-marker**: Chapter markers typically used for DVD/Blu-ray chapters or video chapters

### How It Works

1. **Parse FCPXML**: Reads the XML file line by line
2. **Track Context**: Maintains context of current asset-clip and its offset
3. **Extract Markers**: Identifies marker and chapter-marker elements within asset clips
4. **Calculate Positions**: Converts FCPXML time fractions to seconds
5. **Format Output**: Generates timecodes and outputs in requested format

### FCPXML Time Format

FCPXML uses fractional time representations like `220889/60s`:
- Numerator: Total number of frames
- Denominator: Frame rate
- The script automatically converts these to decimal seconds and timecodes

### Tips

1. **Export FCPXML from Final Cut Pro**: File → Export XML (or Cmd+E, then select XML)

2. **Pipe to file**:
   ```bash
   ./extract_markers.sh project.fcpxml csv > markers.csv
   ./extract_markers.sh project.fcpxml json > markers.json
   ```

3. **Use with spreadsheets**: CSV format imports directly into Excel, Numbers, or Google Sheets

4. **Process with jq**: JSON format works well with jq for filtering:
   ```bash
   ./extract_markers.sh project.fcpxml json | jq '.[] | select(.type == "chapter-marker")'
   ```

5. **Quick preview**: Use text format for a quick overview:
   ```bash
   ./extract_markers.sh project.fcpxml text | less
   ```

### Common Use Cases

- **Generate chapter lists** for video platforms (YouTube, Vimeo)
- **Create marker reports** for client review
- **Extract timestamps** for documentation or notes
- **Export chapter markers** for DVD/Blu-ray authoring
- **Analyze editing structure** and pacing

### Troubleshooting

**"File not found" error**:
- Verify the FCPXML file path is correct
- Ensure the file has a `.fcpxml` extension
- Check file permissions

**No markers extracted**:
- Verify markers exist in the Final Cut Pro project
- Ensure markers are placed on clips within the timeline
- Check that the FCPXML export includes marker information

**Incorrect timecodes**:
- Verify the project frame rate matches the expected 60fps NDF
- For projects with different frame rates, the script assumes 60fps

**Invalid marker type error**:
- Use only supported types: `all`, `marker`, or `chapter-marker`
- Check for typos in the marker type argument

### Exit Codes

- `0` - Success
- `1` - Error (file not found, invalid arguments, unknown format)

### Limitations

- Assumes 60fps frame rate for timecode conversion
- Designed for NDF (Non-Drop Frame) timecode format
- Does not extract marker metadata beyond name, position, and duration
