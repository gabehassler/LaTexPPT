#!/bin/bash

# Set the directory containing the SVG files
if [ -z "$1" ]; then
  SVG_DIR="."
else
  SVG_DIR="$1"
fi

# Loop through all SVG files in the directory
for file in "$SVG_DIR"/*.svg; do
  # Get the filename without the extension
  filename=$(basename "$file" .svg)
  # Convert the SVG file to PDF using Inkscape
  inkscape "$file" --export-pdf="$SVG_DIR/$filename.pdf"
done