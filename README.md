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

### Reading Brain v0.2.0

Upload these files to `readingbrain.koplugin/`:

- `_meta.lua`
- `main.lua`
- `bookmory.lua`
- `library.lua`
- `stats.lua`
- `brain.lua`
- `updater.lua`
- `README.md`

Upload `install-readingbrain.sh` to the repository root.

In the root `manifest.json`, update the existing `readingbrain` entry to the contents of `manifest-readingbrain-entry.json`.

Do not overwrite the other plugin entries.

After these files are on GitHub, Reading Brain v0.1.1 can install v0.2.0 through:

```text
Tools → Reading Brain → Check for Updates
```



More plugins can be added alongside it as separate `.koplugin` directories.

