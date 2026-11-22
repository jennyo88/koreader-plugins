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
feedback.lua
updater.lua
README.md
"

echo "Reading Brain v0.8.0 installer"
echo "Repository: ${REPO}"
echo "Branch: ${BRANCH}"
echo

rm -rf "${TMP}"
mkdir -p "${TMP}" "${DATA_DIR}"

echo "Checking manifest.json..."

if curl -fsSL "${MANIFEST_URL}" -o "${TMP}/manifest.json"; then
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m json.tool "${TMP}/manifest.json" >/dev/null 2>&1; then
            echo "  manifest.json is valid JSON"
        else
            echo "  WARNING: manifest.json is invalid JSON."
            echo "  Installation can continue, but Check for Updates will fail."
        fi
    else
        echo "  manifest downloaded; JSON validation skipped (python3 unavailable)."
    fi
else
    echo "  WARNING: manifest.json could not be downloaded."
    echo "  Installation can continue, but update checks may fail."
fi

echo
echo "Downloading complete Reading Brain plugin..."

for FILE in ${FILES}; do
    echo "  ${FILE}"

    if ! curl -fSL "${BASE}/${FILE}" -o "${TMP}/${FILE}"; then
        echo "ERROR: Could not download ${FILE}."
        echo "Nothing was installed."
        rm -rf "${TMP}"
        exit 1
    fi

    if [ ! -s "${TMP}/${FILE}" ]; then
        echo "ERROR: ${FILE} downloaded as an empty file."
        echo "Nothing was installed."
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

echo "Installing..."
mkdir -p "${TARGET}"

for FILE in ${FILES}; do
    cp "${TMP}/${FILE}" "${TARGET}/${FILE}"
done

# v0.8.0 no longer uses these legacy modules.
rm -f "${TARGET}/update_notifier.lua"
rm -f "${TARGET}/book_page.lua"

rm -rf "${TMP}"

echo
echo "Reading Brain v0.8.0 installed successfully."
echo
echo "Plugin:"
echo "  ${TARGET}"
echo
echo "Bookmory data:"
echo "  ${DATA_DIR}"
echo
echo "Updates are manual only:"
echo "  Reading Brain -> Settings & Updates -> Check for Updates"
echo
echo "Restart KOReader to load Reading Brain."
