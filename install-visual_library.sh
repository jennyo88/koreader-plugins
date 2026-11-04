#!/bin/sh
# Visual Library for KOReader — local installer and optional GitHub Releases installer.
# Place this file NEXT TO the visual_library.koplugin directory in the same folder.
# Run: sh install-visual_library.sh
# Or:  sh install-visual_library.sh --repo OWNER/REPO
# Optional: --target /mnt/us/koreader/plugins
# Only visual_library.koplugin is replaced; no Bookshelf or reading settings are changed.
set -eu

usage() {
    cat <<'EOF'
Visual Library installer

Usage:
  sh install-visual_library.sh [--target /path/to/koreader/plugins]
  sh install-visual_library.sh --repo OWNER/REPO [--target /path/to/koreader/plugins]
  sh install-visual_library.sh --help

Local mode (default): copies visual_library.koplugin from the same folder as
this script. GitHub mode: installs the latest published release asset named
visual-library-koreader-vVERSION.zip from OWNER/REPO.

Your KOReader settings and Bookshelf plugin are never modified.
EOF
}
fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
say() { printf '%s\n' "$1"; }

repo=${VISUAL_LIBRARY_REPO:-}
target=${KOREADER_PLUGINS_DIR:-}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo)
            [ "$#" -gt 1 ] || fail 'Missing OWNER/REPO after --repo.'
            repo=$2; shift 2 ;;
        --target)
            [ "$#" -gt 1 ] || fail 'Missing plugin path after --target.'
            target=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fail "Unknown argument: $1" ;;
    esac
done

# The destination is a plugins/ directory, not a whole KOReader installation.
# Kindle's standard path comes first; other supported devices are fallbacks.
if [ -z "$target" ]; then
    for dir in /mnt/us/koreader/plugins /mnt/us/extensions/koreader/plugins \
        /mnt/onboard/.adds/koreader/plugins /mnt/onboard/koreader/plugins; do
        if [ -d "$dir" ]; then target=$dir; break; fi
    done
fi
[ -n "$target" ] || fail 'KOReader plugins directory not found. Use --target /path/to/koreader/plugins.'
[ -d "$target" ] || fail 'Target plugins directory does not exist.'
case "$target" in */plugins|*/plugins/) : ;; *) fail 'Target must be the KOReader plugins directory.' ;; esac
# Canonicalize for unambiguous, predictable backup locations.
target=$(cd "$target" && pwd -P) || fail 'Cannot access KOReader plugins directory.'
plugin="$target/visual_library.koplugin"
backup="$target/.visual_library.koplugin.previous"
[ ! -L "$plugin" ] || fail 'Refusing to replace a symlinked Visual Library directory.'
[ ! -e "$plugin" ] || [ -d "$plugin" ] || fail 'Visual Library destination exists but is not a directory.'
[ ! -L "$backup" ] || fail 'Backup path is a symlink; inspect manually before installing.'

# A temporary sibling directory ensures the final move stays on the same filesystem.
work=$(mktemp -d "$target/.visual_library_install.XXXXXX") || fail 'Cannot create staging directory.'
cleanup() { rm -rf "$work"; }
trap cleanup 0
trap 'exit 1' 1 2 3 15

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P || true)
source_dir=""
if [ -z "$repo" ]; then
    [ -n "$script_dir" ] || fail 'Cannot find the script directory. Use --repo OWNER/REPO for a remote install.'
    source_dir="$script_dir/visual_library.koplugin"
    [ -d "$source_dir" ] || fail 'visual_library.koplugin not found beside install-visual_library.sh.'
    [ "$source_dir" != "$plugin" ] || fail 'Source and destination are the same folder; nothing to install.'
    say 'Installing Visual Library from the adjacent local folder.'
