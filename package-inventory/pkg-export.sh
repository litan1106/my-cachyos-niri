#!/bin/bash

# Define the output file in a whitelisted/synced location
OUTPUT_FILE="$HOME/Work/pacman-yay-packages.txt"

echo "Exporting installed packages to $OUTPUT_FILE..."

# Check if pacman is available
if ! command -v pacman &> /dev/null; then
    echo "Error: pacman not found. This script is intended for Arch-based systems."
    exit 1
fi

# Create a clean file
echo "# Generated on $(date)" > "$OUTPUT_FILE"

echo "--- Native Packages (Main Repos) ---" >> "$OUTPUT_FILE"
pacman -Qqen | grep -v "omarchy" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "--- AUR Packages ---" >> "$OUTPUT_FILE"
# Also includes foreign packages in general
pacman -Qqem | grep -v "omarchy" >> "$OUTPUT_FILE"

echo "Done! The file $OUTPUT_FILE is now ready for syncing."
echo "On your laptop, you can reinstall these using:"
echo "  yay -S - < $OUTPUT_FILE"
echo "(Note: You may need to clean headers/comments if using raw pacman/yay)"
