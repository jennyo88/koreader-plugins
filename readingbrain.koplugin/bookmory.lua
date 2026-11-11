local Archiver = require("ffi/archiver")
local SQ3 = require("lua-ljsqlite3/init")
local JSON = require("rapidjson")
local lfs = require("libs/libkoreader-lfs")

local Bookmory = {}

Bookmory.data_dir = "/mnt/us/readingbrain"
Bookmory.tmp_db = "/tmp/readingbrain-bookmory.db"

local function is_file(path)
    local a = lfs.attributes(path)
    return a and a.mode == "file"
end

local function basename(path)
    return tostring(path or ""):match("([^/]+)$") or tostring(path or "")
end

function Bookmory:getBackupTimestamp(path)
    local name = basename(path)

    local y, m, d, hh, mm, ss =
        name:match(
            "bookmory_(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)"
        )

    if not y then
        y, m, d =
            name:match(
                "bookmory_(%d%d%d%d)(%d%d)(%d%d)"
            )
        hh, mm, ss = "12", "00", "00"
    end

    if y then
        return os.time{
            year = tonumber(y),
            month = tonumber(m),
            day = tonumber(d),
            hour = tonumber(hh) or 12,
            min = tonumber(mm) or 0,
            sec = tonumber(ss) or 0,
            isdst = false,
        }
    end

    local a = lfs.attributes(path)
    return a and tonumber(a.modification) or nil
end

function Bookmory:formatBackupDate(path, timestamp)
    timestamp = timestamp or self:getBackupTimestamp(path)

    if timestamp and timestamp > 0 then
        return os.date("%b %d, %Y", timestamp)
    end

    return basename(path)
end

function Bookmory:findLatestBackup()
    local a = lfs.attributes(self.data_dir)

    if not a or a.mode ~= "directory" then
        return nil, nil
    end

    local best_path
    local best_time = -1

    local ok = pcall(function()
        for name in lfs.dir(self.data_dir) do
            if name ~= "."
                and name ~= ".."
                and name:lower():match("%.bookmory$") then

                local path = self.data_dir .. "/" .. name

                if is_file(path) then
                    local t = self:getBackupTimestamp(path) or 0

                    if t > best_time then
                        best_path = path
                        best_time = t
                    end
                end
            end
        end
    end)

    if not ok then
        return nil, nil
    end

    return best_path, best_time >= 0 and best_time or nil
end

function Bookmory:extractDatabase(backup_path)
    if not backup_path or not is_file(backup_path) then
        return nil, "Bookmory backup was not found."
    end

    os.remove(self.tmp_db)

    local arc = Archiver.Reader:new()

    if not arc:open(backup_path) then
        return nil, "Could not open the Bookmory backup archive."
    end

    local selected

    for entry in arc:iterate() do
        local name = tostring(entry.path or ""):match("([^/]+)$")

        if name == "new_bookmory.db" then
            selected = entry.path
            break
        elseif name == "bookmory.db" and not selected then
            selected = entry.path
        end
    end

    if not selected then
        arc:close()
        return nil, "No Bookmory database was found inside the backup."
    end

    local ok = arc:extractToPath(selected, self.tmp_db)
    arc:close()

    if not ok or not is_file(self.tmp_db) then
        os.remove(self.tmp_db)
        return nil, "Could not extract the Bookmory database."
    end

    return self.tmp_db
end

local function decode(value)
    if not value or value == "" then
        return nil
    end

    local ok, result = pcall(JSON.decode, value)

    if ok and type(result) == "table" then
        return result
    end

    return nil
end

function Bookmory:readBooks(db_path)
    local books = {}

    local ok, err = pcall(function()
        local db = SQ3.open(db_path)

        local stmt = db:prepare([[
            SELECT value
            FROM entry
            WHERE store = 'books'
              AND (deleted IS NULL OR deleted = 0)
            ORDER BY id;
        ]])

        local rows, nrows = stmt:reset():resultset("i")

        if rows and nrows and nrows > 0 then
            for i = 1, nrows do
                local book = decode(rows[1][i])

                if book then
                    table.insert(books, book)
                end
            end
        end

        stmt:close()
        db:close()
    end)

    if not ok then
        return nil, tostring(err)
    end

    return books
end

function Bookmory:summarize(books)
    local result = {
        books = #(books or {}),
        reads = 0,
        sessions = 0,
        seconds = 0,
        audiobook_titles = 0,
        audiobook_sessions = 0,
        external_sessions = 0,
        finished_reads = 0,
        active_reads = 0,
    }

    local audio_title_seen = {}

    for _, book in ipairs(books or {}) do
        local reads = book.reads or {}
        local book_is_audio_only = book.book_type == "audioBook"

        for _, read in ipairs(reads) do
            result.reads = result.reads + 1

            if read.status == "DONE" then
                result.finished_reads = result.finished_reads + 1
            elseif read.status == "READING" then
                result.active_reads = result.active_reads + 1
            end

            local is_audio =
                read.book_type == "audioBook"
                or book.book_type == "audioBook"

            if is_audio then
                book_is_audio_only = true
            end

            for _, timer in ipairs(read.read_timer_list or {}) do
                local elapsed = tonumber(timer.elapsed_sec) or 0

                if elapsed > 0 then
                    result.sessions = result.sessions + 1
                    result.seconds = result.seconds + elapsed

                    if is_audio then
                        result.audiobook_sessions =
                            result.audiobook_sessions + 1
                    else
                        result.external_sessions =
                            result.external_sessions + 1
                    end
                end
            end
        end

        if book_is_audio_only then
            local key =
                tostring(book.title or "")
                .. " :: "
                .. tostring(book.isbn or "")

            if not audio_title_seen[key] then
                audio_title_seen[key] = true
                result.audiobook_titles =
                    result.audiobook_titles + 1
            end
        end
    end

    return result
end

function Bookmory:getSessions(book)
    local sessions = {}

    for _, read in ipairs(book.reads or {}) do
        local is_audio =
            read.book_type == "audioBook"
            or book.book_type == "audioBook"

        local medium =
            is_audio
            and "Audiobook"
            or "External/Hybrid"

        for _, timer in ipairs(read.read_timer_list or {}) do
            local started_ms =
                tonumber(timer.read_started_at)
                or tonumber(timer.created_at)
                or 0

            local started_sec = math.floor(started_ms / 1000)
            local duration = tonumber(timer.elapsed_sec) or 0

            if started_sec > 0 and duration > 0 then
                table.insert(sessions, {
                    source = "Bookmory",
                    medium = medium,
                    start_time = started_sec,
                    duration = duration,
                })
            end
        end
    end

    return sessions
end

function Bookmory:cleanup(db_path)
    if db_path and db_path:match("^/tmp/") then
        os.remove(db_path)
    end
end

return Bookmory
