# Reading Brain v0.6.0

A cleanup release focused on making Reading Brain feel like one coherent KOReader plugin.

## Simplified main menu

```text
Reading Brain
├── Discover Books
├── Taste Profile
├── Reading Overview
├── Recent Sessions
├── Stats & Patterns
│   ├── By Month
│   ├── Ratings & Taste
│   ├── Reading Habits
│   └── Patterns & Records
├── Data & Sync
│   ├── Sync Reading History
│   └── Data Status
└── Settings & Updates
    ├── Notify on wake when update available
    ├── Check for Updates
    ├── Restore Previous Version
    └── About
```

## What was simplified

- `Unified Summary`, `This Year`, and `Reading Formats` are consolidated into **Reading Overview**.
- `Ratings` and `Authors & Genres` are consolidated into **Ratings & Taste**.
- `Interesting Patterns` and `Reading Records` are consolidated into **Patterns & Records**.
- legacy `Analyze Bookmory Backup` becomes **Data Status** and lives beside sync.
- updater controls and About are grouped under **Settings & Updates**.
- all informational result screens use the same Reading Brain card UI.
- long cards remain scrollable.
- zero-length reading sessions remain filtered out.
- Bookshelf-style wake update notifications are preserved.

The discovery list stays tappable and native, while selected-book details use the Reading Brain card UI.
