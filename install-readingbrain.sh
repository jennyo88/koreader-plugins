#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="readingbrain"
BRANCH="${BRANCH:-main}"

TARGET="/mnt/us/koreader/plugins/$PLUGIN.koplugin"
DATA_DIR="/mnt/us/readingbrain"
TMP="/tmp/$PLUGIN-install"
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

echo "Reading Brain installer"
echo "Repository: $REPO"
echo

rm -rf "$TMP"
mkdir -p "$TMP"
mkdir -p "$DATA_DIR"

for FILE in _meta.lua main.lua bookmory.lua library.lua updater.lua README.md; do
    echo "Downloading $FILE..."
    curl -fL "$BASE/$FILE" -o "$TMP/$FILE"
done

mkdir -p "$TARGET"

for FILE in _meta.lua main.lua bookmory.lua library.lua updater.lua README.md; do
    cp "$TMP/$FILE" "$TARGET/$FILE"
done

rm -rf "$TMP"

echo
echo "Installed Reading Brain."
echo "Bookmory backup folder: $DATA_DIR"
echo "Restart KOReader to load it."
