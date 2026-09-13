# Reading Brain prototype

Upload the `readingbrain.koplugin` folder and `install-readingbrain.sh` to the root of your existing `koreader-plugins` repository.

Install on Kindle:

```sh
cd /mnt/us
curl -fL \
https://raw.githubusercontent.com/jennyo88/koreader-plugins/main/install-readingbrain.sh \
-o install-readingbrain.sh

chmod +x install-readingbrain.sh
./install-readingbrain.sh
```

Then place a Bookmory backup in:

```text
/mnt/us/readingbrain/
```

Restart KOReader and use:

```text
Tools → Reading Brain → Analyze Bookmory Backup
```

This prototype is read-only.