else
    # Strictly validate the repository before placing it into a URL.
    case "$repo" in
        */*) : ;;
        *) fail 'GitHub repository must be OWNER/REPO.' ;;
    esac
    case "$repo" in *[!a-zA-Z0-9._/-]*|*..*|*//*|/*|*/) fail 'Invalid GitHub repository.' ;; esac
    owner=${repo%%/*}
    name=${repo#*/}
    [ -n "$owner" ] && [ -n "$name" ] || fail 'Invalid GitHub repository.'
    command -v curl >/dev/null 2>&1 || fail 'curl is required to install GitHub releases.'
    command -v unzip >/dev/null 2>&1 || fail 'unzip is required to install GitHub releases.'
    say "Checking latest GitHub release in $repo ..."
    curl --fail --location --silent --show-error --connect-timeout 8 --max-time 25 \
        -H 'Accept: application/vnd.github+json' -H 'User-Agent: VisualLibrary-KOReader' \
        "https://api.github.com/repos/$repo/releases/latest" -o "$work/release.json" \
        || fail 'Could not get latest GitHub release. Check Wi-Fi, repo name, and release availability.'
    tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$work/release.json" | head -n 1)
    version=${tag#v}
    printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
        || fail 'Latest GitHub release tag must look like v0.3.1.'
    zipurl="https://github.com/$repo/releases/download/$tag/visual-library-koreader-v$version.zip"
    curl --fail --location --silent --show-error --connect-timeout 8 --max-time 90 \
        "$zipurl" -o "$work/visual_library.zip" || fail 'Could not download the Visual Library release ZIP.'
    bytes=$(wc -c < "$work/visual_library.zip" | tr -d ' ')
    [ "$bytes" -ge 3000 ] && [ "$bytes" -le 10000000 ] || fail 'Downloaded release size is unexpected.'
    # Allow exactly a flat set of plugin files and the containing directory.
    # Inspect the archive before extraction to reject path traversal.
    entries=$(unzip -l "$work/visual_library.zip" 2>/dev/null | awk '
        /^[- ]*---------/ { section++; next }
        section == 1 && NF >= 4 { print $4 }
    ') || fail 'Unable to inspect ZIP contents.'
    [ -n "$entries" ] || fail 'No plugin files in ZIP.'
    printf '%s\n' "$entries" | while IFS= read -r file; do
        case "$file" in
            visual_library.koplugin/) : ;;
            visual_library.koplugin/*)
                name=${file#visual_library.koplugin/}
                case "$name" in ''|*[!a-zA-Z0-9._-]*|.*|*..*) exit 1 ;; esac ;;
            *) exit 1 ;;
        esac
    done || fail 'ZIP contains unexpected or unsafe file paths.'
    mkdir "$work/extracted"
    unzip -q "$work/visual_library.zip" -d "$work/extracted" || fail 'Could not extract release.'
    source_dir="$work/extracted/visual_library.koplugin"
fi

[ -d "$source_dir" ] || fail 'Plugin folder missing from source.'
[ -z "$(find "$source_dir" -type l -print)" ] || fail 'Plugin source has symlinks.'
for file in _meta.lua main.lua catalog.lua moods.lua visualui.lua updater.lua install_update.sh; do
    [ -f "$source_dir/$file" ] || fail "Plugin source missing $file."
done
if [ -n "$repo" ]; then
    grep -Eq "version[[:space:]]*=[[:space:]]*['\"]$version['\"]" "$source_dir/_meta.lua" \
        || fail 'Downloaded plugin version does not match release tag.'
fi

# Always stage a copy, even for local installs. Never move a source folder.
mkdir "$work/new"
cp -R "$source_dir/." "$work/new/" || fail 'Could not stage plugin files.'
[ -f "$work/new/main.lua" ] || fail 'Staged plugin is incomplete.'
# Keep a single previous version for rollback. Defer deleting the old backup
# until the new version is safely installed.
if [ -e "$backup" ]; then
    mv "$backup" "$work/older_backup" || fail 'Could not preserve previous backup.'
fi
if [ -d "$plugin" ]; then
    if ! mv "$plugin" "$backup"; then
        [ ! -d "$work/older_backup" ] || mv "$work/older_backup" "$backup"
        fail 'Could not back up current Visual Library installation.'
    fi
fi
if mv "$work/new" "$plugin"; then
    say "Visual Library installed at $plugin"
    if [ -d "$backup" ]; then say "Previous version: $backup"; fi
    say 'Saved moods, queue, and other KOReader settings were not changed.'
    say 'Restart KOReader fully before opening Visual Library.'
else
    # Restore any previous installation if the final rename fails.
    if [ -d "$backup" ] && [ ! -e "$plugin" ]; then mv "$backup" "$plugin" || :; fi
    if [ -d "$work/older_backup" ] && [ ! -e "$backup" ]; then mv "$work/older_backup" "$backup" || :; fi
    fail 'Installation failed. Previous version was restored when possible.'
fi
