local StatsPatterns = {}

local function rating(book)
    local direct = tonumber(book.last_read_done_star)
    if direct and direct > 0 then
        return direct
    end

    for i = #(book.reads or {}), 1, -1 do
        local star = tonumber(book.reads[i].star)
        if star and star > 0 then
            return star
        end
    end
    return nil
end

local function authorString(book)
    if type(book.authors) == "table" then
        return table.concat(book.authors, ", ")
    end
    return tostring(book.author or book.authors or "")
end

local function sessions(book)
    local out = {}

    for _, read in ipairs(book.reads or {}) do
        for _, timer in ipairs(read.read_timer_list or {}) do
            local sec = tonumber(timer.elapsed_sec) or 0
            local start =
                math.floor(
                    (tonumber(timer.read_started_at) or 0)
                    / 1000
                )

            if sec > 0 and start > 0 then
                table.insert(out, {
                    seconds = sec,
                    start = start,
                })
            end
        end
    end

    return out
end

local function human(seconds)
    local minutes =
        math.floor(
            (tonumber(seconds) or 0)
            / 60
        )

    return string.format(
        "%dh %02dm",
        math.floor(minutes / 60),
        minutes % 60
    )
end

local function top(map, count)
    local list = {}

    for key, value in pairs(map) do
        table.insert(list, {
            key = key,
            value = value,
        })
    end

    table.sort(
        list,
        function(a, b)
            if a.value == b.value then
                return a.key < b.key
            end
            return a.value > b.value
        end
    )

    local out = {}

    for i = 1, math.min(count or 5, #list) do
        table.insert(out, list[i])
    end

    return out
end

local function allSessions(books)
    local out = {}

    for _, book in ipairs(books or {}) do
        for _, s in ipairs(sessions(book)) do
            s.title = book.title or "Untitled"
            table.insert(out, s)
        end
    end

    return out
end

function StatsPatterns:thisYear(books)
    local year = os.date("%Y")
    local finished = 0
    local seconds = 0

    for _, book in ipairs(books or {}) do
        for _, s in ipairs(sessions(book)) do
            if os.date("%Y", s.start) == year then
                seconds = seconds + s.seconds
            end
        end

        for _, read in ipairs(book.reads or {}) do
            if tostring(read.status) == "DONE"
                and tonumber(read["end"])
                and os.date(
                    "%Y",
                    math.floor(tonumber(read["end"]) / 1000)
                ) == year then

                finished = finished + 1
                break
            end
        end
    end

    return
        "Reading time ........ "
        .. human(seconds)
        .. "\n"
        .. "Finished books ...... "
        .. tostring(finished)
end

function StatsPatterns:monthlyReading(books)
    local month_map = {}

    for _, s in ipairs(allSessions(books)) do
        local key = os.date("%Y-%m", s.start)
        month_map[key] =
            (month_map[key] or 0)
            + s.seconds
    end

    local keys = {}
    for key in pairs(month_map) do
        table.insert(keys, key)
    end
    table.sort(keys)

    local out = {}

    local first =
        math.max(
            1,
            #keys - 11
        )

    for i = first, #keys do
        local y, m =
            keys[i]:match("^(%d%d%d%d)%-(%d%d)$")

        local timestamp =
            os.time{
                year = tonumber(y),
                month = tonumber(m),
                day = 1,
                hour = 12,
            }

        table.insert(
            out,
            os.date("%b %Y", timestamp)
            .. " ........ "
            .. human(month_map[keys[i]])
        )
    end

    if #out == 0 then
        return "No timed Bookmory sessions found."
    end

    return table.concat(out, "\n")
end

function StatsPatterns:readingFormats(books)
    local formats = {}

    for _, book in ipairs(books or {}) do
        local key =
            tostring(book.book_type or "Unknown")

        formats[key] =
            (formats[key] or 0) + 1
    end

    local out = {}
    for _, item in ipairs(top(formats, 8)) do
        table.insert(
            out,
            item.key
            .. " ........ "
            .. tostring(item.value)
        )
    end

    return
        #out > 0
        and table.concat(out, "\n")
        or "No format data available."
end

function StatsPatterns:ratings(books)
    local counts = {}
    local total = 0
    local sum = 0

    for _, book in ipairs(books or {}) do
        local r = rating(book)
        if r then
            total = total + 1
            sum = sum + r
            local key = string.format("%.1f", r)
            counts[key] =
                (counts[key] or 0) + 1
        end
    end

    if total == 0 then
        return "No ratings available."
    end

    local keys = {}
    for key in pairs(counts) do
        table.insert(keys, key)
    end

    table.sort(
        keys,
        function(a, b)
            return tonumber(a) > tonumber(b)
        end
    )

    local out = {
        string.format(
            "Average rating ...... %.2f",
            sum / total
        ),
        "Rated books ......... "
            .. tostring(total),
        "",
        "DISTRIBUTION",
    }

    for _, key in ipairs(keys) do
        table.insert(
            out,
            key
            .. "★ ................. "
            .. tostring(counts[key])
        )
    end

    return table.concat(out, "\n")
end

function StatsPatterns:authorsAndGenres(books)
    local authors = {}
    local tags = {}

    for _, book in ipairs(books or {}) do
        local r = rating(book)
        if r and r >= 4 then
            local a = authorString(book)
            if a ~= "" then
                authors[a] =
                    (authors[a] or 0) + 1
            end

            if type(book.tags) == "string" then
                for tag in book.tags:gmatch("#([^#]+)") do
                    tag =
                        tag:match("^%s*(.-)%s*$")
                    if tag and tag ~= "" then
                        tags[tag] =
                            (tags[tag] or 0) + 1
                    end
                end
            end
        end
    end

    local out = {"TOP HIGH-RATED AUTHORS"}

    for _, item in ipairs(top(authors, 5)) do
        table.insert(
            out,
            item.key
            .. " ........ "
            .. tostring(item.value)
        )
    end

    table.insert(out, "")
    table.insert(out, "TOP HIGH-RATED TAGS")

    for _, item in ipairs(top(tags, 8)) do
        table.insert(
            out,
            item.key
            .. " ........ "
            .. tostring(item.value)
        )
    end

    return table.concat(out, "\n")
end

function StatsPatterns:readingHabits(books)
    local weekdays = {}
    local hours = {}
    local total_sessions = 0
    local total_seconds = 0

    for _, s in ipairs(allSessions(books)) do
        total_sessions = total_sessions + 1
        total_seconds = total_seconds + s.seconds

        local day = os.date("%A", s.start)
        weekdays[day] =
            (weekdays[day] or 0)
            + s.seconds

        local hour = tonumber(os.date("%H", s.start)) or 0
        local bucket

        if hour < 6 then
            bucket = "Late night"
        elseif hour < 12 then
            bucket = "Morning"
        elseif hour < 18 then
            bucket = "Afternoon"
        else
            bucket = "Evening"
        end

        hours[bucket] =
            (hours[bucket] or 0)
            + s.seconds
    end

    if total_sessions == 0 then
        return "No timed Bookmory sessions found."
    end

    local out = {
        "Sessions ............ "
            .. tostring(total_sessions),
        "Average session ..... "
            .. human(total_seconds / total_sessions),
        "",
        "MOST READING BY DAY",
    }

    for _, item in ipairs(top(weekdays, 7)) do
        table.insert(
            out,
            item.key
            .. " ........ "
            .. human(item.value)
        )
    end

    table.insert(out, "")
    table.insert(out, "TIME OF DAY")

    for _, item in ipairs(top(hours, 4)) do
        table.insert(
            out,
            item.key
            .. " ........ "
            .. human(item.value)
        )
    end

    return table.concat(out, "\n")
end

function StatsPatterns:interestingPatterns(books)
    local longest
    local days = {}

    for _, s in ipairs(allSessions(books)) do
        if not longest or s.seconds > longest.seconds then
            longest = s
        end

        local day = os.date("%Y-%m-%d", s.start)
        days[day] =
            (days[day] or 0)
            + s.seconds
    end

    local best_day
    for day, sec in pairs(days) do
        if not best_day or sec > best_day.seconds then
            best_day = {
                day = day,
                seconds = sec,
            }
        end
    end

    local out = {}

    if longest then
        table.insert(
            out,
            "Longest session .... "
            .. human(longest.seconds)
        )

        table.insert(
            out,
            "Book ............... "
            .. tostring(longest.title)
        )
    end

    if best_day then
        table.insert(out, "")
        table.insert(
            out,
            "Most intense day ... "
            .. best_day.day
        )
        table.insert(
            out,
            "Reading time ....... "
            .. human(best_day.seconds)
        )
    end

    return
        #out > 0
        and table.concat(out, "\n")
        or "Not enough timed reading data yet."
end

function StatsPatterns:readingRecords(books)
    local max_book
    local book_totals = {}

    for _, book in ipairs(books or {}) do
        local total = 0
        for _, s in ipairs(sessions(book)) do
            total = total + s.seconds
        end

        if total > 0 then
            table.insert(
                book_totals,
                {
                    title = book.title or "Untitled",
                    seconds = total,
                }
            )
        end
    end

    table.sort(
        book_totals,
        function(a, b)
            return a.seconds > b.seconds
        end
    )

    local out = {"MOST TIME SPENT"}

    for i = 1, math.min(5, #book_totals) do
        table.insert(
            out,
            tostring(i)
            .. ". "
            .. book_totals[i].title
            .. "\n   "
            .. human(book_totals[i].seconds)
        )
    end

    return
        #book_totals > 0
        and table.concat(out, "\n")
        or "No timed reading records yet."
end

return StatsPatterns
