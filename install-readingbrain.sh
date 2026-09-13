#!/bin/sh

set -e

REPO="${1:-jennyo88/koreader-plugins}"
BRANCH="${2:-main}"

PLUGIN_DIR="/mnt/us/koreader/plugins/readingbrain.koplugin"
DATA_DIR="/mnt/us/readingbrain"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/readingbrain.koplugin"

mkdir -p "$PLUGIN_DIR"
mkdir -p "$DATA_DIR"

for file in _meta.lua main.lua bookmory.lua library.lua README.md; do
    echo "Downloading $file..."
    curl -fL "$BASE/$file" -o "$PLUGIN_DIR/$file"
done

echo
echo "Reading Brain installed."
echo "Copy a .bookmory backup into:"
echo "$DATA_DIR"
echo
echo "Restart KOReader."
