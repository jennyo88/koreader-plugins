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

local function session_id(source, book_key, start_time, duration)
    return table.concat({
        tostring(source or ""),
        tostring(book_key or ""),
        tostring(start_time or 0),
        tostring(duration or 0),
    }, " :: ")
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
    local stmt = db:prepare([[
        INSERT OR REPLACE INTO books
            (book_key, title, authors, kindle_file, bookmory_format, matched, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    ]])

    stmt:reset():bind(
        book.book_key,
        book.title,
        book.authors,
        book.kindle_file,
        book.bookmory_format,
        book.matched and 1 or 0,
        os.time()
    ):step()

    stmt:close()
end

function Brain:insertSession(db, session)
    if (tonumber(session.duration) or 0) <= 0
        or (tonumber(session.start_time) or 0) <= 0 then

        return false
    end

    local sid = session_id(
        session.source,
        session.book_key,
        session.start_time,
        session.duration
    )

    local stmt = db:prepare([[
        INSERT OR IGNORE INTO sessions
            (session_id, book_key, source, medium, start_time, duration, imported_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    ]])

    stmt:reset():bind(
        sid,
        session.book_key,
        session.source,
        session.medium,
        tonumber(session.start_time) or 0,
        tonumber(session.duration) or 0,
        os.time()
    ):step()

    stmt:close()
    return true
end

function Brain:setMeta(db, key, value)
    local stmt = db:prepare([[
        INSERT OR REPLACE INTO meta(key, value)
        VALUES(?, ?);
    ]])

    stmt:reset():bind(
        tostring(key),
        tostring(value)
    ):step()

    stmt:close()
end

local function scalar(db, sql)
    local stmt = db:prepare(sql)
    local rows, nrows = stmt:reset():resultset("i")
    local value = 0

    if rows and nrows and nrows > 0 then
        value = tonumber(rows[1][1]) or 0
    end

    stmt:close()
    return value
end

local function merged_duration(db, where_sql)
    local sql =
        "SELECT start_time, duration FROM sessions "
        .. "WHERE duration > 0 AND start_time > 0"
        .. (where_sql or "")
        .. " ORDER BY start_time;"

    local stmt = db:prepare(sql)
    local rows, nrows = stmt:reset():resultset("i")
    local total = 0
    local current_start
    local current_end

    if rows and nrows and nrows > 0 then
        for i = 1, nrows do
            local start_time = tonumber(rows[1][i]) or 0
            local duration = tonumber(rows[2][i]) or 0
            local finish = start_time + duration

            if start_time > 0 and duration > 0 then
                if not current_start then
                    current_start = start_time
                    current_end = finish
                elseif start_time <= current_end then
                    if finish > current_end then
                        current_end = finish
                    end
                else
                    total = total + (current_end - current_start)
                    current_start = start_time
                    current_end = finish
                end
            end
        end
    end

    if current_start then
        total = total + (current_end - current_start)
    end

    stmt:close()
    return total
end

function Brain:getMeta(key)
    local a = lfs.attributes(self.db_path)

    if not a or a.mode ~= "file" then
        return nil
    end

    local db = SQ3.open(self.db_path)
    db:exec("PRAGMA query_only = ON;")

    local stmt = db:prepare([[
        SELECT value
        FROM meta
        WHERE key = ?
        LIMIT 1;
    ]])

    stmt:reset():bind(tostring(key))
    local rows, nrows = stmt:resultset("i")
    local value

    if rows and nrows and nrows > 0 then
        value = rows[1][1]
    end

    stmt:close()
    db:close()

    return value
end

function Brain:getSyncInfo()
    return {
        backup = self:getMeta("bookmory_backup"),
        backup_time = tonumber(self:getMeta("bookmory_backup_time")) or 0,
        last_sync = tonumber(self:getMeta("last_sync")) or 0,
    }
end

function Brain:getSummary()
    local a = lfs.attributes(self.db_path)

    if not a or a.mode ~= "file" then
        return nil
    end

    local db = SQ3.open(self.db_path)
    db:exec("PRAGMA query_only = ON;")

    local result = {
        books = scalar(db, "SELECT count(*) FROM books;"),
        matched = scalar(db, "SELECT count(*) FROM books WHERE matched = 1;"),
        sessions = scalar(db, "SELECT count(*) FROM sessions WHERE duration > 0;"),
        seconds = scalar(db, "SELECT coalesce(sum(duration), 0) FROM sessions WHERE duration > 0;"),
        kindle_seconds = scalar(db, "SELECT coalesce(sum(duration), 0) FROM sessions WHERE duration > 0 AND medium = 'Kindle';"),
        audio_seconds = scalar(db, "SELECT coalesce(sum(duration), 0) FROM sessions WHERE duration > 0 AND medium = 'Audiobook';"),
        hybrid_seconds = scalar(db, "SELECT coalesce(sum(duration), 0) FROM sessions WHERE duration > 0 AND medium = 'External/Hybrid';"),
        elapsed_seconds = merged_duration(db),
    }

    result.overlap_seconds =
        math.max(
            0,
            result.seconds - result.elapsed_seconds
        )

    db:close()
    return result
end

return Brain
