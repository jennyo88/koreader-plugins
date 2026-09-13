# TBR Recommender

A personal KOReader plugin that recommends books already on your Kindle.

## Version

`0.2.1`

## Library

Scans recursively:

```text
/mnt/us/koreader/books
```

## Recommendation modes

- **Surprise Me** — random unfinished books.
- **Quick Read** — favors shorter known page counts.
- **Continue a Series** — only the earliest unfinished owned volume in each series.
- **Continue Something Started** — books with real reading progress, favoring books closest to completion.
- **Something Different** — unopened books that avoid authors and series represented among books currently in progress, when metadata is available.
- **Short & Easy** — unopened books from the shorter half of known page counts.
- **Unopened Books** — books KOReader has not recorded as opened.

## Recommendation card

v0.2.0 replaces the plain result box with a custom e-ink-friendly card.

Each recommendation is tappable and shows available metadata such as author, page count, series, and the reason it was selected.

The card includes:

- **Pick Again**
- **Close**

## Series safety

Continue a Series never recommends a later owned volume while an earlier owned volume is still unfinished.

## Updates

Use:

**Tools → TBR Recommender → Check for Updates**

Updates are staged, the previous version is backed up, and KOReader offers **Restart now / Restart later** after installation.
