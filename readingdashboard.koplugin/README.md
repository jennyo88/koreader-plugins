# KOReader Reading Dashboard

A custom KOReader reading dashboard with a clean e-ink-friendly interface.

## Version

`0.3.0`

## Current features

- Reading percentage
- Visual progress bar
- Current page / total pages
- Pages remaining
- Total reading time
- Average time per page
- Estimated time remaining for the entire book
- Custom Kindle-friendly dashboard UI

## Repository structure

```text
koreader-plugins/
├── README.md
├── install-readingdashboard.sh
└── readingdashboard.koplugin/
    ├── _meta.lua
    ├── main.lua
    └── README.md
```

## Install on Kindle

From the Kindle terminal:

```sh
cd /mnt/us

curl -fL \
https://raw.githubusercontent.com/jennyo88/koreader-plugins/main/install-readingdashboard.sh \
-o install-readingdashboard.sh

chmod +x install-readingdashboard.sh

./install-readingdashboard.sh jennyo88/koreader-plugins
```

Restart KOReader after installation.

## Update

Run the installer again:

```sh
/mnt/us/install-readingdashboard.sh jennyo88/koreader-plugins
```

Then restart KOReader.

## Manual installation

Copy:

```text
readingdashboard.koplugin/
```

to:

```text
/mnt/us/koreader/plugins/
```

The final path should be:

```text
/mnt/us/koreader/plugins/readingdashboard.koplugin/main.lua
```

## Troubleshooting

If the plugin does not appear:

1. Confirm the folder is named exactly `readingdashboard.koplugin`.
2. Confirm `main.lua` is directly inside that folder.
3. Restart KOReader completely.
4. Check KOReader's Plugin Management menu and confirm Reading Dashboard is enabled.
5. Check KOReader's log for Lua errors if the plugin fails to load.

## Planned features

Future versions may include:

- Current reading session time
- Pages read during the current session
- Reading today
- Estimated finish date
- Configurable dashboard fields
- Gesture shortcut
- Improved dashboard UI
- Additional reading-speed calculations
