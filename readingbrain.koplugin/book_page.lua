local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local BookPage = {}

local DB_PATH =
    "/mnt/us/readingbrain/readingbrain.sqlite3"

local function human(seconds)
    seconds = tonumber(seconds) or 0

    local minutes =
        math.floor(seconds / 60)

    local hours =
        math.floor(minutes / 60)

    minutes = minutes % 60

    if hours > 0 then
        return
            string.format(
                "%dh %02dm",
                hours,
                minutes
            )
    end

    return
        string.format(
            "%dm",
            minutes
        )
end

local function normalize(value)
    if type(value) ~= "string" then
        return ""
    end

    value = value:lower()
    value = value:gsub("[^%w%s]", " ")
    value = value:gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""

    return value
end

local function latest_rating(book)
    local rating =
        tonumber(
            book
            and book.last_read_done_star
        )

    if rating
        and rating > 0 then

        return rating
    end

    local reads =
        book
        and book.reads
        or {}

    for i = #reads, 1, -1 do
        local star =
            tonumber(
                reads[i].star
            )

        if star
            and star > 0 then

            return star
        end
    end

    return nil
end

local function find_bookmory(title, books)
    local target =
        normalize(title)

    if target == "" then
        return nil
    end

    for _, book in ipairs(
        books or {}
    ) do
        if normalize(book.title) == target then
            return book
        end
    end

    return nil
end

function BookPage:build(book_key, title, bookmory_books)
    local a =
        lfs.attributes(DB_PATH)

    if not a
        or a.mode ~= "file" then

        return
            "No unified history yet.\n\n"
            .. "Run Sync Reading History first."
    end

    local db =
        SQ3.open(DB_PATH)

    db:exec(
        "PRAGMA query_only = ON;"
    )

    local stmt =
        db:prepare([[
            SELECT
                count(*) AS sessions,
                coalesce(sum(duration), 0) AS total,
                coalesce(avg(duration), 0) AS average,
                coalesce(max(duration), 0) AS longest,
                min(start_time) AS first_time,
                max(start_time) AS last_time,
                coalesce(sum(
                    CASE WHEN medium = 'Kindle'
                    THEN duration ELSE 0 END
                ), 0) AS kindle,
                coalesce(sum(
                    CASE WHEN medium = 'Audiobook'
                    THEN duration ELSE 0 END
                ), 0) AS audio,
                coalesce(sum(
                    CASE WHEN medium = 'External/Hybrid'
                    THEN duration ELSE 0 END
                ), 0) AS hybrid
            FROM sessions
            WHERE book_key = ?
              AND duration > 0;
        ]])

    stmt:bind(
        1,
        book_key
    )

    local rows,
        nrows =
        stmt:resultset("i")

    stmt:close()
    db:close()

    if not rows
        or not nrows
        or nrows < 1 then

        return
            "No reading sessions found for this book."
    end

    local sessions =
        tonumber(rows[1][1]) or 0

    local total =
        tonumber(rows[2][1]) or 0

    local average =
        tonumber(rows[3][1]) or 0

    local longest =
        tonumber(rows[4][1]) or 0

    local first_time =
        tonumber(rows[5][1]) or 0

    local last_time =
        tonumber(rows[6][1]) or 0

    local kindle =
        tonumber(rows[7][1]) or 0

    local audio =
        tonumber(rows[8][1]) or 0

    local hybrid =
        tonumber(rows[9][1]) or 0

    local bm =
        find_bookmory(
            title,
            bookmory_books
        )

    local rating =
        latest_rating(bm)

    local progress

    if bm then
        local cur =
            tonumber(bm.cur_page)

        local total_page =
            tonumber(
                bm.real_total_page
                or bm.total_page
            )

        if cur
            and total_page
            and total_page > 0 then

            progress =
                math.floor(
                    cur / total_page
                    * 100
                    + 0.5
                )
        end
    end

    local lines = {
        "READING",
        "Sessions ............ "
            .. tostring(sessions),

        "Total time .......... "
            .. human(total),

        "Average session ..... "
            .. human(average),

        "Longest session ..... "
            .. human(longest),
    }

    if first_time > 0 then
        table.insert(
            lines,
            "First session ....... "
            .. os.date(
                "%b %d, %Y",
                first_time
            )
        )
    end

    if last_time > 0 then
        table.insert(
            lines,
            "Last session ........ "
            .. os.date(
                "%b %d, %Y",
                last_time
            )
        )
    end

    table.insert(lines, "")
    table.insert(lines, "FORMAT MIX")

    table.insert(
        lines,
        "Kindle ............... "
        .. human(kindle)
    )

    table.insert(
        lines,
        "Audiobook ............ "
        .. human(audio)
    )

    table.insert(
        lines,
        "External / Hybrid .... "
        .. human(hybrid)
    )

    if rating
        or progress then

        table.insert(lines, "")
        table.insert(lines, "BOOKMORY")
    end

    if progress then
        table.insert(
            lines,
            "Progress ............. "
            .. tostring(progress)
            .. "%"
        )
    end

    if rating then
        table.insert(
            lines,
            "Rating ............... "
            .. string.format(
                "%.1f★",
                rating
            )
        )
    end

    return table.concat(
        lines,
        "\n"
    )
end

return BookPage
