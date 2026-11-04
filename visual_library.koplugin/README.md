# Visual Library v0.3.0 — KOReader plugin

A compact, offline reading room and mood-based EPUB picker for KOReader, designed with the Kindle Paperwhite 7th generation in mind. **This plugin does not modify Bookshelf.**

## What's new

- **Reading Room home**: four quick mood choices, compact Continue Reading, and an Up Next row of real cached cover thumbnails.
- **Mood Picker**: eight selectable emotions, with shorter labels and a simple Show matches action. Multiple moods can be combined.
- **Mood Shelf results**: book covers in a three-column grid, with a short explanation of each match beneath the cover. Filter to all books, not opened here, or paused books.
- **Cover indicators**: series-number pill at the top-right, total pages for unread books, **estimated pages remaining** for books in progress, a completion mark for finished books, and a thin progress bar.
- **Queue**: cover thumbnails beside each entry, with the same reorder/remove controls.
- **Refreshed gallery proportions**: centered, portrait-format covers rather than stretched square thumbnails.

**Pages remaining are approximate for reflowable EPUBs** because the displayed page count and saved percent progress can use different pagination bases. The badge is prefixed with `~` when estimated. Missing page counts stay hidden. These data are read from KOReader's existing cover cache and book sidecars; no EPUB is opened solely to index it.

## Upgrade from v0.2.1

1. Exit KOReader completely.
2. Extract the ZIP, then copy the included `visual_library.koplugin` directory to `/mnt/us/koreader/plugins/`, replacing the older plugin directory.
3. **Do not delete** `/mnt/us/koreader/settings/visual_library.lua`. It stores mood selections, per-book mood tags, queue order, and Visual Library shelf preferences.
4. Restart KOReader, then open **Tools → More tools → Visual Library** or use your opt-in **Start with → visual library** option.
5. Test **Home → Mood → Show matches**, open a match, and check **Shelves** and **Queue**.

If there is a problem, exit KOReader and restore only the `visual_library.koplugin` directory from the v0.2.1 ZIP. Leave the settings file intact.

## Features retained

- Offline local EPUB catalog (scan up to 900 files, maximum directory depth 7).
- Read-only use of existing Cover Browser metadata and cached covers.
- Reading queue, Quick Read list, Paused shelf, and book-level mood tags.
- Open EPUB directly from book details or Continue Reading.
- Optional **Start with** integration.
- Full E Ink refresh on page changes to prevent overlay/ghost refresh errors.
- No network dependency, no Bookmory or Bookshelf data changes.

## Notes

- **Alpha version:** Lua files were syntax-checked and all six pages were constructed in a mocked widget environment at 758×1024 and 1072×1448. **Not yet tested on the physical Kindle after this update.**
- Badges require saved sidecar or cached metadata. For books without a known page count or series index, there is no corresponding badge.
- Mood matches depend on user-assigned tags or existing EPUB/Calibre keywords. Untagged books are not assigned fictional mood matches.
- To update the catalog after copying new books, use **Tools → More tools → Visual Library → Refresh EPUB catalog**.
- To disable automatic launch, select a different item under KOReader's **Start with** menu.
- If a screen clips or overlaps, send a photo of the problem screen and the KOReader `crash.log` if present.
