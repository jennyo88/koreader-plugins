# Reading Brain v0.1.1

Experimental, read-only KOReader plugin for combining Bookmory and Kindle/KOReader reading data.

## What v0.1.0 does

- Finds the newest `.bookmory` backup.
- Extracts `new_bookmory.db` with KOReader's archive reader.
- Reads the Bookmory SQLite database with KOReader's bundled SQLite library.
- Counts Bookmory books, reads, timed sessions, and total logged time.
- Separates explicit `audioBook` sessions from neutral external/hybrid sessions.
- Scans EPUBs in `/mnt/us/koreader/books`.
- Performs conservative title/author matching.
- Shows a summary.

## What it does NOT do

It does not import, merge, overwrite, or modify KOReader reading statistics.

This version is intentionally read-only.

## Backup location

Create:

```text
/mnt/us/readingbrain/
```

and copy your latest `.bookmory` backup there.

The plugin also checks a few common top-level Kindle folders.

## Menu

```text
Tools
└── Reading Brain
    ├── Analyze Bookmory Backup
    └── About
```

## Matching

v0.1.0 only performs conservative exact normalized title matching with author verification where metadata is available.

Ambiguous matches are counted as **Needs review** rather than guessed.


## Built-in updater

Reading Brain now uses the same updater pattern as the other personal KOReader plugins.

Menu:

```text
Tools
└── Reading Brain
    ├── Analyze Bookmory Backup
    ├── Check for Updates
    ├── Restore Previous Version
    └── About
```

The updater:

- checks the root `manifest.json` in `jennyo88/koreader-plugins`
- downloads updates from `readingbrain.koplugin/`
- stages files in `/tmp`
- backs up the previous plugin version
- offers **Restart now / Restart later**
- can restore the previous version
