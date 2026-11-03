# Threadlight for KOReader — v1.3.1

A small, spoiler-aware personal story memory plugin for EPUBs. Intended for low-resource e-ink readers, including older Kindle Paperwhites. The **phone editor** lets you save notes with your phone keyboard while the notes remain stored locally on the Kindle.

## Install or update

1. Close KOReader.
2. Remove the older `threadlight.koplugin` directory from `koreader/plugins/` (do not delete your EPUB `.sdr` sidecar directories).
3. Copy this extracted `threadlight.koplugin` directory to `koreader/plugins/`.
4. Restart KOReader. Open an EPUB, then visit **Tools → Threadlight**.

## Phone editor

1. Connect the Kindle and your phone to the **same Wi-Fi network**. Do not use a guest network that isolates devices.
2. Open the desired EPUB in KOReader and navigate to the passage you are documenting.
3. Open **Tools → Threadlight → Phone editor · start / show address**.
4. Use your phone camera to **scan the large, centered QR code** that appears on your Kindle. Tap the screen to close the QR overlay after scanning. If QR display isn't supported on your KOReader installation, manually enter the displayed URL in your phone browser.
5. On the page, write a checkpoint (two fields) or start a story thread (name and optional explanation), then tap Save. You'll receive a confirmation message in the browser.
6. Select **Tools → Threadlight → Phone editor · stop** on your Kindle when finished. You can start it again anytime.

The phone editor associates each note with the **position at which you started the editor**, even if you change pages while composing on your phone. You must stop/restart the editor to change that anchor. It only edits the **currently open** EPUB; switch books by stopping the editor, opening the next EPUB, and starting it again.

## Highlights by checkpoint (new in v1.3)

Existing KOReader **text highlights** are read directly from the open EPUB's live annotations; no re-highlighting, copying, importing, or additional typing is needed.

- Open **Tools → Threadlight → Highlights by checkpoint** to choose a checkpoint and read only the highlights assigned to its interval.
- Alternatively, open **Story checkpoints**, choose an entry, then **Highlights for this checkpoint**.
- The same archive appears in an expandable section of the **Phone editor** page, so you can read the highlights comfortably on your phone. Refresh the page after making highlights or checkpoints.
- **Range rule:** A checkpoint includes highlights whose *starting locations* are after the preceding checkpoint and at or before this checkpoint. The first checkpoint starts at the beginning of the book. Checkpoints are ordered by EPUB reading position rather than creation time. If you add a checkpoint between existing ones, the grouping adjusts automatically.
- Only textual highlights that KOReader exposes in `ui.annotation.annotations` are included. Bookmarks, image-only annotations, and highlights made in other apps but not imported into KOReader are not included.
- If an EPUB or checkpoint lacks a valid XPointer, Threadlight reports that rather than guessing from reading percentages. Changing EPUB versions or reformatting can invalidate anchors. No story text is analyzed or sent online.
- The original KOReader highlights remain untouched. Removing Threadlight does not remove the highlights.

### v1.3.1 QR display fix

KOReader v2026.07.x requires an explicit QR widget width and height. Older Threadlight builds omitted these settings, leaving the phone editor QR extremely small or blank. This update sets the QR to approximately 88% of the Kindle screen width (subject to screen height) for reliable scanning. The phone editor and all highlight features are otherwise unchanged.

### Troubleshooting

- **The QR link doesn't open:** Confirm both devices are on the same Wi-Fi and local-device communication is allowed, and keep the Kindle awake. Turn off VPN or client-isolation settings if they block LAN devices. If the Kindle cannot determine a Wi-Fi address, the editor will show an error.
- **Nothing appears after saving:** Reopen Story checkpoints or Story threads inside Threadlight. Your notes attach to the EPUB position when the phone editor was started.
- **The phone page says expired link:** Start Phone editor again; each new session uses a new temporary link.
- **The Kindle goes to sleep:** The editor stops on suspend. Restart it to scan a new link.
- **Plugin doesn't appear in menus:** Open an EPUB, verify Threadlight is enabled in Plugin management, restart KOReader, then look in Tools.

### Security and privacy

The HTTP server is **off by default** and listens only on the Kindle's detected local Wi-Fi address. The phone page is available only while the editor runs. Each start generates a new cryptographically random, unguessable session address. Requests are size-limited, and the server never reads EPUB text, exports library contents, or executes commands. No external servers, accounts, cloud sync, JavaScript, or third-party assets are used. The connection is ordinary **HTTP, not encrypted HTTPS**: use a trusted private Wi-Fi network, not public Wi-Fi. Anyone who can access the QR link on that network while the editor is active can submit notes. Turn off the editor after using it.

### Existing features retained

- **Previously...** shows up to three latest visible checkpoints and up to ten open story threads.
- **Checkpoints** store what happened and what to remember next time, with a link to the EPUB position.
- **Highlights by checkpoint** shows saved text highlights for the interval ending at each checkpoint (viewable on Kindle and phone).
- **Story threads** record evolving questions, theories, and relationships; add updates and resolve/reopen them.
- **Spoiler curtain** hides notes made ahead of the current position (native EPUB XPointers first, percentage fallback).
- **Return reminder** can offer notes after seven days away.
- **Gestures:** Recall story, Save checkpoint, View threads.
- **Storage:** Notes remain in each EPUB's KOReader `.sdr` sidecar settings (`threadlight_v1`), unchanged from v1.1. Back up `.sdr` when migrating books.

## Runtime compatibility

The plugin is Lua and relies on KOReader's shipped LuaSocket, QRMessage widget when available, UIManager scheduled tasks, and the existing per-book sidecar settings APIs. Phone editor requires Wi-Fi, but all original features work offline. No additional software is needed on the Kindle or phone.

## Tests

Source tests (`tests/`) are included in the development directory but not required to install. Run with TeX Lua if available:

```sh
luatex --luaonly tests/mock_smoke.lua
luatex --luaonly tests/phone_smoke.lua
luatex --luaonly tests/http_smoke.lua
luatex --luaonly tests/highlights_smoke.lua
```

These exercise menu registration, position filtering, note persistence, HTML encoding, the local HTTP server and POST decoding on a desktop mock. **This version has not yet been tested on a physical Kindle.**
