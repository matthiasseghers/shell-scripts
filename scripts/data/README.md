# Data Scripts

Small utilities for transforming data files.

## Scripts

### pdf_to_csv.sh
Convert a PDF statement to CSV using plain text extraction.

**Usage**
```bash
./pdf_to_csv.sh statement.pdf
```

**Output**
Creates a CSV file next to the PDF with the same base name.

**Requirements**
- `pdftotext` (Poppler utilities)

**Notes**
- The parser expects lines that start with a date in `dd/MM/yyyy` format.
- Amount is taken from the last field of each matching line.
