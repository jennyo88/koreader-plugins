local DataStorage = require("datastorage")
local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local Stats = {}

local DB_PATH =
    DataStorage:getSettingsDir()
    .. "/statistics.sqlite3"

function Stats:read()
    if lfs.attributes(DB_PATH, "mode") ~= "file" then
        return {
            available = false,
            sessions = {},
        }
    end

    local db = SQ3.open(DB_PATH, "ro")

    local stmt =
        db:prepare([[
            SELECT
                b.title,
                coalesce(b.authors, ''),
                p.start_time,
                p.duration
            FROM page_stat p
            JOIN book b
              ON b.id = p.id_book
            WHERE p.duration > 0
            ORDER BY p.start_time;
        ]])

    local raw = {}

    while true do
        local row = stmt:step()
        if not row then
            break
        end

        table.insert(raw, {
            title = row[1] or "Untitled",
            authors = row[2] or "",
            start_time = tonumber(row[3]) or 0,
            duration = tonumber(row[4]) or 0,
        })
    end

    stmt:close()
    db:close()

    local sessions = {}
    local current
    local GAP = 600

    for _, item in ipairs(raw) do
        if item.start_time > 0 and item.duration > 0 then
            local same =
                current
                and current.title == item.title
                and current.authors == item.authors

            local last_end =
                current
                and (
                    current._last_start
                    + current._last_duration
                )
                or 0

            if same
                and item.start_time >= last_end
                and item.start_time - last_end <= GAP then

                current.duration =
                    current.duration
                    + item.duration

                current._last_start =
                    item.start_time

                current._last_duration =
                    item.duration
            else
                current = {
                    title = item.title,
                    authors = item.authors,
                    start_time = item.start_time,
                    duration = item.duration,
                    _last_start = item.start_time,
                    _last_duration = item.duration,
                }

                table.insert(sessions, current)
            end
        end
    end

    for _, session in ipairs(sessions) do
        session._last_start = nil
        session._last_duration = nil
    end

    return {
        available = true,
        sessions = sessions,
    }
end

return Stats
