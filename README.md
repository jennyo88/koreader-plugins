# KOReader Plugins

Personal KOReader plugins maintained for my Kindle reading workflow.

This repository currently contains three active plugins:

| Plugin | Version | Purpose |
| --- | --- | --- |
| **Reading Brain** | **0.8.3** | Unified reading history, discovery, reading statistics, taste analysis, and reading-pattern insights. |
| **Reading Dashboard** | **0.5.3** | A compact in-book dashboard for current reading progress and session information. |
| **TBR Recommender** | **0.2.1** | Recommends unread books already available in the local KOReader library. |

## Repository structure

```text
koreader-plugins/
├── readingbrain.koplugin/
├── readingdashboard.koplugin/
├── tbrrecommender.koplugin/
├── scripts/
│   ├── install-plugin.sh
│   └── validate-readingbrain-release.sh
├── .gitignore
├── LICENSE
├── README.md
└── manifest.json
```

## Installation

The unified installer downloads the current `main` branch, validates the requested plugin, backs up an existing installation, and installs the complete `.koplugin` directory.

On the Kindle, place `scripts/install-plugin.sh` somewhere accessible and run:

```sh
sh install-plugin.sh readingbrain
sh install-plugin.sh readingdashboard
sh install-plugin.sh tbrrecommender
```

Install all three:

```sh
sh install-plugin.sh all
```

Show supported plugin names:

```sh
sh install-plugin.sh --list
```

Plugins are installed to:

```text
/mnt/us/koreader/plugins/
```

Restart KOReader after installation.

### Manual installation

Alternatively, copy the complete plugin directory into:

```text
/mnt/us/koreader/plugins/
```

For example:

```text
/mnt/us/koreader/plugins/readingbrain.koplugin/
```

The plugin folder must contain `_meta.lua` and `main.lua` directly inside it.

## Updates

Each plugin uses the repository-level `manifest.json` to determine the latest version and which files belong to an update.

Updates are intentionally user-triggered. Reading Brain does not perform background or wake-time update checks.

When publishing an update:

1. Update the plugin version in its source files.
2. Upload all changed plugin files.
3. Update `manifest.json` only after the new files are available on `main`.
4. For Reading Brain releases, run:

```sh
sh scripts/validate-readingbrain-release.sh
```

5. Test the update from KOReader before treating the release as complete.

This order prevents devices from seeing a new manifest version before its files are available.

## Reading Brain

**Current version: 0.8.3**

Reading Brain combines Bookmory history with KOReader statistics into a separate read-only analysis layer.

Current areas include:

- **Discover Books** — taste-based recommendations with Save, Not for Me, and Already Own feedback.
- **Taste Profile** — summarizes rating and preference signals from reading history.
- **Reading Overview** — current-year reading activity, recent momentum, medium mix, taste snapshot, and all-time totals.
- **Stats & Patterns** — monthly reading, ratings and taste, habits, patterns, and records.
- **Data & Sync** — imports Bookmory and KOReader history into Reading Brain's own cache.
- **Data Status** — backup health, Kindle matching, and unified-history status.
- **Gesture support** — `Open Reading Brain` can be assigned through KOReader's Gesture Manager and opens Reading Overview.
- **Manual updates** — update checks run only when explicitly selected.

Reading Brain source data is treated as read-only. Its own cache, feedback, and settings are stored separately.

### Bookmory data

Place the current `.bookmory` backup in:

```text
/mnt/us/readingbrain/
```

Keeping one current backup there is recommended.

## Reading Dashboard

**Current version: 0.5.3**

Reading Dashboard provides an e-ink-friendly dashboard for the currently open book, including reading progress and session-related information.

It also supports its own manual update flow through the shared repository manifest.

## TBR Recommender

**Current version: 0.2.1**

TBR Recommender chooses from books already present in the local KOReader library.

Recommendation modes include:

- Surprise Me
- Quick Read
- Continue a Series
- Continue Something Started
- Something Different
- Short & Easy
- Unopened Books

Series recommendations favor the earliest unfinished owned volume.

## Manifest

`manifest.json` is shared by the plugin updaters.

Its required structure is:

```json
{
  "plugins": {
    "plugin-id": {
      "name": "Plugin Name",
      "version": "0.0.0",
      "description": "Description",
      "files": [
        "_meta.lua",
        "main.lua"
      ]
    }
  }
}
```

Do not remove the top-level `plugins` object. The updater code expects it.

## Development notes

- Keep plugin directories named exactly `*.koplugin`.
- Keep `_meta.lua` and `main.lua` at the plugin root.
- Do not commit Bookmory backups, SQLite databases, temporary files, or local backups.
- Prefer complete plugin-directory installs for fresh installation.
- Keep manifest file lists synchronized with updater-managed files.
- Reading Brain release validation belongs in `scripts/validate-readingbrain-release.sh`.

## License

See [LICENSE](LICENSE).
