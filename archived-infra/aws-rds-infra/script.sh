#!/bin/bash

OUTPUT_FILE="merged.txt"
> "$OUTPUT_FILE"  # Clear output file if it exists

for file in *.tf; do
  echo "# ===== File: $file =====" >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo -e "\n" >> "$OUTPUT_FILE"
done

echo "✅ All .tf files merged into $OUTPUT_FILE"

