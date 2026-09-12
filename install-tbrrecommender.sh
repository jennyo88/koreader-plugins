#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="tbrrecommender"
BRANCH="${BRANCH:-main}"

TARGET="/mnt/us/koreader/plugins/$PLUGIN.koplugin"
TMP="/tmp/$PLUGIN-install"
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

echo "TBR Recommender installer"
echo "Repository: $REPO"
echo "Library: /mnt/us/koreader/books"
echo

rm -rf "$TMP"
mkdir -p "$TMP"

for FILE in _meta.lua main.lua library.lua recommender.lua updater.lua; do
    echo "Downloading $FILE..."
    curl -fL "$BASE/$FILE" -o "$TMP/$FILE"
done

mkdir -p "$TARGET"

for FILE in _meta.lua main.lua library.lua recommender.lua updater.lua; do
    cp "$TMP/$FILE" "$TARGET/$FILE"
done

rm -rf "$TMP"

echo
echo "Installed TBR Recommender."
echo "Restart KOReader to load it."
