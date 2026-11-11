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
mkdir -p "${TMP}" "${DATA_DIR}"

echo "Downloading complete plugin..."
for FILE in ${FILES}; do
    echo "  ${FILE}"
    if ! curl -fSL "${BASE}/${FILE}" -o "${TMP}/${FILE}"; then
        echo "ERROR: Could not download ${FILE}."
        echo "Nothing was installed."
        rm -rf "${TMP}"
        exit 1
    fi
    if [ ! -s "${TMP}/${FILE}" ]; then
        echo "ERROR: ${FILE} is empty."
        echo "Nothing was installed."
        rm -rf "${TMP}"
        exit 1
    fi
done

echo
echo "All files downloaded."

if [ -d "${TARGET}" ]; then
    echo "Backing up existing plugin..."
    rm -rf "${BACKUP}"
    cp -R "${TARGET}" "${BACKUP}"
fi

echo "Installing..."
mkdir -p "${TARGET}"

for FILE in ${FILES}; do
    cp "${TMP}/${FILE}" "${TARGET}/${FILE}"
done

# v0.7.3 is manual-update only.
# This is safe because the installed v0.7.3 main.lua does not load this file.
rm -f "${TARGET}/update_notifier.lua"

rm -rf "${TMP}"

echo
echo "Reading Brain installed successfully."
echo "Restart KOReader."
