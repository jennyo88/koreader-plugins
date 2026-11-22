#!/bin/sh
set -eu

ROOT="${1:-.}"
PLUGIN_DIR="${ROOT}/readingbrain.koplugin"
MANIFEST="${ROOT}/manifest.json"

if [ ! -d "${PLUGIN_DIR}" ]; then
    echo "ERROR: ${PLUGIN_DIR} not found"
    exit 1
fi

if [ ! -f "${MANIFEST}" ]; then
    echo "ERROR: ${MANIFEST} not found"
    exit 1
fi

python3 -m json.tool "${MANIFEST}" >/dev/null

echo "manifest.json: valid JSON"

python3 - "${ROOT}" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
manifest = json.loads((root / "manifest.json").read_text())
plugins = manifest.get("plugins")
if not isinstance(plugins, dict):
    raise SystemExit("manifest.json must contain a top-level 'plugins' object")
entry = plugins.get("readingbrain")
if not isinstance(entry, dict):
    raise SystemExit("manifest.json is missing plugins.readingbrain")
version = str(entry.get("version", ""))
files = entry.get("files")
if not version or not isinstance(files, list):
    raise SystemExit("Reading Brain manifest entry needs version and files")
plugin_dir = root / "readingbrain.koplugin"
missing = [name for name in files if not (plugin_dir / name).is_file()]
if missing:
    raise SystemExit("Manifest lists missing files: " + ", ".join(missing))
main = (plugin_dir / "main.lua").read_text()
meta = (plugin_dir / "_meta.lua").read_text()
main_match = re.search(r'local PLUGIN_VERSION\s*=\s*"([^"]+)"', main)
meta_match = re.search(r'version\s*=\s*"([^"]+)"', meta)
if not main_match or not meta_match:
    raise SystemExit("Could not read version from main.lua/_meta.lua")
versions = {version, main_match.group(1), meta_match.group(1)}
if len(versions) != 1:
    raise SystemExit(
        "Version mismatch: manifest=%s main=%s meta=%s"
        % (version, main_match.group(1), meta_match.group(1))
    )
legacy = {"update_notifier.lua", "book_page.lua"}
listed_legacy = sorted(legacy.intersection(files))
if listed_legacy:
    raise SystemExit("Legacy files remain in manifest: " + ", ".join(listed_legacy))
print("manifest files: present")
print("versions: aligned at " + version)
print("legacy dependencies: absent")
PY

if command -v luac5.1 >/dev/null 2>&1; then
    LUA_CHECK=luac5.1
elif command -v luac >/dev/null 2>&1; then
    LUA_CHECK=luac
else
    LUA_CHECK=""
fi

if [ -n "${LUA_CHECK}" ]; then
    for FILE in "${PLUGIN_DIR}"/*.lua; do
        "${LUA_CHECK}" -p "${FILE}"
    done
    echo "Lua syntax: OK"
else
    echo "WARNING: luac was not found; Lua syntax check skipped."
fi
