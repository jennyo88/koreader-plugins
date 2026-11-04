# Visual Library v0.3.1 — KOReader plugin

A compact, offline reading room and mood-based EPUB picker for KOReader, designed with the Kindle Paperwhite 7th generation in mind. **This plugin does not modify Bookshelf.**

## What's new

- **Reading Room home**: four quick mood choices, compact Continue Reading, and an Up Next row of real cached cover thumbnails.
- **Mood Picker**: eight selectable emotions, with shorter labels and a simple Show matches action. Multiple moods can be combined.
- **Mood Shelf results**: book covers in a three-column grid, with a short explanation of each match beneath the cover. Filter to all books, not opened here, or paused books.
- **Cover indicators**: series-number pill at the top-right, total pages for unread books, **estimated pages remaining** for books in progress, a completion mark for finished books, and a thin progress bar.
- **Queue**: cover thumbnails beside each entry, with the same reorder/remove controls.
- **Refreshed gallery proportions**: centered, portrait-format covers rather than stretched square thumbnails.

**Pages remaining are approximate for reflowable EPUBs** because the displayed page count and saved percent progress can use different pagination bases. The badge is prefixed with `~` when estimated. Missing page counts stay hidden. These data are read from KOReader's existing cover cache and book sidecars; no EPUB is opened solely to index it.

## Install and update from the companion shell script

The companion `install-visual_library.sh` is distributed **beside** the `visual_library.koplugin` folder, not inside it. Place both in the same directory and run:

```sh
sh install-visual_library.sh
```

The script finds `/mnt/us/koreader/plugins` on Kindle and replaces **only** `visual_library.koplugin` with the adjacent local folder. It stages files first and keeps the previous version as `plugins/.visual_library.koplugin.previous`. The `koreader/settings/visual_library.lua` settings file is never changed. Exit KOReader before running the script, then restart it.

If your KOReader plugins directory differs:

```sh
sh install-visual_library.sh --target /path/to/koreader/plugins
```

After publishing to GitHub Releases, the same script can download the latest release from your repository:

```sh
sh install-visual_library.sh --repo OWNER/REPOSITORY
```

A release must have a semantic-version tag (e.g. `v0.3.1`) and attach `visual-library-koreader-v0.3.1.zip`, containing **only** the `visual_library.koplugin/` folder. The installer does not have a built-in repository URL.

## Update from inside KOReader

Under **Tools → More tools → Visual Library → Settings & Updates**:

1. Choose **Set GitHub update repository** and enter `OWNER/REPOSITORY` after you publish Visual Library.
2. Choose **Check for updates**. The plugin compares the installed version to the latest GitHub Release.
3. Confirm installation when a newer release is available; restart KOReader to load it.

Update checks are manual and require Wi-Fi and `curl` plus `unzip` on the Kindle. They do not run at startup. The updater preserves the `visual_library.lua` settings file and never writes to Bookshelf. **An update cannot be downloaded until you have published a GitHub Release.**

## Upgrade from v0.3.0

1. Exit KOReader completely.
2. Extract the ZIP, then copy the included `visual_library.koplugin` directory to `/mnt/us/koreader/plugins/`, replacing the older plugin directory.
3. **Do not delete** `/mnt/us/koreader/settings/visual_library.lua`. It stores mood selections, per-book mood tags, queue order, and Visual Library shelf preferences.
4. Restart KOReader, then open **Tools → More tools → Visual Library** or use your opt-in **Start with → visual library** option.
5. Test **Home → Mood → Show matches**, open a match, and check **Shelves** and **Queue**.

If there is a problem, exit KOReader and restore only the `visual_library.koplugin` directory from the v0.3.0 ZIP. Leave the settings file intact.

## Features retained

- Offline local EPUB catalog (scan up to 900 files, maximum directory depth 7).
- Read-only use of existing Cover Browser metadata and cached covers.
- Reading queue, Quick Read list, Paused shelf, and book-level mood tags.
- Open EPUB directly from book details or Continue Reading.
- Optional **Start with** integration.
- Full E Ink refresh on page changes to prevent overlay/ghost refresh errors.
- No network dependency, no Bookmory or Bookshelf data changes.

## Notes

- **Alpha version:** The v0.3.0 UI was syntax-checked and simulated at Paperwhite resolutions. The v0.3.1 updater and installation script have not yet been tested on your physical Kindle. Test manually before selecting Start with.
- Badges require saved sidecar or cached metadata. For books without a known page count or series index, there is no corresponding badge.
- Mood matches depend on user-assigned tags or existing EPUB/Calibre keywords. Untagged books are not assigned fictional mood matches.
- To update the catalog after copying new books, use **Tools → More tools → Visual Library → Refresh EPUB catalog**.
- To disable automatic launch, select a different item under KOReader's **Start with** menu.
- If a screen clips or overlaps, send a photo of the problem screen and the KOReader `crash.log` if present.
