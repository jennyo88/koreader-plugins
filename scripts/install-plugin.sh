#!/bin/sh
#
# install-plugin.sh
# Unified installer for jennyo88/koreader-plugins
#
# Usage:
#   sh install-plugin.sh readingbrain
#   sh install-plugin.sh readingdashboard
#   sh install-plugin.sh tbrrecommender
#   sh install-plugin.sh all
#   sh install-plugin.sh --list
#
# Kindle target:
#   /mnt/us/koreader/plugins/<plugin>.koplugin
#

set -u

OWNER="jennyo88"
REPO="koreader-plugins"
BRANCH="main"

KOREADER_DIR="/mnt/us/koreader"
PLUGIN_DIR="$KOREADER_DIR/plugins"

ARCHIVE_URL="https://github.com/$OWNER/$REPO/archive/refs/heads/$BRANCH.zip"
TMP_ROOT="/tmp/koreader-plugins-install.$$"
ARCHIVE="$TMP_ROOT/repo.zip"
EXTRACT_DIR="$TMP_ROOT/extracted"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
    echo ""
    echo "ERROR: $*"
    exit 1
}

plugin_folder() {
    case "$1" in
        readingbrain)
            echo "readingbrain.koplugin"
            ;;
        readingdashboard)
            echo "readingdashboard.koplugin"
            ;;
        tbrrecommender)
            echo "tbrrecommender.koplugin"
            ;;
        *)
            return 1
            ;;
    esac
}

show_list() {
    cat <<'EOF'
Available plugins:
  readingbrain
  readingdashboard
  tbrrecommender

Special:
  all
EOF
}

download_repo() {
    mkdir -p "$TMP_ROOT" "$EXTRACT_DIR" || fail "Could not create temporary directory."

    echo "Downloading $OWNER/$REPO ($BRANCH)..."

    if command -v curl >/dev/null 2>&1; then
        curl -fL --connect-timeout 20 --retry 2 \
            "$ARCHIVE_URL" -o "$ARCHIVE" \
            || fail "Repository download failed."
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$ARCHIVE" "$ARCHIVE_URL" \
            || fail "Repository download failed."
    else
        fail "Neither curl nor wget is available."
    fi

    [ -s "$ARCHIVE" ] || fail "Downloaded archive is empty."

    command -v unzip >/dev/null 2>&1 \
        || fail "unzip is not available."

    echo "Extracting repository..."
    unzip -q "$ARCHIVE" -d "$EXTRACT_DIR" \
        || fail "Could not extract repository archive."
}

find_repo_root() {
    REPO_ROOT=""

    for d in "$EXTRACT_DIR"/*; do
        if [ -d "$d" ]; then
            REPO_ROOT="$d"
            break
        fi
    done

    [ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT" ] \
        || fail "Could not locate extracted repository."
}

install_one() {
    NAME="$1"
    FOLDER="$(plugin_folder "$NAME")" \
        || fail "Unknown plugin: $NAME"

    SOURCE="$REPO_ROOT/$FOLDER"
    TARGET="$PLUGIN_DIR/$FOLDER"
    BACKUP="$PLUGIN_DIR/${FOLDER}.backup"

    echo ""
    echo "Installing $NAME..."
    echo "Source: $FOLDER"

    [ -d "$SOURCE" ] \
        || fail "$FOLDER was not found in the repository."

    [ -s "$SOURCE/_meta.lua" ] \
        || fail "$FOLDER/_meta.lua is missing or empty."

    [ -s "$SOURCE/main.lua" ] \
        || fail "$FOLDER/main.lua is missing or empty."

    mkdir -p "$PLUGIN_DIR" \
        || fail "Could not create KOReader plugins directory."

    rm -rf "$BACKUP"

    if [ -d "$TARGET" ]; then
        echo "Backing up current install..."
        mv "$TARGET" "$BACKUP" \
            || fail "Could not back up existing $FOLDER."
    fi

    cp -R "$SOURCE" "$TARGET"

    if [ $? -ne 0 ] || [ ! -s "$TARGET/main.lua" ] || [ ! -s "$TARGET/_meta.lua" ]; then
        echo "Install failed; restoring previous version..."
        rm -rf "$TARGET"

        if [ -d "$BACKUP" ]; then
            mv "$BACKUP" "$TARGET"
        fi

        fail "Could not install $FOLDER."
    fi

    echo "Installed: $TARGET"

    if [ -d "$BACKUP" ]; then
        echo "Backup:    $BACKUP"
    fi
}

usage() {
    echo "Usage: sh install-plugin.sh <plugin|all|--list>"
    echo ""
    show_list
}

ARG="${1:-}"

case "$ARG" in
    -l|--list)
        show_list
        exit 0
        ;;
    -h|--help|"")
        usage
        exit 0
        ;;
    all|readingbrain|readingdashboard|tbrrecommender)
        ;;
    *)
        usage
        fail "Unknown plugin: $ARG"
        ;;
esac

download_repo
find_repo_root

if [ "$ARG" = "all" ]; then
    install_one readingbrain
    install_one readingdashboard
    install_one tbrrecommender
else
    install_one "$ARG"
fi

echo ""
echo "Done."
echo "Restart KOReader to load the installed plugin."
