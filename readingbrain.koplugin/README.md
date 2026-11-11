# Reading Brain v0.8.0

Reading Brain is a personal reading-history and discovery plugin for KOReader.

## Main menu

- Discover Books
- Taste Profile
- Reading Overview
- Stats & Patterns
- Data & Sync
  - Sync Reading History
  - Data Status
- Settings & Updates
  - Check for Updates
  - Restore Previous Version
  - About

Updates are manual-only. Reading Brain does not check for updates on wake.

## v0.8.0 highlights

### Data reliability

- `/mnt/us/readingbrain/` is the only Bookmory backup source.
- The newest Bookmory backup is selected from its filename date/time, with file modification time only as a fallback.
- Stats pages show both the latest Bookmory backup date and the backup date used by the unified-history cache.
- A newer unsynced backup is clearly labeled.
- Unified summaries distinguish source-logged time from overlap-adjusted elapsed reading time.
- Sync rebuilds the Reading Brain cache inside a transaction so a failed rebuild can roll back instead of leaving a half-written cache.

### Stats & Patterns

Stats & Patterns is a five-page viewer:

1. By Month
2. Ratings & Taste
3. Reading Habits
4. Patterns
5. Records

The visual square bars are preserved.

Patterns can include, when enough evidence exists:

- reading momentum
- format shift
- weekend vs weekday behavior
- time-of-day tendency
- reliable and unpredictable taste signals
- fastest obsession
- biggest comeback
- slow-burn favorite
- binge tendency
- recent taste drift

Records include:

- longest session
- most intense reading day
- strongest month
- longest active-reading streak
- longest break between reading days
- most elapsed time on one book
- most sessions for one book
- most revisited book
- longest calendar-span read
- Kindle / Audiobook / External-Hybrid title records
- most books and sessions in one day
- fastest high-rated read
- highest-rated recurring author and tag

### Discovery

- Bookmory wishlist-only entries are no longer automatically treated as already read.
- Read/active/paused/give-up books are still excluded from new recommendations.
- Recommendation feedback is applied to a larger candidate pool before the final top five are selected.
- Want to Read is prioritized without adding an arbitrary +100 score.

### Stability and speed

- Feature modules are loaded safely so one broken optional module does not make the entire Reading Brain plugin disappear.
- Bookmory data is cached in memory by backup identity.
- Kindle library scanning is cached for five minutes.
- Recent Sessions and the unused per-book page dependency were removed.
- Wake update notifications were removed; Check for Updates is manual-only.

## Bookmory backup

Copy the current Bookmory backup to:

`/mnt/us/readingbrain/`

Then choose:

`Reading Brain → Data & Sync → Sync Reading History`
