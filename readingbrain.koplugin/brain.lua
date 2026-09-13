local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local Brain = {}

Brain.data_dir = "/mnt/us/readingbrain"
Brain.db_path = Brain.data_dir .. "/readingbrain.sqlite3"

local function ensure_dir()
    local a = lfs.attributes(Brain.data_dir)

    if not a then
        lfs.mkdir(Brain.data_dir)
    end
end

local function sqlquote(value)
    if value == nil then
        return "NULL"
    end

    value = tostring(value):gsub("'", "''")
    return "'" .. value .. "'"
end

local function session_id(source, book_key, start_time, duration)
    return table.concat({
        tostring(source or ""),
        tostring(book_key or ""),
        tostring(start_time or 0),
        tostring(duration or 0),
    }, "|")
end

function Brain:open()
    ensure_dir()

    local db = SQ3.open(self.db_path)

    db:exec([[
        CREATE TABLE IF NOT EXISTS books (
            book_key TEXT PRIMARY KEY,
            title TEXT,
            authors TEXT,
            kindle_file TEXT,
            bookmory_format TEXT,
            matched INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS sessions (
            session_id TEXT PRIMARY KEY,
            book_key TEXT NOT NULL,
            source TEXT NOT NULL,
            medium TEXT NOT NULL,
            start_time INTEGER NOT NULL DEFAULT 0,
            duration INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS sessions_book_key
            ON sessions(book_key);

        CREATE INDEX IF NOT EXISTS sessions_start_time
            ON sessions(start_time);

        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT
        );
    ]])

    return db
end

function Brain:clearImportedData(db)
    db:exec("DELETE FROM sessions;")
    db:exec("DELETE FROM books;")
end

function Brain:upsertBook(db, book)
    local sql = string.format([[
        INSERT OR REPLACE INTO books
            (book_key, title, authors, kindle_file, bookmory_format, matched, updated_at)
        VALUES
            (%s, %s, %s, %s, %s, %d, %d);
    ]],
        sqlquote(book.book_key),
        sqlquote(book.title),
        sqlquote(book.authors),
        sqlquote(book.kindle_file),
        sqlquote(book.bookmory_format),
        book.matched and 1 or 0,
        os.time()
    )

    db:exec(sql)
end

function Brain:insertSession(db, session)
    local sid = session_id(
        session.source,
        session.book_key,
        session.start_time,
        session.duration
    )

    local sql = string.format([[
        INSERT OR IGNORE INTO sessions
            (session_id, book_key, source, medium, start_time, duration, imported_at)
        VALUES
            (%s, %s, %s, %s, %d, %d, %d);
    ]],
        sqlquote(sid),
        sqlquote(session.book_key),
        sqlquote(session.source),
        sqlquote(session.medium),
        tonumber(session.start_time) or 0,
        tonumber(session.duration) or 0,
        os.time()
    )

    db:exec(sql)
end

function Brain:setMeta(db, key, value)
    local sql = string.format([[
        INSERT OR REPLACE INTO meta(key, value)
        VALUES(%s, %s);
    ]],
        sqlquote(key),
        sqlquote(value)
    )

    db:exec(sql)
end

function Brain:getSummary()
    local a = lfs.attributes(self.db_path)

    if not a then
        return nil
    end

    local db = SQ3.open(self.db_path)

    local books = tonumber(db:rowexec("SELECT count(*) FROM books;")) or 0
    local matched = tonumber(db:rowexec("SELECT count(*) FROM books WHERE matched = 1;")) or 0
    local sessions = tonumber(db:rowexec("SELECT count(*) FROM sessions;")) or 0
    local seconds = tonumber(db:rowexec("SELECT coalesce(sum(duration), 0) FROM sessions;")) or 0
    local kindle_seconds = tonumber(db:rowexec(
        "SELECT coalesce(sum(duration), 0) FROM sessions WHERE medium = 'Kindle';"
    )) or 0
    local audio_seconds = tonumber(db:rowexec(
        "SELECT coalesce(sum(duration), 0) FROM sessions WHERE medium = 'Audiobook';"
    )) or 0
    local hybrid_seconds = tonumber(db:rowexec(
        "SELECT coalesce(sum(duration), 0) FROM sessions WHERE medium = 'External/Hybrid';"
    )) or 0

    db:close()

    return {
        books = books,
        matched = matched,
        sessions = sessions,
        seconds = seconds,
        kindle_seconds = kindle_seconds,
        audio_seconds = audio_seconds,
        hybrid_seconds = hybrid_seconds,
    }
end

function Brain:getRecentSessions(limit)
    local result = {}
    local a = lfs.attributes(self.db_path)

    if not a then
        return result
    end

    local db = SQ3.open(self.db_path)
    local stmt = db:prepare([[
        SELECT
            b.title,
            s.medium,
            s.start_time,
            s.duration
        FROM sessions s
        LEFT JOIN books b
          ON b.book_key = s.book_key
        ORDER BY s.start_time DESC
        LIMIT ?;
    ]])

    stmt:reset():bind(tonumber(limit) or 20)
    local rows, nrows = stmt:resultset("i")

    if rows and nrows and nrows > 0 then
        for i = 1, nrows do
            table.insert(result, {
                title = rows[1][i] or "Unknown title",
                medium = rows[2][i] or "Unknown",
                start_time = tonumber(rows[3][i]) or 0,
                duration = tonumber(rows[4][i]) or 0,
            })
        end
    end

    stmt:close()
    db:close()

    return result
end

return Brain
