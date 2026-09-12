#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="tbrrecommender"
BRANCH="${BRANCH:-main}"
TARGET="/mnt/us/koreader/plugins/$PLUGIN.koplugin"
TMP="/tmp/$PLUGIN-install"
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

rm -rf "$TMP"
mkdir -p "$TMP"

for FILE in _meta.lua main.lua library.lua recommender.lua; do
    echo "Downloading $FILE..."
    curl -fL "$BASE/$FILE" -o "$TMP/$FILE"
done

mkdir -p "$TARGET"

for FILE in _meta.lua main.lua library.lua recommender.lua; do
    cp "$TMP/$FILE" "$TARGET/$FILE"
done

rm -rf "$TMP"

echo "Installed TBR Recommender. Restart KOReader."
