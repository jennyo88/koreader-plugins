# Reading Brain v0.7.0 feature pack

This release is designed around three improvements without adding menu clutter.

## Backup health

Reading Brain can now distinguish:

- `CURRENT` — backup is 0–6 days old
- `AGING` — backup is 7–13 days old
- `STALE` — backup is 14+ days old
- `NEW BACKUP` — a newer Bookmory backup exists than the one last synced
- `MISSING` — no Bookmory backup is available

The intended UI is a short status word in the top-right corner of the Data Status card.

## Discovery feedback

Recommendation feedback states:

- Want to Read
- Not for Me
- Already Own

`Want to Read` boosts future ranking.
`Not for Me` and `Already Own` are excluded from future results.

Feedback is stored separately from the Reading Brain database so rebuilding unified history does not erase it.

## Per-book Reading Brain page

A book page is intended to open from Recent Sessions and show:

- session count
- total reading time
- average session
- longest session
- first and last session dates
- Kindle vs Audiobook vs External/Hybrid time
- Bookmory progress
- Bookmory rating

This avoids another top-level menu item while making Recent Sessions substantially more useful.

## Files

Upload these new files to `readingbrain.koplugin/`:

- `backup_health.lua`
- `feedback.lua`
- `book_page.lua`

Then integrate the small `main.lua` changes described in `MAIN-INTEGRATION.md`.
