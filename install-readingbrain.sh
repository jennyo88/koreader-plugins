#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="readingbrain"
BRANCH="${BRANCH:-main}"

TARGET="/mnt/us/koreader/plugins/$PLUGIN.koplugin"
DATA_DIR="/mnt/us/readingbrain"
TMP="/tmp/$PLUGIN-install"

BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

FILES="
_meta.lua
main.lua
bookmory.lua
library.lua
stats.lua
brain.lua
discovery.lua
stats_patterns.lua
backup_health.lua
book_page.lua
feedback.lua
updater.lua
README.md
"

echo "Reading Brain installer"
echo "Repository: $REPO"
echo "Branch: $BRANCH"
echo

rm -rf "$TMP"
mkdir -p "$TMP"
mkdir -p "$DATA_DIR"

echo "Downloading Reading Brain..."

for FILE in $FILES; do
    echo "  $FILE"
    curl -fL "$BASE/$FILE" -o "$TMP/$FILE"
done

echo
echo "All files downloaded successfully."
echo "Installing..."

mkdir -p "$TARGET"

for FILE in $FILES; do
    cp "$TMP/$FILE" "$TARGET/$FILE"
done

rm -rf "$TMP"

echo
echo "Reading Brain installed successfully."
echo
echo "Plugin:"
echo "  $TARGET"
echo
echo "Bookmory data:"
echo "  $DATA_DIR"
echo
echo "Restart KOReader to load Reading Brain."
