# Minimal Shelf — KOReader plugin (v0.3.0 cover gallery prototype)

A lightweight, offline-first library organizer for the **Kindle Paperwhite 3 / 7th generation**.
It uses KOReader's bundled Lua modules and a native list menu. No external plugins,
Calibre desktop connection, or Wi-Fi are required during normal use.

## Current features

- Manual offline book-library scan, with a limit of 400 ebook files and depth 7
- Numeric series sorting, next-in-series suggestions, and missing-number hints
- Short Reads filtering (75, 100, or 150 pages, total or remaining)
- **Cover gallery**: 2 × 2 book cards with covers, title, series badge and pages left
- Manual **Extract book covers (offline)** using KOReader's bundled Cover Browser
- Book-display preference: Covers (default) or Text lists
- Inline badges: `#2 | 85 left` or `#2 | ~85 left (Calibre)`
- **Extract page counts (offline)** from existing KOReader and Calibre metadata
- **Page counts** list sorted shortest to longest; books with unknown counts sort last
- Check for updates from GitHub **only on explicit request** (version check only)
- No scheduled tasks, startup networking, wake-time requests, or automatic Wi-Fi

## How cover images work

**Minimal Shelf now displays covers in book views.** The home screen, Continue Reading,
Next in Series, Short Reads, Page Counts, All Indexed Books and individual
Series book lists show four large covers per page, with book titles and
series/page-count labels beneath. Use Previous / Next to page through books,
and tap a cover to open its book. The Series index (series names) and main
plugin menu remain text menus.

Covers come from KOReader's **bundled Cover Browser cache**, not an online
service. The gallery loads at most four cached cover images at once. If a
book has no cached image, its title appears as a clean placeholder cover.

To fill missing covers:

1. Enable **Cover Browser** under KOReader's plugin manager and restart.
2. Open **Minimal Shelf → Settings & updates → Extract book covers (manual, offline)**.
3. Confirm the bundled Cover Browser extraction prompts. Choose whether to
   include subdirectories; extraction can consume CPU and battery, so consider
   plugging in your Kindle for large libraries.
4. Reopen the Minimal Shelf book list to see the new covers.

Extraction is never scheduled or triggered on startup, wake, or page turns.
The **Book display: Covers / Text lists** option switches the book view.
The Minimal Shelf menu opens a cover-first home view once the library is indexed.
Tap **Sections** to open the full text navigation menu. This does not replace
KOReader's initial File Browser home screen. Actual image rendering has not been device-tested.

## How page extraction works

Select **Minimal Shelf → Settings & updates → Extract page counts (offline)**.
The scan only reads saved metadata and displays the number of books found per source.
It does not render unopened EPUBs or create new pagination data.

Source priority, highest to lowest:

1. **KOReader layout pages:** `doc_pages` saved in the book's sidecar after it was opened
   and rendered. The number describes its **last saved reading layout**; changes to
   font, margin or line spacing require opening/rerendering the book to refresh it.
2. **Calibre pages:** the numeric `#pages` custom column in **`metadata.calibre`** or
   **`.metadata.calibre`**, matching the exact Calibre device path (`lpath`).
   `#page_count` and `#pagecount` are also recognized as custom-column names.
   Calibre pages are *not* KOReader screen pages. Badges use `~` and `(Calibre)`.
3. **Document pages:** Cover Browser's existing page count, when known, for fixed-layout
   files such as PDF.
4. **Unknown:** no reliable saved number. Shows `pages ?` instead of a guessed value.

Remaining pages are calculated from the saved `percent_finished`; when the total
comes from Calibre, **remaining is also an estimate**. If a book has never been
opened, the remaining count is taken as its full total.

### Getting Calibre's `#pages` onto the Kindle

1. In Calibre, create/populate a custom column with lookup name **`#pages`**. For
   example, Calibre's optional *Count Pages* plugin can fill it on your computer.
2. Use Calibre's **Send to device** workflow (or its KOReader wireless transfer)
   so it writes `metadata.calibre` or `.metadata.calibre` containing the per-book
   `user_metadata` and `lpath` entries. A plain filesystem copy of an EPUB may
   **not** transfer this metadata.
3. The `metadata.calibre` file usually lives at the device library root or an
   ancestor folder, with book paths relative to that file. Minimal Shelf checks
   each book directory and up to eight parents, looking for both filenames.
4. After syncing, select **Extract page counts (offline)** again.

The plugin does not read Calibre's desktop `metadata.db`, scan embedded EPUB OPF
custom fields, infer counts from book size/word count, or alter KOReader's
Cover Browser cache. It reads `metadata.calibre` as a snapshot, up to 12 MiB per
file to bound memory usage on the Paperwhite 3. Metadata that does not have a
number for an exact book path remains unknown.

## Install

1. Unzip `minimalshelf-v0.3.0.zip` and copy **`minimalshelf.koplugin/`** into
   `koreader/plugins/` on the Kindle.
2. Restart KOReader; enable **Minimal Shelf** in Plugin management if required.
3. In the KOReader main menu select **Minimal Shelf → Settings & updates →
   Choose library folder** (typically `/mnt/us/documents`).
4. Choose **Refresh library**, then **Extract page counts (offline)** after transferring
   or reading books.
5. The Minimal Shelf entry opens your cover-first shelf; select **Sections** to navigate
  `Continue reading`, `Next in series`, `Book series`,
   `Short reads`, `Page counts`, and `All indexed books` lists.

## Limitations and safety

- **This release adds a basic cover gallery**, but does not replace KOReader's
  built-in startup home screen.
- Badge labels appear underneath cover images, not overlaid on the image.
- The scan runs when selected and may briefly occupy the screen on older Kindles;
  it does not use Wi-Fi. It caches the results in `minimalshelf_settings.lua`.
- Updater checks the `main/minimalshelf.koplugin/update.json` version manifest only
  when selected **and already connected to Wi-Fi**. It reports available updates,
  but the recovery-build updater deliberately does not download/install ZIPs.
- API compatibility and performance have **not been tested on a physical PW3**.
  Back up the existing plugin folder before replacing it.

## Publishing in your existing multi-plugin GitHub repository

Copy the **`minimalshelf.koplugin/`** folder into the root of
[`jennyo88/koreader-plugins`](https://github.com/jennyo88/koreader-plugins)
without replacing existing plugin folders. The root `README.md` and `tests/`
are optional for GitHub; keep your existing repository README if you prefer.

To release a new version, update `main.lua`, `version.lua`, `_meta.lua` and
`update.json` version strings together. The manual check reads
`https://raw.githubusercontent.com/jennyo88/koreader-plugins/main/minimalshelf.koplugin/update.json`.

## Privacy

All reading progress and book metadata remain on the Kindle. None are uploaded.
The only possible network call happens when selecting **Check for updates**.

### Install directly from GitHub on a Kindle

After publishing `minimalshelf.koplugin/` at the root of this repository, copy
`install-minimalshelf.sh` to the Kindle and run it from a shell with Wi-Fi enabled:

```sh
sh install-minimalshelf.sh
```

You can choose another repository by passing `owner/repo` as the first argument,
or another branch with `BRANCH=branchname sh install-minimalshelf.sh`.
The installer downloads every required file before replacing the current plugin
and saves the previous folder to `minimalshelf.koplugin.backup`. No scheduled
checks are created; the installer uses the network only when run manually.
