#!/usr/bin/env bash

OUTPUT_FILE="all-yaml-files.txt"

echo "Collecting YAML files into $OUTPUT_FILE..."
echo "" > "$OUTPUT_FILE"

# Find all .yaml and .yml files recursively
find . -type f \( -name "*.yaml" -o -name "*.yml" \) | while read FILE
do
  echo "===============================" >> "$OUTPUT_FILE"
  echo "File: $FILE" >> "$OUTPUT_FILE"
  echo "===============================" >> "$OUTPUT_FILE"
  cat "$FILE" >> "$OUTPUT_FILE"
  echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "✅ Done! All YAML files have been merged in $OUTPUT_FILE"

