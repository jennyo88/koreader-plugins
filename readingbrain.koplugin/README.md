<<<<<<< HEAD
# Reading Brain v0.5.0

Reading Brain now includes **Stats & Patterns** with e-ink-friendly visual bars and evidence-based reading observations.

## Stats & Patterns
=======
# Reading Brain v0.4.0

Reading Brain combines your Bookmory history and KOReader statistics, and can now use your ratings to discover books you do not already own.

## Discovery Engine

`Discover Books`:

1. Reads your Bookmory ratings.
2. Builds positive and negative weights from Bookmory tags.
3. Uses the strongest positive traits to fetch English-language candidates from Open Library.
4. Excludes titles already present in Bookmory.
5. Excludes titles already in `/mnt/us/koreader/books`.
6. Scores the remaining candidates using your actual rating-derived taste profile.
7. Shows the top five recommendations with an explanation.

No Open Library account or API key is required.

### Taste Profile

`Taste Profile` shows the strongest positive and negative tag tendencies Reading Brain currently sees in the Bookmory backup.

A 3-star rating is treated as neutral. Ratings above 3 add weight; ratings below 3 subtract weight.

## Built-in update notification

Reading Brain now checks its own entry in your GitHub `manifest.json` quietly on startup/wake.

- checks at most once every 12 hours
- only checks while Wi-Fi is already connected
- does not turn Wi-Fi on
- shows KOReader's small native top-edge notification when a newer Reading Brain version exists
- never installs automatically

You can toggle it in:

```text
Tools → Reading Brain → Notify when an update is available
```

The normal **Check for Updates** command still performs the actual installation.

## Unified reading history

Reading Brain still keeps its separate cache at:
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

```text
Tools → Reading Brain → Stats & Patterns
├── This Year
├── Monthly Reading
├── Reading Formats
├── Ratings
├── Authors & Genres
├── Reading Habits
├── Interesting Patterns
└── Reading Records
```

<<<<<<< HEAD
### Visual stats

- current-year reading time
- month-by-month reading bars
- Kindle vs Audiobook vs External/Hybrid
- rating distribution
- reading by weekday and time of day
- repeat authors and recurring tags

### Interesting patterns

Reading Brain only reports a pattern when there is enough supporting data. Current tests include:

- biggest reading weekday
- reliable recurring tag
- most unpredictable recurring tag
- fastest high-rated “obsession”
- biggest comeback after a long break
=======
It does not modify KOReader's statistics database or the Bookmory backup.
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

### Reading records

<<<<<<< HEAD
- longest unified reading session
- most intense reading day
- book with the most total logged reading time

The existing discovery engine, unified history, Bookmory analysis, updater, and update notification remain intact.
=======
```text
Tools
└── Reading Brain
    ├── Discover Books
    ├── Taste Profile
    ├── Sync Unified History
    ├── Unified Summary
    ├── Recent Sessions
    ├── Analyze Bookmory Backup
    ├── Notify when an update is available
    ├── Check for Updates
    ├── Restore Previous Version
    └── About
```
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
