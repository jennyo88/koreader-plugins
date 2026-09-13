# Reading Brain v0.2.0

Reading Brain creates a separate unified reading history from:

- KOReader reading statistics
- Bookmory timed reading sessions

It never writes to KOReader's own statistics database.

## Data model

Reading Brain distinguishes **source** from **medium**.

Sources:

- KOReader
- Bookmory

Media:

- Kindle
- Audiobook
- External/Hybrid

Bookmory records explicitly marked `audioBook` are imported as **Audiobook**.

Bookmory sessions for text-capable books are deliberately imported as **External/Hybrid**, because those sessions may represent audiobook listening, immersive reading, or another external reading mode.

KOReader sessions are imported as **Kindle**.

## Reading Brain database

Reading Brain writes only to:

```text
/mnt/us/readingbrain/readingbrain.sqlite3
```

Re-syncing rebuilds this cache from the source data.

## KOReader sessions

KOReader's statistics plugin stores page-level timing rows rather than explicit session objects.

Reading Brain groups those rows into sessions. A gap of more than **10 minutes** starts a new session.

This does not alter the source database.

## Menu

```text
Tools
└── Reading Brain
    ├── Sync Unified History
    ├── Unified Summary
    ├── Recent Sessions
    ├── Analyze Bookmory Backup
    ├── Check for Updates
    ├── Restore Previous Version
    └── About
```

## Safety

Reading Brain does **not** modify:

- KOReader `statistics.sqlite3`
- Bookmory backups
- EPUB files

The only generated database is Reading Brain's own cache.
