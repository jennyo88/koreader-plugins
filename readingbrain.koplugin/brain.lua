local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local Brain = {}
local DIR = "/mnt/us/readingbrain"
local DB_PATH = DIR .. "/readingbrain.sqlite3"

local function ensureDir()
    if lfs.attributes(DIR, "mode") ~= "directory" then
        lfs.mkdir(DIR)
    end
end

local function ensureSchema(db)
    db:exec([[
        CREATE TABLE IF NOT EXISTS books (
            book_key TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            authors TEXT,
            kindle_file TEXT,
            bookmory_format TEXT,
            matched INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_key TEXT NOT NULL,
            source TEXT NOT NULL,
            medium TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            duration INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_book
        ON sessions(book_key);

        CREATE INDEX IF NOT EXISTS idx_sessions_start
        ON sessions(start_time);
    ]])
end

function Brain:open()
    ensureDir()
    local db = SQ3.open(DB_PATH)
    ensureSchema(db)
    return db
end

function Brain:clearImportedData(db)
    db:exec("DELETE FROM sessions; DELETE FROM books;")
end

function Brain:upsertBook(db, book)
    local stmt =
        db:prepare([[
            INSERT OR REPLACE INTO books
            (book_key, title, authors, kindle_file, bookmory_format, matched)
            VALUES (?, ?, ?, ?, ?, ?);
        ]])

    stmt:reset():bind(
        tostring(book.book_key or ""),
        tostring(book.title or "Untitled"),
        tostring(book.authors or ""),
        book.kindle_file,
        book.bookmory_format,
        book.matched and 1 or 0
    ):step()

    stmt:close()
end

function Brain:insertSession(db, session)
    local duration = tonumber(session.duration) or 0
    local start_time = tonumber(session.start_time) or 0

    if duration <= 0 or start_time <= 0 then
        return
    end

    local stmt =
        db:prepare([[
            INSERT INTO sessions
            (book_key, source, medium, start_time, duration)
            VALUES (?, ?, ?, ?, ?);
        ]])

    stmt:reset():bind(
        tostring(session.book_key or ""),
        tostring(session.source or "Unknown"),
        tostring(session.medium or "Unknown"),
        start_time,
        duration
    ):step()

    stmt:close()
end

function Brain:setMeta(db, key, value)
    local stmt =
        db:prepare(
            "INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?);"
        )

    stmt:reset():bind(
        tostring(key or ""),
        tostring(value or "")
    ):step()

    stmt:close()
end

function Brain:getSummary()
    if lfs.attributes(DB_PATH, "mode") ~= "file" then
        return nil
    end

    local db = SQ3.open(DB_PATH, "ro")

    local books =
        tonumber(
            db:rowexec(
                "SELECT count(*) FROM books;"
            )
        ) or 0

    local matched =
        tonumber(
            db:rowexec(
                "SELECT count(*) FROM books WHERE matched = 1;"
            )
        ) or 0

    local sessions =
        tonumber(
            db:rowexec(
                "SELECT count(*) FROM sessions WHERE duration > 0;"
            )
        ) or 0

    local seconds =
        tonumber(
            db:rowexec(
                "SELECT coalesce(sum(duration),0) FROM sessions WHERE duration > 0;"
            )
        ) or 0

    local kindle =
        tonumber(
            db:rowexec(
                "SELECT coalesce(sum(duration),0) FROM sessions WHERE duration > 0 AND medium = 'Kindle';"
            )
        ) or 0

    local audio =
        tonumber(
            db:rowexec(
                "SELECT coalesce(sum(duration),0) FROM sessions WHERE duration > 0 AND medium = 'Audiobook';"
            )
        ) or 0

    local hybrid =
        tonumber(
            db:rowexec(
                "SELECT coalesce(sum(duration),0) FROM sessions WHERE duration > 0 AND medium = 'External/Hybrid';"
            )
        ) or 0

    db:close()

    return {
        books = books,
        matched = matched,
        sessions = sessions,
        seconds = seconds,
        kindle_seconds = kindle,
        audio_seconds = audio,
        hybrid_seconds = hybrid,
    }
end

function Brain:getRecentSessions(limit)
    if lfs.attributes(DB_PATH, "mode") ~= "file" then
        return {}
    end

    local db = SQ3.open(DB_PATH, "ro")
    local stmt =
        db:prepare([[
            SELECT
                s.book_key,
                coalesce(b.title, 'Untitled'),
                s.medium,
                s.start_time,
                s.duration
            FROM sessions s
            LEFT JOIN books b
              ON b.book_key = s.book_key
            WHERE s.duration > 0
            ORDER BY s.start_time DESC
            LIMIT ?;
        ]])

    stmt:bind(tonumber(limit) or 18)

    local out = {}

    while true do
        local row = stmt:step()
        if not row then
            break
        end

        table.insert(out, {
            book_key = row[1],
            title = row[2],
            medium = row[3],
            start_time = tonumber(row[4]) or 0,
            duration = tonumber(row[5]) or 0,
        })
    end

    stmt:close()
    db:close()

    return out
end

return Brain
