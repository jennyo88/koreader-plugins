local Archiver = require("ffi/archiver")
local SQ3 = require("lua-ljsqlite3/init")
local json = require("json")
local lfs = require("libs/libkoreader-lfs")

local Bookmory = {}

local DATA_DIR = "/mnt/us/readingbrain"
local TMP_DB = "/tmp/readingbrain-bookmory.db"

local function fileTime(name)
    local y, m, d, hh, mm, ss =
        tostring(name):match(
            "bookmory_(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)"
        )

    if not y then
        y, m, d =
            tostring(name):match(
                "bookmory_(%d%d%d%d)(%d%d)(%d%d)"
            )
        hh, mm, ss = "12", "00", "00"
    end

    if not y then
        return 0
    end

    return os.time{
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(hh) or 12,
        min = tonumber(mm) or 0,
        sec = tonumber(ss) or 0,
    } or 0
end

function Bookmory:findLatestBackup()
    local latest
    local latest_time = 0

    local ok, iter, obj = pcall(lfs.dir, DATA_DIR)
    if not ok or not iter then
        return nil
    end

    for name in iter, obj do
        if name ~= "." and name ~= ".." and name:match("%.bookmory$") then
            local path = DATA_DIR .. "/" .. name
            local t = fileTime(name)

            if t == 0 then
                local attr = lfs.attributes(path)
                t = attr and tonumber(attr.modification) or 0
            end

            if t > latest_time then
                latest = path
                latest_time = t
            end
        end
    end

    return latest
end

function Bookmory:extractDatabase(backup)
    os.remove(TMP_DB)

    local arc = Archiver.Reader:new()
    if not arc:open(backup) then
        return nil, tostring(arc.err or "Could not open backup.")
    end

    local selected

    for entry in arc:iterate() do
        local name = tostring(entry.path):match("([^/]+)$")

        if name == "new_bookmory.db" then
            selected = entry.path
            break
        elseif name == "bookmory.db" and not selected then
            selected = entry.path
        end
    end

    if not selected then
        arc:close()
        return nil, "No Bookmory SQLite database was found in the backup."
    end

    local ok = arc:extractToPath(selected, TMP_DB)
    local err = arc.err
    arc:close()

    if not ok then
        return nil, tostring(err or "Could not extract Bookmory database.")
    end

    return TMP_DB
end

function Bookmory:readBooks(db_path)
    local db = SQ3.open(db_path, "ro")
    local stmt =
        db:prepare(
            "SELECT value FROM entry WHERE store = 'books';"
        )

    local books = {}

    while true do
        local row = stmt:step()
        if not row then
            break
        end

        local ok, book =
            pcall(
                json.decode,
                row[1]
            )

        if ok and type(book) == "table" then
            table.insert(books, book)
        end
    end

    stmt:close()
    db:close()

    return books
end

function Bookmory:cleanup(db_path)
    if db_path and db_path:match("^/tmp/") then
        os.remove(db_path)
    end
end

function Bookmory:getSessions(book)
    local out = {}

    for _, read in ipairs(book.reads or {}) do
        for _, timer in ipairs(read.read_timer_list or {}) do
            local seconds =
                tonumber(timer.elapsed_sec) or 0

            local start =
                math.floor(
                    (tonumber(timer.read_started_at) or 0)
                    / 1000
                )

            if seconds > 0 and start > 0 then
                table.insert(out, {
                    source = "Bookmory",
                    medium =
                        tostring(book.book_type) == "audioBook"
                        and "Audiobook"
                        or "External/Hybrid",
                    start_time = start,
                    duration = seconds,
                })
            end
        end
    end

    return out
end

function Bookmory:summarize(books)
    local result = {
        books = 0,
        sessions = 0,
        seconds = 0,
    }

    for _, book in ipairs(books or {}) do
        result.books = result.books + 1

        for _, session in ipairs(self:getSessions(book)) do
            result.sessions = result.sessions + 1
            result.seconds =
                result.seconds
                + (tonumber(session.duration) or 0)
        end
    end

    return result
end

return Bookmory
