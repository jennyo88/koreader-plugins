#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
BRANCH="${BRANCH:-main}"

PLUGIN="readingbrain"
TARGET="/mnt/us/koreader/plugins/${PLUGIN}.koplugin"
DATA_DIR="/mnt/us/readingbrain"
TMP="/tmp/${PLUGIN}-install"
BACKUP="/mnt/us/koreader/plugins/${PLUGIN}.koplugin.install-backup"

BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${PLUGIN}.koplugin"
MANIFEST_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/manifest.json"

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
echo "Repository: ${REPO}"
echo "Branch: ${BRANCH}"
echo

rm -rf "${TMP}"
mkdir -p "${TMP}"
mkdir -p "${DATA_DIR}"

echo "Checking manifest.json..."

if curl -fsSL "${MANIFEST_URL}" -o "${TMP}/manifest.json"; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m json.tool "${TMP}/manifest.json" >/dev/null 2>&1; then
            echo "  manifest.json is valid JSON"
        else
            echo
            echo "WARNING: manifest.json is not valid JSON."
            echo "Reading Brain can still be installed, but"
            echo "\"Check for Updates\" will fail until the manifest is fixed."
            echo
        fi
    else
        echo "  Downloaded manifest.json"
        echo "  JSON validation skipped because python3 is unavailable."
    fi
else
    echo
    echo "WARNING: Could not download manifest.json."
    echo "The plugin can still be installed, but update checks may fail."
    echo
fi

echo
echo "Downloading Reading Brain..."

for FILE in ${FILES}; do
    echo "  ${FILE}"

    if ! curl -fsSL "${BASE}/${FILE}" -o "${TMP}/${FILE}"; then
        echo
        echo "ERROR: Could not download ${FILE}"
        echo "Nothing has been installed."
        rm -rf "${TMP}"
        exit 1
    fi

    if [ ! -s "${TMP}/${FILE}" ]; then
        echo
        echo "ERROR: ${FILE} downloaded as an empty file."
        echo "Nothing has been installed."
        rm -rf "${TMP}"
        exit 1
    fi
done

echo
echo "All plugin files downloaded successfully."

if [ -d "${TARGET}" ]; then
    echo "Backing up current Reading Brain..."
    rm -rf "${BACKUP}"
    cp -R "${TARGET}" "${BACKUP}"
fi
