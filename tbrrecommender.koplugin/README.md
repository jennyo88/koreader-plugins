# TBR Recommender

A personal KOReader plugin that recommends books already on your Kindle.

## Version

`0.3.0`

## Library

Scans EPUBs recursively from:

```text
/mnt/us/koreader/books
```

Completed books are excluded from normal TBR recommendations. `Continue a Series` still reads completed-book metadata so it can safely identify the earliest unfinished owned volume.

The library scan is cached for five minutes, so **Pick Again** can reroll without rescanning the Kindle every time. Use **Settings & Updates → Refresh Library** after adding or removing books if you want an immediate rescan.

## Recommendation modes

- **Surprise Me** — random unfinished books.
- **Quick Read** — favors shorter known page counts.
- **Continue a Series** — only the earliest unfinished owned volume in each series.
- **Continue Something Started** — books with real reading progress, favoring books closest to completion.
- **Something Different** — unopened books that avoid authors and series represented among books currently in progress, when metadata is available.
- **Short & Easy** — unopened books from the shorter half of known page counts.
- **Unopened Books** — books KOReader has not recorded as opened.

## Recommendation card

Recommendations are shown in an e-ink-friendly card.

Each recommendation is tappable and shows available metadata such as author, page count, series, and the reason it was selected.

The card includes:

- **Pick Again**
- **Close**

During a KOReader session, **Pick Again** avoids showing the same books again for that mode until the available candidate pool has been cycled.

## Gesture support

KOReader's Gesture Manager can assign:

```text
TBR Recommender: Surprise Me
```

This runs the `Surprise Me` mode directly from a gesture.

## Series safety

`Continue a Series` never recommends a later owned volume while an earlier owned volume is still unfinished.

## Reliability

`library.lua` and `recommender.lua` are loaded safely. If either module cannot load, TBR Recommender reports the problem instead of taking down the whole plugin.

## Settings & Updates

Use:

```text
Tools → TBR Recommender → Settings & Updates
```

Available actions:

- **Refresh Library**
- **Check for Updates**
- **Restore Previous Version**
- **About**

Update checks are manual. Updates are staged, the previous version is backed up, and KOReader offers **Restart now / Restart later** after installation.
