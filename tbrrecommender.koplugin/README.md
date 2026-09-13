# TBR Recommender

A personal KOReader plugin that recommends books already on your Kindle.

## Version

`0.1.3`

## Library location

The plugin scans:

```text
/mnt/us/koreader/books
```

## Modes

- **Surprise Me**
- **Quick Read**
- **Continue a Series**
- **Unopened Books**

## Updater

The plugin can now update itself from:

```text
Tools → TBR Recommender → Check for Updates
```

It also keeps a backup of the previous version and supports:

```text
Restore Previous Version
```

After an update or restore, it offers:

```text
Restart later
Restart now
```

## Current limitations

- EPUB only.
- Finished books are excluded when KOReader marks them `complete`.
- Unopened books may have less metadata until KOReader has cached information.
- Recommendations are not yet tappable.


## Tappable recommendations

Recommendations are now shown as buttons.

- Tap a book to open it directly in KOReader.
- **Pick Again** generates another set of three using the same mode.
- **Close** dismisses the recommendation window.


## Smarter Continue a Series

`Continue a Series` now looks at completed and unfinished volumes together.

For each series it:

1. Sorts owned books by series number.
2. Skips volumes KOReader marks `complete`.
3. Recommends only the earliest volume that is not complete.
4. Never recommends a later owned volume while an earlier owned volume is still unfinished.

Example:

```text
Book 1 — complete
Book 2 — complete
Book 3 — unread
Book 4 — unread
```

Only **Book 3** is eligible.

Series recommendations are labeled **Next unread volume**.
