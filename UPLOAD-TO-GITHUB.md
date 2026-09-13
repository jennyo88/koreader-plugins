# Reading Brain v0.1.1 upload

Upload these files to:

```text
readingbrain.koplugin/
```

- `_meta.lua`
- `main.lua`
- `bookmory.lua`
- `library.lua`
- `updater.lua`
- `README.md`

Upload `install-readingbrain.sh` to the repository root.

Then merge the entry in `manifest-readingbrain-entry.json` into the existing root `manifest.json` under `"plugins"`.

Do not replace the other plugin entries with stale versions.

Once those files are on GitHub, reinstall once so the Kindle receives `updater.lua`, then future updates can be installed from inside Reading Brain.
