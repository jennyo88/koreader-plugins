# KOReader Reading Dashboard

A compact reading dashboard for KOReader that shows progress and reading statistics for the current book.

## Version

`0.2.0`

## Current features

- Shows the current book title
- Shows reading progress as a percentage
- Shows current page and total page count
- Shows pages remaining
- Shows total time spent reading the book
- Shows average reading time per page
- Shows estimated time remaining for the **entire book**

## Example

```text
The Picture of Dorian Gray

PROGRESS
8%  •  Page 25 of 311
286 pages remaining

READING
Time read          25m 42s
Avg. per page       1m 17s
Time remaining      6h 07m
```

## Time remaining

`Time remaining` is an estimate for finishing the **entire book**.

It is calculated from:

```text
average reading time per page × pages remaining
```

It is not the same as KOReader's chapter time remaining value shown in the footer.

Because the estimate is based on your recorded average reading speed, it should become more representative as more reading statistics are collected.

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
