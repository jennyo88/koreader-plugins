# KOReader Reading Dashboard

A small personal KOReader plugin that provides a compact dashboard for the current book.

## Version

`0.1.0`

This first version intentionally stays simple so it is easy to test on a real Kindle before adding deeper statistics.

## What v0.1.0 does

- Adds **Reading Dashboard** to KOReader's main menu while a document is open.
- Shows the current book title when KOReader exposes it.
- Shows percentage progress.
- Shows current page and page count when available.
- Uses fallbacks so the plugin should fail gracefully if a particular KOReader document type does not expose one of those values.

## Repository structure

```text
koreader-plugins/
├── README.md
├── install-readingdashboard.sh
└── readingdashboard.koplugin/
    ├── _meta.lua
    └── main.lua
```

## Install on Kindle with curl

Clone or upload this repository to GitHub first.

Then, from your Kindle terminal:

```sh
cd /mnt/us
curl -fL \
  https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/koreader-plugins/main/install-readingdashboard.sh \
  -o install-readingdashboard.sh

chmod +x install-readingdashboard.sh

./install-readingdashboard.sh YOUR_GITHUB_USERNAME/koreader-plugins
```

Restart KOReader after installation.

## Update

Run the same installer again:

```sh
/mnt/us/install-readingdashboard.sh YOUR_GITHUB_USERNAME/koreader-plugins
```

It replaces only the plugin code files.

## Manual installation

Copy:

```text
readingdashboard.koplugin/
```

to:

```text
/mnt/us/koreader/plugins/
```

so the final path is:

```text
/mnt/us/koreader/plugins/readingdashboard.koplugin/main.lua
```

Then restart KOReader.

## Troubleshooting

If the plugin does not appear:

1. Confirm the folder name is exactly `readingdashboard.koplugin`.
2. Confirm `main.lua` is directly inside that folder, not inside an extra nested directory.
3. Restart KOReader completely.
4. Check **Tools → Plugin management** and confirm Reading Dashboard is enabled.
5. If KOReader stops loading the plugin, inspect KOReader's crash/log output for the first Lua error.

## Planned next versions

### v0.2
- Time spent reading this book
- Estimated time remaining
- Reading speed
- Pages remaining

### v0.3
- Today's reading time
- Pages read today
- Finish-date estimate

### v0.4
- Configurable dashboard fields
- Optional gesture shortcut
- Cleaner dedicated dashboard UI

## Notes

The metadata intentionally keeps:

```lua
name = "readingdashboard"
```

even though newer KOReader versions are reducing reliance on metadata `name`, because it helps compatibility with older stable releases.
