local DataStorage = require("datastorage")
local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local Stats = {}

Stats.db_path =
    DataStorage:getSettingsDir()
    .. "/statistics.sqlite3"

-- Page-level statistics are grouped into human-readable sessions.
-- A gap greater than this starts a new session.
Stats.session_gap_seconds = 10 * 60

local function exists(path)
    local a = lfs.attributes(path)
    return a and a.mode == "file"
end

function Stats:read()
    local result = {
        available = false,
        books = {},
        sessions = {},
        total_seconds = 0,
        page_rows = 0,
    }

    if not exists(self.db_path) then
        return result, "KOReader statistics.sqlite3 was not found."
    end

    local ok, err = pcall(function()
        local db = SQ3.open(self.db_path)

        local stmt = db:prepare([[
            SELECT
                b.id,
                b.title,
                b.authors,
                b.pages,
                b.series,
                b.md5,
                p.start_time,
                p.duration
            FROM book b
            JOIN page_stat_data p
              ON p.id_book = b.id
            WHERE p.duration > 0
            ORDER BY b.id, p.start_time;
        ]])

        local rows, nrows = stmt:reset():resultset("i")

        local by_book = {}

        if rows and nrows and nrows > 0 then
            for i = 1, nrows do
                local id_book = tonumber(rows[1][i])
                local title = rows[2][i]
                local authors = rows[3][i]
                local pages = tonumber(rows[4][i])
                local series = rows[5][i]
                local md5 = rows[6][i]
                local start_time = tonumber(rows[7][i]) or 0
                local duration = tonumber(rows[8][i]) or 0

                result.page_rows = result.page_rows + 1

                if not by_book[id_book] then
                    by_book[id_book] = {
                        id = id_book,
                        title = title,
                        authors = authors,
                        pages = pages,
                        series = series,
                        md5 = md5,
                        rows = {},
                    }

                    table.insert(result.books, by_book[id_book])
                end

                table.insert(by_book[id_book].rows, {
                    start_time = start_time,
                    duration = duration,
                })
            end
        end

        stmt:close()
        db:close()

        for _, book in ipairs(result.books) do
            local current

            for _, row in ipairs(book.rows) do
                local row_end = row.start_time + row.duration

                if not current
                    or row.start_time > current.last_end + self.session_gap_seconds then

                    current = {
                        id_book = book.id,
                        title = book.title,
                        authors = book.authors,
                        md5 = book.md5,
                        start_time = row.start_time,
                        duration = row.duration,
                        last_end = row_end,
                    }

                    table.insert(result.sessions, current)
                else
                    current.duration =
                        current.duration
                        + row.duration

                    if row_end > current.last_end then
                        current.last_end = row_end
                    end
                end
            end
        end

        for _, session in ipairs(result.sessions) do
            result.total_seconds =
                result.total_seconds
                + (session.duration or 0)

            session.last_end = nil
        end

        result.available = true
    end)

    if not ok then
        return nil, tostring(err)
    end

    return result
end

return Stats
