#!/bin/sh
# Visual Library release installer, called by updater.lua only.
# POSIX shell; stages and validates before changing the live plugin.
set -eu

say_error() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
[ "$#" -eq 3 ] || say_error 'Expected repository, release tag, and plugin directory.'
repo=$1
tag=$2
plugin=$3
case "$repo" in
  */*) : ;;
  *) say_error 'Invalid GitHub repository.' ;;
esac
case "$repo" in *[!a-zA-Z0-9._/-]*|*..*|*//* ) say_error 'Invalid GitHub repository.' ;; esac
case "$tag" in
  v[0-9]*.[0-9]*.[0-9]*|[0-9]*.[0-9]*.[0-9]*) : ;;
  *) say_error 'Invalid release tag.' ;;
esac
version=${tag#v}
case "$version" in *[!0-9.]*|.*|*..*|*.) say_error 'Invalid semantic version.' ;; esac
# Whitelist plugin target. The update must only replace this plugin's own directory.
case "$plugin" in /*/visual_library.koplugin) : ;; *) say_error 'Unexpected plugin path.' ;; esac
[ -d "$plugin" ] || say_error 'Current Visual Library folder missing.'
parent=${plugin%/*}
work=$(mktemp -d "$parent/.visual_library_update.XXXXXX") || say_error 'Cannot create staging directory.'
cleanup() { rm -rf "$work"; }
trap cleanup EXIT HUP INT TERM

command -v curl >/dev/null 2>&1 || say_error 'curl is not installed.'
command -v unzip >/dev/null 2>&1 || say_error 'unzip is not installed.'

url="https://github.com/$repo/releases/download/$tag/visual-library-koreader-v$version.zip"
curl --fail --location --silent --show-error --connect-timeout 8 --max-time 90 "$url" -o "$work/release.zip" || say_error 'Could not download release ZIP.'
# Limit to plausible small plugin ZIPs, including a lower bound to reject empty responses.
bytes=$(wc -c < "$work/release.zip" | tr -d ' ')
[ "$bytes" -ge 3000 ] && [ "$bytes" -le 10000000 ] || say_error 'Unexpected release ZIP size.'

# Use the minimal supported `unzip -l` interface. Reject all paths except direct
# files in visual_library.koplugin/; prevents archive traversal and nested content.
entries=$(unzip -l "$work/release.zip" 2>/dev/null | awk '
    /^[- ]*---------/ { section++; next }
    section == 1 && NF >= 4 { print $4 }
') || say_error 'Cannot inspect release ZIP.'
[ -n "$entries" ] || say_error 'Release ZIP contains no listed files.'
printf '%s\n' "$entries" | while IFS= read -r file; do
    case "$file" in
        visual_library.koplugin/) : ;;
        visual_library.koplugin/*)
            name=${file#visual_library.koplugin/}
            case "$name" in
                ''|*[!a-zA-Z0-9._-]*|.*|*..*) exit 1 ;;
            esac
            ;;
        *) exit 1 ;;
    esac
done || say_error 'Release ZIP contains unexpected paths.'

mkdir "$work/extracted" || say_error 'Cannot prepare extraction.'
unzip -q "$work/release.zip" -d "$work/extracted" || say_error 'Release ZIP could not be unpacked.'
staged="$work/extracted/visual_library.koplugin"
for name in _meta.lua main.lua catalog.lua visualui.lua moods.lua updater.lua install_update.sh; do
    [ -f "$staged/$name" ] || say_error "Release missing $name."
done
[ -z "$(find "$staged" -type l -print)" ] || say_error 'Release contains symbolic links.'
# Check the metadata version matches the published tag before touching the live files.
grep -Eq "version[[:space:]]*=[[:space:]]*['\"]$version['\"]" "$staged/_meta.lua" || say_error 'Release metadata version mismatch.'

# Keep only one previous copy, outside the plugin, for manual rollback.
backup="$parent/.visual_library.koplugin.previous"
if [ -e "$backup" ]; then
    old_backup="$work/previous"
    mv "$backup" "$old_backup" || say_error 'Cannot move older backup.'
fi
if ! mv "$plugin" "$backup"; then
    if [ -e "$work/previous" ]; then mv "$work/previous" "$backup"; fi
    say_error 'Cannot back up the current plugin.'
fi
if mv "$staged" "$plugin"; then
    printf 'Installed Visual Library %s. Restart KOReader.\n' "$version"
    exit 0
fi
mv "$backup" "$plugin" || say_error 'Installation failed; backup needs manual restoration.'
if [ -e "$work/previous" ]; then mv "$work/previous" "$backup"; fi
say_error 'Installation failed; previous version restored.'
