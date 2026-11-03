# Threadlight · KOReader plugin

A free, offline, spoiler-aware story-memory tool for readers who switch between several books or return after long breaks. **Version 1.0.**

## What it does

- **Save a checkpoint:** Two brief prompts: “What just happened?” and “What should I remember next time?” Saves your EPUB location and date.
- **Start a story thread:** Track a character, mystery, unanswered question, or relationship, add updates, then mark it resolved or reopen it.
- **Previously…:** Compact catch-up card with the last three checkpoints and up to ten unresolved threads, limited to the reader's current place in the book.
- **Spoiler curtain:** Notes from later in the book are concealed when you navigate backward, based on KOReader's EPUB XPointer comparison (fallback: approximate percentage).
- **Jump to scene:** Return to the position where a checkpoint or thread update was saved, and use KOReader's Back location stack to return.
- **Optional 7-day return reminder:** Off by default.
- **Gesture actions:** `Threadlight: recall the story`, `Threadlight: save a checkpoint`, and `Threadlight: view story threads`.

## Install

1. Extract this ZIP. It contains **`threadlight.koplugin/`** directly at the archive root.
2. Copy that entire folder to **`koreader/plugins/threadlight.koplugin/`** on your Kindle (merge with the existing `plugins/` directory, but do not overwrite other plugins).
3. Restart KOReader. If necessary, enable **Threadlight** in **Tools → Plugin management**, then restart.
4. Open an EPUB. Find **Threadlight** in the reader's main/top menu (often under Tools).

### On-device terminal / curl

Once the ZIP is on the Kindle, from its KOReader directory (the directory containing `plugins/`):

```sh
unzip -o /path/to/threadlight-koreader-v1.0.zip -d .
```

If you host the ZIP at your own URL, download with `curl -L -o /tmp/threadlight.zip 'https://YOUR-URL/threadlight-koreader-v1.0.zip'` and extract with `unzip -o /tmp/threadlight.zip -d /path/to/koreader/`. The ChatGPT attachment's link is not a direct public curl URL.

## Notes, design limits & privacy

- **No invented summaries:** The notes are written by *you*; this does not use an LLM, Internet, OCR, or the EPUB text itself.
- **Intended for reflowable EPUBs**, especially e-ink Kindles. The menu is disabled for fixed-layout documents.
- The text position comparison works for valid EPUB XPointers. If an EPUB is replaced with an altered copy, positions may become invalid. The percentage fallback can be approximate when page layout changes.
- Notes are stored inside KOReader's per-book **sidecar settings** using the `threadlight_v1` key, not in a central database. **Back up the `.sdr` folders** with your Calibre/KOReader backup routine. Notes may not follow a moved or replaced file unless its sidecar is preserved.
- There are no automatic book-wide summaries, character extraction, or syncing to Bookmory. These require capabilities KOReader does not provide reliably or offline without additional services.
- The screen never needs to display more than two text input fields at once. Long histories use the scrollable TextViewer; lists are paginated.
- Uninstall: close KOReader and delete `koreader/plugins/threadlight.koplugin/`. This will not deliberately erase the sidecar data. To erase saved content, delete the `threadlight_v1` entry from the relevant sidecar manually or delete the whole sidecar **only if you accept losing unrelated KOReader book settings and annotations**.

## Technical

Lua 5.1/LuaJIT-compatible pure Lua; KOReader's `WidgetContainer`, `Menu`, `TextViewer`, `InputDialog`, `MultiInputDialog`, `DocSettings`, `Dispatcher`, and EPUB XPointer APIs. No third-party dependency or Lua patch. Designed from source inspection of KOReader's current GitHub master in November 2026. **Not tested on a physical Kindle or a live KOReader installation.**
