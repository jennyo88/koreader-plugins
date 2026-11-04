#!/bin/sh
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="minimalshelf"
BRANCH="${BRANCH:-main}"

TARGET="/mnt/us/koreader/plugins/$PLUGIN.koplugin"
BACKUP="${TARGET}.backup"
TMP="/tmp/$PLUGIN-install-$$"
STAGE="${TARGET}.new.$$"
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"

FILES="_meta.lua main.lua version.lua catalog.lua series.lua calibre_pages.lua updater.lua update_notifier.lua update.json"

cleanup() {
    rm -rf "$TMP" "$STAGE"
}
trap cleanup 0
trap 'exit 1' 1 2 3 15

echo "Minimal Shelf installer"
echo "Repository: $REPO"
echo "Branch: $BRANCH"
echo "Install location: $TARGET"
echo

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required to download the plugin." >&2
    exit 1
fi

mkdir -p "$TMP" "$(dirname "$TARGET")"

# Download everything before modifying the installed plugin.
for FILE in $FILES; do
    echo "Downloading $FILE..."
    curl -fL "$BASE/$FILE" -o "$TMP/$FILE"
done

# Stage the new version on the same filesystem as the target.
mkdir -p "$STAGE"
for FILE in $FILES; do
    cp "$TMP/$FILE" "$STAGE/$FILE"
done

# Preserve the previous installation for manual rollback.
if [ -d "$TARGET" ]; then
    rm -rf "$BACKUP"
    mv "$TARGET" "$BACKUP"
fi

if ! mv "$STAGE" "$TARGET"; then
    echo "Error: installation failed." >&2
    if [ -d "$BACKUP" ] && [ ! -e "$TARGET" ]; then
        mv "$BACKUP" "$TARGET"
        echo "Previous installation restored."
    fi
    exit 1
fi

echo
echo "Installed Minimal Shelf."
if [ -d "$BACKUP" ]; then
    echo "Previous version saved to: $BACKUP"
fi
echo "Restart KOReader to load it."
