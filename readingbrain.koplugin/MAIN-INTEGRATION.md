# Reading Brain v0.7.0 integration patch

This feature pack contains three new modules:

- `backup_health.lua`
- `feedback.lua`
- `book_page.lua`

They are intentionally separate so the existing Reading Brain UI and sync code stay stable.

## 1. Load the modules in `main.lua`

Near the other plugin-local modules:

```lua
local BackupHealth =
    dofile(plugin_dir .. "/backup_health.lua")

local Feedback =
    dofile(plugin_dir .. "/feedback.lua")

local BookPage =
    dofile(plugin_dir .. "/book_page.lua")
```

## 2. Mark a Bookmory backup as synced

At the end of a successful `Sync Reading History`, after the cache has been rebuilt:

```lua
BackupHealth:markSynced(backup)
```

Do this only after a successful sync.

## 3. Data Status header

When building Data Status:

```lua
local backup_status =
    BackupHealth:getStatus()
```

Use:

```lua
backup_status.label
```

as the small right-aligned header status:

- CURRENT
- AGING
- STALE
- NEW BACKUP
- MISSING

The body can include:

```lua
BackupHealth:formatBody()
```

## 4. Discovery feedback

After `Discovery:scoreCandidates(...)`:

```lua
scored =
    Feedback:apply(scored)
```

On the selected recommendation detail screen add three actions:

```text
Want to Read
Not for Me
Already Own
```

Callbacks:

```lua
Feedback:set(selected, "want")
Feedback:set(selected, "dismiss")
Feedback:set(selected, "owned")
```

`Not for Me` and `Already Own` disappear from future discovery results.
`Want to Read` receives a large ranking boost.

## 5. Per-book Reading Brain page

For each Recent Sessions row, keep `book_key` and `title`.

On tap:

```lua
local books =
    self:loadBookmoryBooks()

local body =
    BookPage:build(
        session.book_key,
        session.title,
        books or {}
    )

self:showCardDialog(
    session.title or "BOOK",
    body
)
```

This gives:
- total reading time
- session count
- average session
- longest session
- first/last session
- Kindle/audio/hybrid split
- Bookmory progress
- Bookmory rating

The book page should open from Recent Sessions rather than adding another top-level menu item.
