# My KOReader Plugins

Personal KOReader plugins designed for my Kindle.

## Plugins

### Reading Dashboard

Current version: `0.5.3`

Location:

```text
readingdashboard.koplugin/
```

Install/update:

```sh
/mnt/us/install-readingdashboard.sh YOUR_GITHUB_USERNAME/koreader-plugins
```

### TBR Recommender

Current version: `0.2.1`

Location:

```text
tbrrecommender.koplugin/
```

Install/update:

```sh
/mnt/us/install-tbrrecommender.sh YOUR_GITHUB_USERNAME/koreader-plugins
```

### Reading Brain v0.4.0

Upload these files to `readingbrain.koplugin/`:

- `_meta.lua`
- `main.lua`
- `bookmory.lua`
- `library.lua`
- `stats.lua`
- `brain.lua`
- `discovery.lua`
- `update_notifier.lua`
- `updater.lua`
- `README.md`

Upload `install-readingbrain.sh` to the repository root.

Update the existing `readingbrain` entry in the root `manifest.json` to the contents of `manifest-readingbrain-entry.json`.

Important: both `discovery.lua` and `update_notifier.lua` must exist on GitHub before changing the manifest to 0.4.0, otherwise the updater will receive an HTTP 404.

Once everything is uploaded:

```text
Tools → Reading Brain → Check for Updates
```

More plugins can be added alongside it as separate `.koplugin` directories.

