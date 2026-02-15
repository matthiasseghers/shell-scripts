#!/bin/bash

# Usage: ./pdf_to_csv.sh statement.pdf

if [ $# -ne 1 ]; then
  echo "Usage: $0 <pdf-file>"
  exit 1
fi

PDF_FILE="$1"

if [ ! -f "$PDF_FILE" ]; then
  echo "File not found: $PDF_FILE"
  exit 1
fi

# Extract filename without extension
BASE_NAME="${PDF_FILE%.pdf}"
TXT_FILE="${BASE_NAME}.txt"
CSV_FILE="${BASE_NAME}.csv"

# Step 1: Extract raw text from PDF
pdftotext -raw "$PDF_FILE" "$TXT_FILE"

# Step 2: Convert to CSV
awk '
# Only process lines starting with a date (dd/MM/yyyy)
/^[0-9]{2}\/[0-9]{2}\/[0-9]{4}/ {
    date=$1
    amount=$NF
    $1=""; $NF=""
    desc=$0
    gsub(/^ +| +$/,"",desc)
    # Wrap description and amount in quotes to preserve commas
    print date "," "\"" desc "\"" "," "\"" amount "\""
}' "$TXT_FILE" >"$CSV_FILE"

# Step 3: Cleanup
rm "$TXT_FILE"

echo "CSV created: $CSV_FILE"
