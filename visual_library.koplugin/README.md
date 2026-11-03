# Visual Library for KOReader · early prototype v0.1.1

**Made for monochrome Kindle Paperwhite (7th generation) and EPUB libraries.**

## Fix in v0.1.1: screen navigation & refresh
- Fixes the Home screen remaining visible when tapping **Find by mood**.
- Marks Visual Library as a full-screen opaque window.
- Performs a full repaint/refresh when changing screens, and a lighter UI refresh when reloading the same screen.
- Schedules navigation after input handling to prevent partially displayed pages.
- Closing the plugin refreshes the underlying KOReader file manager.
- Update without deleting `koreader/settings/visual_library.lua`; existing mood tags, queue and shelf selections are retained.

## Features in this build
- Home: prominent Mood Picker, last EPUB, queue preview, and shelves.
- Mood Picker: eight emotional moods; multi-select, explicit per-book mood tags, ranked results, and Surprise Me.
- E Ink cover gallery: three columns, paginated; uses **existing** KOReader Cover Browser cover cache when available, with text placeholders otherwise.
- Shelves: All books, Current Reading (last opened), Up Next (Visual Library queue), Quick Read, Paused, Latest (KOReader history).
- Queue: add/remove, change order, persistent across restarts.
- Book details: metadata, series, tags, queue/paused/quick actions, open EPUB.
- `Start with → visual library` entry on KOReader File Manager screen (opt-in).
- Settings stored independently at `koreader/settings/visual_library.lua`.

This does **not** import your custom Bookshelf plugin categories or Bookmory data, nor does it automatically extract missing covers or derive accurate reading-progress percentages. Those integrations need real-device testing. It never opens a book just to index it, preventing 0-minute reading sessions.

## Installation
1. Unzip this archive. Its top folder should be `visual_library.koplugin`.
2. Copy that complete folder to `/mnt/us/koreader/plugins/` on Kindle (also visible as `koreader/plugins/` when mounted by USB).
3. Restart KOReader.
4. From KOReader's file manager, open **Tools → More tools → Visual Library → Open Visual Library**. Or use the filing-cabinet menu **Start with → visual library**.
5. From *Shelves*, tap a book and choose **Edit mood tags**. Select several emotions, then go to *Moods* and select your desired combinations.

## Troubleshooting
- If the plugin is not shown, check the folder is exactly `visual_library.koplugin`, with `_meta.lua`, `main.lua`, `visualui.lua`, `catalog.lua`, and `moods.lua` directly inside it, and that the plugin is enabled in KOReader Plugin management.
- If the gallery shows only text tiles, the corresponding books do not yet have covers cached by Cover Browser. You can use the existing Cover Browser gallery or its extraction action to populate its cache.
- If few books appear, ensure KOReader **Home folder** points to the parent folder of your EPUBs. The catalog scans EPUB files under that folder (depth 7, up to 900 entries), and can be refreshed from **Visual Library → Refresh EPUB catalog**.
- To **stop opening at startup**, select another choice in **Start with** from the KOReader File Manager. To **completely disable**, turn off Visual Library in Plugin management.
- Do **not** delete your EPUBs or `.sdr` directories. Removing `koreader/settings/visual_library.lua` resets *only* Visual Library tags, queue, and paused/quick shelves.
- For a crash, disable the plugin in Plugin management and check KOReader's `crash.log` and `settings/visual_library.lua`.

## Limitations / validation
This ZIP has been statically checked but **not tested on a real Kindle**. KOReader plugin APIs may differ from the source checked in November 2026 or from the user's installation. Please test launching from the Tools menu before selecting it under Start with.

The code uses KOReader libraries loaded by KOReader; running it with a stock Lua interpreter alone does not display its UI. No changes are made to Bookshelf's files or Calibre data.

## Updating from v0.1.0
1. Exit Visual Library and KOReader fully.
2. Replace the complete `koreader/plugins/visual_library.koplugin` folder with the v0.1.1 folder.
3. Restart KOReader, enter Visual Library from the file manager, and tap **Find by mood**.
4. If the old home controls still appear, send a new photo and check `koreader/crash.log`.

Avoid deleting `koreader/settings/visual_library.lua`: it stores your personal choices.
