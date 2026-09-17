# Reading Brain v0.5.3

Stats UI cleanup.

The Stats & Patterns screens now use a custom card-style dialog modeled after the TBR Recommender instead of KOReader's large InfoMessage text.

Changes:
- smaller 15pt stat text
- centered 21pt title
- framed white card
- thin divider
- cleaner margins and spacing
- dedicated Close button
- e-ink-friendly black-and-white presentation

No stats calculations changed in this release.


## v0.5.4

Reading Brain keeps the v0.5.3 visual formatting unchanged.

Update notifications now match the Bookshelf behavior more closely:

- menu item: **Notify on wake when update available**
- setting is clickable and persists correctly
- opt-in; off by default
- checks only after Kindle/KOReader wake
- only checks while Wi-Fi is already connected
- at most one successful check per hour
- posts a quiet top-edge notification only when a newer version exists
- never turns Wi-Fi on
- never installs an update automatically
