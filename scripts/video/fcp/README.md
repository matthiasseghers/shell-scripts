# Final Cut Pro Scripts

This directory contains scripts for working with Final Cut Pro files.

## extract_markers.sh

Extract markers from a Final Cut Pro FCPXML/FCPXMLD file and output YouTube chapter timestamps
to the same directory as the input file.

This script is a thin wrapper around [MarkersExtractor](https://github.com/TheAcharya/MarkersExtractor),
a dedicated CLI tool for marker extraction from FCP. It handles dependency installation automatically
on first run.

### Prerequisites

- macOS
- [Homebrew](https://brew.sh/)

`markers-extractor` will be installed automatically via Homebrew if not already present.

### Usage

```bash
./extract_markers.sh <path-to-fcpxml-or-fcpxmld>
```

### Example

```bash
./extract_markers.sh ~/Desktop/MyVideo.fcpxmld
```

Output is written to the same directory as the input file. `markers-extractor` creates a
timestamped subfolder containing the YouTube chapters `.txt` file.

### Output Format

A plain text file with YouTube-compatible chapter timestamps:

```
00:00 Introduction
01:30 Chapter 1
05:45 Chapter 2
```

This can be pasted directly into a YouTube video description.

### Exporting FCPXML from Final Cut Pro

File → Export XML (or `Cmd+E`, then select XML format).

### Tips

- For more control over the export (image thumbnails, label overlays, other export formats like
  CSV, JSON, Notion, Airtable), use `markers-extractor` directly:
  ```bash
  markers-extractor --help
  ```
- `markers-extractor` supports many export formats beyond YouTube chapters — see the
  [MarkersExtractor documentation](https://github.com/TheAcharya/MarkersExtractor) for the full list.