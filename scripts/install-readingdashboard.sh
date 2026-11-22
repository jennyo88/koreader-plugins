#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="readingdashboard"
BRANCH="${BRANCH:-main}"

KOREADER_DIR="/mnt/us/koreader"
PLUGIN_DIR="$KOREADER_DIR/plugins"
TARGET="$PLUGIN_DIR/$PLUGIN.koplugin"
TMP="/tmp/$PLUGIN-install"

echo "Reading Dashboard installer"
echo "Repository: $REPO"
echo

rm -rf "$TMP"
mkdir -p "$TMP"

BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

echo "Downloading plugin files..."

curl -fL "$BASE/_meta.lua" \
  -o "$TMP/_meta.lua"

curl -fL "$BASE/main.lua" \
  -o "$TMP/main.lua"

curl -fL "$BASE/updater.lua" \
  -o "$TMP/updater.lua"

if [ -d "$TARGET" ]; then
    echo "Updating existing installation..."
else
    echo "Installing plugin..."
fi

mkdir -p "$TARGET"

cp "$TMP/_meta.lua" \
  "$TARGET/_meta.lua"

cp "$TMP/main.lua" \
  "$TARGET/main.lua"

cp "$TMP/updater.lua" \
  "$TARGET/updater.lua"

rm -rf "$TMP"

echo
echo "Installed:"
echo "  $TARGET/_meta.lua"
echo "  $TARGET/main.lua"
echo "  $TARGET/updater.lua"
echo
echo "Restart KOReader to load Reading Dashboard."
