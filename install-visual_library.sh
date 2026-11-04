#!/bin/sh
# Visual Library installer — downloads directly from the GitHub branch,
# using the same curl/raw.githubusercontent.com pattern as Reading Brain.
# Only visual_library.koplugin is replaced; Bookshelf and settings stay untouched.
set -eu

REPO="${1:-jennyo88/koreader-plugins}"
PLUGIN="visual_library"
BRANCH="${BRANCH:-main}"
PLUGINS_DIR="${KOREADER_PLUGINS_DIR:-/mnt/us/koreader/plugins}"
TARGET="$PLUGINS_DIR/$PLUGIN.koplugin"
BACKUP="$PLUGINS_DIR/.$PLUGIN.koplugin.previous"
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH/$PLUGIN.koplugin"
FILES="_meta.lua main.lua catalog.lua moods.lua visualui.lua updater.lua install_update.sh README.md"

# Avoid accidentally using invalid paths or URL parameters.
case "$REPO" in
    */*) : ;;
    *) echo "ERROR: Expected GitHub repository OWNER/REPO." >&2; exit 1 ;;
esac
case "$REPO" in
    *[!a-zA-Z0-9._/-]*|*..*|*//*|/*|*/) echo "ERROR: Invalid repository." >&2; exit 1 ;;
esac
case "$BRANCH" in
    ''|*[!a-zA-Z0-9._/-]*|*..*|/*) echo "ERROR: Invalid branch." >&2; exit 1 ;;
esac
[ -d "$PLUGINS_DIR" ] || { echo "ERROR: KOReader plugins folder not found: $PLUGINS_DIR" >&2; exit 1; }
[ ! -L "$TARGET" ] || { echo "ERROR: Target is a symlink; refusing to replace it." >&2; exit 1; }
[ ! -L "$BACKUP" ] || { echo "ERROR: Backup is a symlink; refusing to replace it." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }

# Stage downloads beside the plugin directory so moving the finished files is safe.
TMP=$(mktemp -d "$PLUGINS_DIR/.$PLUGIN-install.XXXXXX") || exit 1
cleanup() { rm -rf "$TMP"; }
trap cleanup 0
trap 'exit 1' 1 2 3 15
mkdir "$TMP/new"

echo "Visual Library installer"
echo "Repository: $REPO"
echo "Branch: $BRANCH"
echo

for FILE in $FILES; do
    echo "Downloading $FILE..."
    curl -fL --connect-timeout 10 --max-time 45 "$BASE/$FILE" -o "$TMP/new/$FILE"
done

# Do not replace the installed plugin unless every required file downloaded.
for FILE in $FILES; do
    [ -s "$TMP/new/$FILE" ] || { echo "ERROR: Missing or empty $FILE" >&2; exit 1; }
done

# Keep one previous version for rollback. A failed download leaves the old one intact.
if [ -d "$BACKUP" ]; then
    mv "$BACKUP" "$TMP/older_backup"
fi
if [ -d "$TARGET" ]; then
    if ! mv "$TARGET" "$BACKUP"; then
        [ ! -d "$TMP/older_backup" ] || mv "$TMP/older_backup" "$BACKUP"
        echo "ERROR: Could not back up current installation." >&2
        exit 1
    fi
fi
if ! mv "$TMP/new" "$TARGET"; then
    [ ! -d "$BACKUP" ] || mv "$BACKUP" "$TARGET"
    [ ! -d "$TMP/older_backup" ] || mv "$TMP/older_backup" "$BACKUP"
    echo "ERROR: Installation failed; attempted to restore previous version." >&2
    exit 1
fi

echo
echo "Installed Visual Library to: $TARGET"
[ ! -d "$BACKUP" ] || echo "Previous version backed up to: $BACKUP"
echo "Saved moods and reading queue are unchanged."
echo "Bookshelf was not modified."
echo "Restart KOReader to load the update."
