# Reading Brain 0.8.0 Recovery

This is a clean, internally consistent recovery release for KOReader.

## Menu

- Discover Books
- Taste Profile
- Reading Overview
- Stats & Patterns
- Data & Sync
- Settings & Updates

Recent Sessions has been removed from the main menu.

## Stats & Patterns

Stats opens as a paged viewer:

1. By Month
2. Ratings & Taste
3. Reading Habits
4. Patterns & Records

Each page shows the date of the newest Bookmory backup.

## Data

Put Bookmory backups in:

`/mnt/us/readingbrain/`

Then use:

Reading Brain → Data & Sync → Sync Reading History

## Recovery design

Automatic updater/network wake checks are intentionally conservative in this build so optional update features cannot make the plugin disappear.
