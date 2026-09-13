# TBR Recommender

A personal KOReader plugin that recommends books already on your Kindle.

## Version

`0.1.2`

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
