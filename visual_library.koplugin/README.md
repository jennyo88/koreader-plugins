# Visual Library for KOReader — v0.2.0 (design update)

A monochrome, offline visual EPUB library and mood-based book picker designed for the Kindle Paperwhite 7th generation.

## What changed in v0.2.0

- **Editorial home screen:** clear title hierarchy, a prominent **Explore by mood** action, and smaller supporting actions.
- **Mood Picker:** eight large, two-column mood choices. Selected moods use a high-contrast, inverted style, with a clear selection count and a full-width **Find my books** action.
- **Continue Reading:** a tidy cover-and-details card. The book title no longer repeats underneath the cover.
- **Library covers:** slimmer frames, more consistent cover sizes and caption spacing; noncached books use deliberate high-contrast typographic placeholders (no EPUB opening).
- **Navigation:** compact header, subtle divider lines and bottom-aligned navigation rather than controls floating halfway up the screen.
- **Other screens:** calmer typography and headings for shelves, matches, reading queue and book details.
- **Refresh fix retained:** navigation between screens still uses a full KOReader refresh; same-screen selection uses a UI refresh.

All queues, mood selections, tags, and shelf preferences continue to be stored independently in `koreader/settings/visual_library.lua`. This release does not migrate or reset that file.

## Features

- Home: Mood Picker, most recently opened EPUB, queue preview and shelf shortcuts.
- Mood Picker: eight emotions; multiple selections, explicit per-book tags and ranked matches.
- Book catalog: local EPUB scanning; three-column, paginated grayscale cover gallery; uses previously cached Cover Browser images when present.
- Shelves: All Books, Current Reading, Up Next, Quick Read, Paused and Latest.
- Queue: add, remove and reorder books; persists through restarts.
- Book details: cached title, author, series, editable mood tags and book actions.
- `Start with → visual library` integration (opt-in).
- No internet required, no artificial reading sessions created by extracting covers.

## Update from v0.1.1

1. Exit Visual Library, then completely exit KOReader.
2. Extract `visual-library-koreader-v0.2.0.zip`.
3. Replace the complete folder `/mnt/us/koreader/plugins/visual_library.koplugin/` with the folder from the archive.
4. **Keep** `/mnt/us/koreader/settings/visual_library.lua` — it contains your queue and personal mood tags.
5. Restart KOReader. Open **Tools → More tools → Visual Library**, or use your saved **Start with** option.
6. Test **Explore by mood**, switch a few moods on/off, then visit **Shelves** and **Queue**.

If you'd rather revert, replace only the plugin folder with the previous v0.1.1 version, without touching the settings file.

## Notes and limitations

- This is an **alpha build**. The Lua sources have been syntax-checked, and screen/layout construction was tested in a simulated widget environment at 758×1024 and 1072×1448. The layout still requires **real Kindle testing**.
- No integration yet with Bookmory, custom third-party Bookshelf shelves or exact completion percentages.
- Cached Cover Browser artwork appears where it already exists. Missing covers remain placeholders; the plugin never opens EPUBs for the sole purpose of importing covers.
- Scan up to 900 EPUBs under KOReader's Home folder (maximum depth 7). Select **Visual Library → Refresh EPUB catalog** from the Tools menu if you add new books.
- To disable automatic launch, change **Start with** to another option in the KOReader file manager.
- If you notice another partial refresh or clipped page, provide a photo of that exact screen and, if applicable, KOReader's `crash.log`.
