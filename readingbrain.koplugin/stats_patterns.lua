local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local StatsPatterns = {}
local DB_PATH = "/mnt/us/readingbrain/readingbrain.sqlite3"
local MONTHS = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local WEEKDAYS = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}

local function exists(path)
    local a = lfs.attributes(path)
    return a and a.mode == "file"
end

local function normalize(v)
    if type(v) ~= "string" then
        return ""
    end

    v = v:lower()
    v = v:gsub("&", " and ")
    v = v:gsub("[^%w%s]", " ")
    v = v:gsub("%s+", " ")
    return v:match("^%s*(.-)%s*$") or ""
end

local function human(seconds)
    seconds = tonumber(seconds) or 0
    local m = math.floor(seconds / 60)
    local h = math.floor(m / 60)
    m = m % 60

    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end

    return string.format("%dm", m)
end

local function span(seconds)
    local d = (tonumber(seconds) or 0) / 86400

    if d < 1 then
        return string.format("%.1fh", (tonumber(seconds) or 0) / 3600)
    elseif d < 10 then
        return string.format("%.1f days", d)
    end

    return string.format("%.0f days", d)
end

local function bar(value, max_value, width)
    width = width or 12

    if not max_value or max_value <= 0 then
        return string.rep("·", width)
    end

    local n = math.floor((value / max_value) * width + 0.5)
    n = math.max(0, math.min(width, n))

    return
        string.rep("■", n)
        .. string.rep("·", width - n)
end

local function latest_rating(book)
    local r = tonumber(book.last_read_done_star)

    if r and r > 0 then
        return r
    end

    local reads = book.reads or {}

    for i = #reads, 1, -1 do
        r = tonumber(reads[i].star)

        if r and r > 0 then
            return r
        end
    end

    return nil
end

local function tags_for(book)
    local out = {}

    if type(book.tags) == "table" then
        for _, t in ipairs(book.tags) do
            if type(t) == "string" and t ~= "" then
                table.insert(out, t)
            end
        end
    elseif type(book.tags) == "string" then
        for t in book.tags:gmatch("#([^#]+)") do
            t = t:match("^%s*(.-)%s*$")

            if t and t ~= "" then
                table.insert(out, t)
            end
        end
    end

    return out
end

local function authors_for(book)
    if type(book.authors) == "table" then
        return book.authors
    end

    if type(book.authors) == "string" and book.authors ~= "" then
        return {book.authors}
    end

    if type(book.author) == "string" and book.author ~= "" then
        return {book.author}
    end

    return {}
end

local function bookmory_sessions(book)
    local out = {}

    for _, read in ipairs(book.reads or {}) do
        for _, timer in ipairs(read.read_timer_list or {}) do
            local ms =
                tonumber(timer.read_started_at)
                or tonumber(timer.created_at)
                or 0

            local st = math.floor(ms / 1000)
            local dur = tonumber(timer.elapsed_sec) or 0

            if st > 0 and dur > 0 then
                table.insert(out, {
                    start_time = st,
                    duration = dur,
                })
            end
        end
    end

    table.sort(
        out,
        function(a, b)
            return a.start_time < b.start_time
        end
    )

    return out
end

local function latest_book_activity(book)
    local latest = 0

    for _, read in ipairs(book.reads or {}) do
        local read_time =
            tonumber(read["end"])
            or tonumber(read.start)
            or 0

        if read_time > 100000000000 then
            read_time = math.floor(read_time / 1000)
        end

        latest = math.max(latest, read_time)

        for _, timer in ipairs(read.read_timer_list or {}) do
            local timer_time =
                tonumber(timer.read_started_at)
                or tonumber(timer.created_at)
                or 0

            if timer_time > 100000000000 then
                timer_time = math.floor(timer_time / 1000)
            end

            latest = math.max(latest, timer_time)
        end
    end

    return latest
end

local function unified_sessions()
    local out = {}

    if not exists(DB_PATH) then
        return out
    end

    local ok = pcall(function()
        local db = SQ3.open(DB_PATH)
        db:exec("PRAGMA query_only = ON;")

        local stmt = db:prepare([[
            SELECT
                b.title,
                b.authors,
                s.source,
                s.medium,
                s.start_time,
                s.duration
            FROM sessions s
            LEFT JOIN books b
              ON b.book_key = s.book_key
            WHERE s.duration > 0
              AND s.start_time > 0
            ORDER BY s.start_time;
        ]])

        local rows, n = stmt:reset():resultset("i")

        if rows and n and n > 0 then
            for i = 1, n do
                table.insert(out, {
                    title = rows[1][i] or "Unknown title",
                    authors = rows[2][i] or "",
                    source = rows[3][i] or "Unknown",
                    medium = rows[4][i] or "Unknown",
                    start_time = tonumber(rows[5][i]) or 0,
                    duration = tonumber(rows[6][i]) or 0,
                })
            end
        end

        stmt:close()
        db:close()
    end)

    if not ok then
        return {}
    end

    return out
end

local function merge_intervals(sessions)
    local sorted = {}

    for _, s in ipairs(sessions or {}) do
        local st = tonumber(s.start_time) or 0
        local dur = tonumber(s.duration) or 0

        if st > 0 and dur > 0 then
            table.insert(sorted, {
                start_time = st,
                duration = dur,
                finish = st + dur,
            })
        end
    end

    table.sort(
        sorted,
        function(a, b)
            return a.start_time < b.start_time
        end
    )

    local merged = {}
    local current

    for _, s in ipairs(sorted) do
        if not current then
            current = {
                start_time = s.start_time,
                finish = s.finish,
            }
        elseif s.start_time <= current.finish then
            if s.finish > current.finish then
                current.finish = s.finish
            end
        else
            current.duration = current.finish - current.start_time
            table.insert(merged, current)
            current = {
                start_time = s.start_time,
                finish = s.finish,
            }
        end
    end

    if current then
        current.duration = current.finish - current.start_time
        table.insert(merged, current)
    end

    return merged
end

local function merged_seconds(sessions)
    local total = 0

    for _, s in ipairs(merge_intervals(sessions)) do
        total = total + (s.duration or 0)
    end

    return total
end

local function window_sessions(sessions, start_time, end_time)
    local out = {}

    for _, s in ipairs(sessions or {}) do
        local st = tonumber(s.start_time) or 0
        local finish = st + (tonumber(s.duration) or 0)
        local clipped_start = math.max(st, start_time)
        local clipped_end = math.min(finish, end_time)

        if clipped_end > clipped_start then
            table.insert(out, {
                title = s.title,
                authors = s.authors,
                source = s.source,
                medium = s.medium,
                start_time = clipped_start,
                duration = clipped_end - clipped_start,
            })
        end
    end

    return out
end

local function group_by_title(sessions)
    local groups = {}

    for _, s in ipairs(sessions or {}) do
        local key = normalize(s.title)

        if key ~= "" then
            local item = groups[key]

            if not item then
                item = {
                    title = s.title or "Unknown title",
                    sessions = {},
                }
                groups[key] = item
            end

            table.insert(item.sessions, s)
        end
    end

    return groups
end

local function tag_patterns(books)
    local stats = {}

    for _, book in ipairs(books or {}) do
        local r = latest_rating(book)

        if r then
            for _, t in ipairs(tags_for(book)) do
                local k = normalize(t)

                if k ~= "" then
                    local s = stats[k] or {
                        label = t,
                        ratings = {},
                    }

                    table.insert(s.ratings, r)
                    stats[k] = s
                end
            end
        end
    end

    local reliable
    local unpredictable

    for _, s in pairs(stats) do
        if #s.ratings >= 4 then
            local sum = 0

            for _, v in ipairs(s.ratings) do
                sum = sum + v
            end

            s.mean = sum / #s.ratings

            local variance = 0

            for _, v in ipairs(s.ratings) do
                variance = variance + (v - s.mean) ^ 2
            end

            s.variance = variance / #s.ratings

            if s.mean >= 4
                and (
                    not reliable
                    or s.mean > reliable.mean
                    or (
                        s.mean == reliable.mean
                        and #s.ratings > #reliable.ratings
                    )
                ) then

                reliable = s
            end

            if not unpredictable
                or s.variance > unpredictable.variance then

                unpredictable = s
            end
        end
    end

    return reliable, unpredictable
end

local function recurring_rating_records(books)
    local astats = {}
    local tstats = {}

    for _, book in ipairs(books or {}) do
        local r = latest_rating(book)

        if r then
            for _, a in ipairs(authors_for(book)) do
                local k = normalize(a)

                if k ~= "" then
                    local s = astats[k] or {
                        label = a,
                        count = 0,
                        total = 0,
                    }
                    s.count = s.count + 1
                    s.total = s.total + r
                    astats[k] = s
                end
            end

            for _, t in ipairs(tags_for(book)) do
                local k = normalize(t)

                if k ~= "" then
                    local s = tstats[k] or {
                        label = t,
                        count = 0,
                        total = 0,
                    }
                    s.count = s.count + 1
                    s.total = s.total + r
                    tstats[k] = s
                end
            end
        end
    end

    local best_author
    local best_tag

    for _, s in pairs(astats) do
        if s.count >= 2 then
            s.avg = s.total / s.count

            if not best_author
                or s.avg > best_author.avg
                or (
                    s.avg == best_author.avg
                    and s.count > best_author.count
                ) then

                best_author = s
            end
        end
    end

    for _, s in pairs(tstats) do
        if s.count >= 4 then
            s.avg = s.total / s.count

            if not best_tag
                or s.avg > best_tag.avg
                or (
                    s.avg == best_tag.avg
                    and s.count > best_tag.count
                ) then

                best_tag = s
            end
        end
    end

    return best_author, best_tag
end

local function timing_patterns(books)
    local fastest
    local comeback
    local slow_burn

    for _, book in ipairs(books or {}) do
        local ss = bookmory_sessions(book)
        local r = latest_rating(book)

        if #ss >= 2 then
            local span_value =
                (ss[#ss].start_time + ss[#ss].duration)
                - ss[1].start_time

            if r and r >= 4.5
                and #ss >= 3
                and span_value > 0
                and (
                    not fastest
                    or span_value < fastest.span
                ) then

                fastest = {
                    title = book.title or "Unknown title",
                    span = span_value,
                    rating = r,
                }
            end

            if r and r >= 4.5
                and span_value >= 14 * 86400
                and (
                    not slow_burn
                    or span_value > slow_burn.span
                ) then

                slow_burn = {
                    title = book.title or "Unknown title",
                    span = span_value,
                    rating = r,
                }
            end

            local gap = 0

            for i = 2, #ss do
                local prev =
                    ss[i - 1].start_time
                    + ss[i - 1].duration

                gap = math.max(
                    gap,
                    ss[i].start_time - prev
                )
            end

            if gap >= 7 * 86400
                and (
                    not comeback
                    or gap > comeback.gap
                ) then

                comeback = {
                    title = book.title or "Unknown title",
                    gap = gap,
                }
            end
        end
    end

    return fastest, comeback, slow_burn
end

local function recent_tag_drift(books)
    local cutoff = os.time() - 180 * 86400
    local recent = {}
    local older = {}
    local recent_books = 0
    local older_books = 0

    for _, book in ipairs(books or {}) do
        local r = latest_rating(book)
        local activity = latest_book_activity(book)

        if r and activity > 0 then
            local target

            if activity >= cutoff then
                recent_books = recent_books + 1
                target = recent
            else
                older_books = older_books + 1
                target = older
            end

            local seen = {}

            for _, tag in ipairs(tags_for(book)) do
                local k = normalize(tag)

                if k ~= "" and not seen[k] then
                    seen[k] = true
                    local item = target[k] or {
                        label = tag,
                        count = 0,
                    }
                    item.count = item.count + 1
                    target[k] = item
                end
            end
        end
    end

    if recent_books < 6 or older_books < 12 then
        return nil
    end

    local best

    for key, item in pairs(recent) do
        local old_count = older[key] and older[key].count or 0
        local recent_share = item.count / recent_books
        local older_share = old_count / older_books
        local delta = recent_share - older_share

        if item.count >= 2
            and delta >= 0.15
            and (
                not best
                or delta > best.delta
            ) then

            best = {
                label = item.label,
                recent_share = recent_share,
                older_share = older_share,
                delta = delta,
            }
        end
    end

    return best
end

local function day_totals_from_merged(merged)
    local days = {}

    for _, s in ipairs(merged or {}) do
        local day = os.date("%Y-%m-%d", s.start_time)
        days[day] = (days[day] or 0) + s.duration
    end

    return days
end

local function date_epoch(day)
    local y, m, d = tostring(day):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")

    if not y then
        return 0
    end

    return os.time{
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 12,
        min = 0,
        sec = 0,
    } or 0
end

function StatsPatterns:thisYear(bookmory_books)
    local sessions = unified_sessions()

    if #sessions == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local year = tonumber(os.date("%Y"))
    local filtered = {}
    local kindle = 0
    local audio = 0
    local hybrid = 0
    local days = {}
    local books = {}

    for _, s in ipairs(sessions) do
        if tonumber(os.date("%Y", s.start_time)) == year then
            table.insert(filtered, s)

            if s.medium == "Kindle" then
                kindle = kindle + s.duration
            elseif s.medium == "Audiobook" then
                audio = audio + s.duration
            elseif s.medium == "External/Hybrid" then
                hybrid = hybrid + s.duration
            end

            days[os.date("%Y-%m-%d", s.start_time)] = true
            books[normalize(s.title)] = true
        end
    end

    local elapsed = merged_seconds(filtered)
    local d = 0
    local b = 0

    for _ in pairs(days) do
        d = d + 1
    end

    for k in pairs(books) do
        if k ~= "" then
            b = b + 1
        end
    end

    local maxv = math.max(kindle, audio, hybrid, 1)

    return
        tostring(year)
        .. " • overlap-adjusted elapsed time\n\n"
        .. "ELAPSED READING\n"
        .. bar(elapsed, elapsed, 20)
        .. "  "
        .. human(elapsed)
        .. "\n\nLOGGED BY MEDIUM\n"
        .. "Kindle\n"
        .. bar(kindle, maxv, 18)
        .. "  "
        .. human(kindle)
        .. "\n\nAudiobook\n"
        .. bar(audio, maxv, 18)
        .. "  "
        .. human(audio)
        .. "\n\nExternal / Hybrid\n"
        .. bar(hybrid, maxv, 18)
        .. "  "
        .. human(hybrid)
        .. "\n\nActive reading days: "
        .. d
        .. "\nBooks with sessions: "
        .. b
end

function StatsPatterns:monthlyReading(bookmory_books)
    local sessions = unified_sessions()

    if #sessions == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local year = tonumber(os.date("%Y"))
    local by_month = {}

    for i = 1, 12 do
        by_month[i] = {}
    end

    for _, s in ipairs(sessions) do
        if tonumber(os.date("%Y", s.start_time)) == year then
            local month = tonumber(os.date("%m", s.start_time))
            table.insert(by_month[month], s)
        end
    end

    local values = {}
    local maxv = 0

    for i = 1, 12 do
        values[i] = merged_seconds(by_month[i])
        maxv = math.max(maxv, values[i])
    end

    local lines = {
        tostring(year) .. " • overlap-adjusted elapsed time",
        "",
    }

    for i = 1, 12 do
        table.insert(
            lines,
            string.format(
                "%s  %s  %s",
                MONTHS[i],
                bar(values[i], maxv, 14),
                human(values[i])
            )
        )
    end

    return table.concat(lines, "\n")
end

function StatsPatterns:readingFormats(bookmory_books)
    local sessions = unified_sessions()

    if #sessions == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local totals = {}
    local logged_total = 0

    for _, s in ipairs(sessions) do
        totals[s.medium] =
            (totals[s.medium] or 0)
            + s.duration

        logged_total = logged_total + s.duration
    end

    local elapsed = merged_seconds(sessions)
    local lines = {
        "Elapsed overall .... " .. human(elapsed),
        "Source logs ........ " .. human(logged_total),
        "",
    }

    for _, medium in ipairs({
        "Kindle",
        "Audiobook",
        "External/Hybrid",
    }) do
        local sec = totals[medium] or 0
        local pct = logged_total > 0 and sec / logged_total * 100 or 0

        table.insert(lines, medium)
        table.insert(
            lines,
            bar(sec, logged_total, 20)
            .. string.format(
                "  %.1f%% • %s",
                pct,
                human(sec)
            )
        )
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end

function StatsPatterns:ratings(bookmory_books)
    local dist = {}

    for r = 0.5, 5, 0.5 do
        dist[r] = 0
    end

    local count = 0
    local total = 0

    for _, book in ipairs(bookmory_books or {}) do
        local r = latest_rating(book)

        if r then
            r = math.floor(r * 2 + 0.5) / 2

            if dist[r] ~= nil then
                dist[r] = dist[r] + 1
            end

            count = count + 1
            total = total + r
        end
    end

    if count == 0 then
        return "No ratings were found in the Bookmory backup."
    end

    local maxv = 0

    for _, v in pairs(dist) do
        maxv = math.max(maxv, v)
    end

    local lines = {
        "Bookmory ratings • all time",
        string.format("Rated books: %d", count),
        string.format("Average rating: %.2f★", total / count),
        "",
    }

    for r = 5, 0.5, -0.5 do
        table.insert(
            lines,
            string.format(
                "%3.1f★  %s  %d",
                r,
                bar(dist[r] or 0, maxv, 12),
                dist[r] or 0
            )
        )
    end

    return table.concat(lines, "\n")
end

function StatsPatterns:authorsAndGenres(bookmory_books)
    local astats = {}
    local tstats = {}

    for _, book in ipairs(bookmory_books or {}) do
        local r = latest_rating(book)

        if r then
            for _, a in ipairs(authors_for(book)) do
                local k = normalize(a)

                if k ~= "" then
                    local s = astats[k] or {
                        label = a,
                        count = 0,
                        total = 0,
                    }
                    s.count = s.count + 1
                    s.total = s.total + r
                    astats[k] = s
                end
            end

            for _, t in ipairs(tags_for(book)) do
                local k = normalize(t)

                if k ~= "" then
                    local s = tstats[k] or {
                        label = t,
                        count = 0,
                        total = 0,
                    }
                    s.count = s.count + 1
                    s.total = s.total + r
                    tstats[k] = s
                end
            end
        end
    end

    local authors = {}
    local tags = {}

    for _, s in pairs(astats) do
        if s.count >= 2 then
            s.avg = s.total / s.count
            table.insert(authors, s)
        end
    end

    for _, s in pairs(tstats) do
        if s.count >= 3 then
            s.avg = s.total / s.count
            table.insert(tags, s)
        end
    end

    table.sort(
        authors,
        function(a, b)
            if a.avg == b.avg then
                return a.count > b.count
            end
            return a.avg > b.avg
        end
    )

    table.sort(
        tags,
        function(a, b)
            if a.avg == b.avg then
                return a.count > b.count
            end
            return a.avg > b.avg
        end
    )

    local lines = {"TOP REPEAT AUTHORS"}

    for i = 1, math.min(5, #authors) do
        local x = authors[i]
        table.insert(
            lines,
            string.format(
                "%d. %s  %.2f★ (%d)",
                i,
                x.label,
                x.avg,
                x.count
            )
        )
    end

    table.insert(lines, "")
    table.insert(lines, "HIGHEST-RATED RECURRING TAGS")

    for i = 1, math.min(7, #tags) do
        local x = tags[i]
        table.insert(
            lines,
            string.format(
                "%d. %s  %.2f★ (%d)",
                i,
                x.label,
                x.avg,
                x.count
            )
        )
    end

    return table.concat(lines, "\n")
end

function StatsPatterns:readingHabits(bookmory_books)
    local raw = unified_sessions()

    if #raw == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local sessions = merge_intervals(raw)
    local wd = {}

    for i = 1, 7 do
        wd[i] = 0
    end

    local parts = {
        Morning = 0,
        Afternoon = 0,
        Evening = 0,
        ["Late night"] = 0,
    }

    local total = 0

    for _, s in ipairs(sessions) do
        local w = tonumber(os.date("%w", s.start_time)) + 1
        wd[w] = wd[w] + s.duration

        local h = tonumber(os.date("%H", s.start_time))
        local p =
            (h >= 5 and h < 12) and "Morning"
            or (h >= 12 and h < 17) and "Afternoon"
            or (h >= 17 and h < 22) and "Evening"
            or "Late night"

        parts[p] = parts[p] + s.duration
        total = total + s.duration
    end

    local maxw = 0

    for i = 1, 7 do
        maxw = math.max(maxw, wd[i])
    end

    local lines = {
        "All time • overlap-adjusted",
        "",
        "BY DAY OF WEEK",
    }

    for i = 1, 7 do
        table.insert(
            lines,
            string.format(
                "%s  %s  %s",
                WEEKDAYS[i],
                bar(wd[i], maxw, 8),
                human(wd[i])
            )
        )
    end

    table.insert(lines, "")
    table.insert(lines, "BY TIME OF DAY")

    local maxp = math.max(
        parts.Morning,
        parts.Afternoon,
        parts.Evening,
        parts["Late night"]
    )

    for _, p in ipairs({
        "Morning",
        "Afternoon",
        "Evening",
        "Late night",
    }) do
        table.insert(
            lines,
            string.format(
                "%-10s %s  %s",
                p,
                bar(parts[p], maxp, 8),
                human(parts[p])
            )
        )
    end

    table.insert(lines, "")
    table.insert(
        lines,
        "Average active block: "
        .. human(total / math.max(1, #sessions))
    )

    return table.concat(lines, "\n")
end

function StatsPatterns:interestingPatterns(bookmory_books)
    local raw = unified_sessions()

    if #raw == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local effective = merge_intervals(raw)
    local lines = {}

    local function section(title, body)
        if not body or body == "" then
            return
        end

        if #lines > 0 then
            table.insert(lines, "")
            table.insert(lines, "────────────────────")
            table.insert(lines, "")
        end

        table.insert(lines, title)
        table.insert(lines, body)
    end

    -- Reading momentum: last 30 days vs the 30 days before that.
    local now = os.time()
    local recent_start = now - 30 * 86400
    local previous_start = now - 60 * 86400
    local recent_sessions = window_sessions(raw, recent_start, now + 1)
    local previous_sessions = window_sessions(raw, previous_start, recent_start)

    if #recent_sessions >= 3 and #previous_sessions >= 3 then
        local recent_time = merged_seconds(recent_sessions)
        local previous_time = merged_seconds(previous_sessions)

        if previous_time >= 3600 then
            local change =
                (recent_time - previous_time)
                / previous_time
                * 100

            if math.abs(change) >= 20 then
                section(
                    "READING MOMENTUM",
                    "Last 30 days ....... "
                    .. human(recent_time)
                    .. "\nPrevious 30 days ... "
                    .. human(previous_time)
                    .. "\nChange ............. "
                    .. string.format("%+.0f%%", change)
                )
            end
        end
    end

    -- Format shift over the same two windows.
    local function medium_shares(list)
        local totals = {
            Kindle = 0,
            Audiobook = 0,
            ["External/Hybrid"] = 0,
        }
        local total = 0

        for _, s in ipairs(list) do
            if totals[s.medium] ~= nil then
                totals[s.medium] = totals[s.medium] + s.duration
                total = total + s.duration
            end
        end

        return totals, total
    end

    local recent_medium, recent_logged = medium_shares(recent_sessions)
    local previous_medium, previous_logged = medium_shares(previous_sessions)

    if recent_logged >= 3 * 3600
        and previous_logged >= 3 * 3600 then

        local best_medium
        local best_delta = 0

        for _, medium in ipairs({
            "Kindle",
            "Audiobook",
            "External/Hybrid",
        }) do
            local recent_share = recent_medium[medium] / recent_logged
            local previous_share = previous_medium[medium] / previous_logged
            local delta = recent_share - previous_share

            if math.abs(delta) > math.abs(best_delta) then
                best_delta = delta
                best_medium = medium
            end
        end

        if best_medium and math.abs(best_delta) >= 0.15 then
            section(
                "FORMAT SHIFT",
                best_medium
                .. " is "
                .. string.format(
                    "%+.0f percentage points",
                    best_delta * 100
                )
                .. " of your recent logged time versus the prior 30 days."
            )
        end
    end

    -- Weekend vs weekday, using average active day rather than raw totals.
    local day_totals = day_totals_from_merged(effective)
    local weekend_total = 0
    local weekday_total = 0
    local weekend_days = 0
    local weekday_days = 0

    for day, sec in pairs(day_totals) do
        local epoch = date_epoch(day)
        local w = tonumber(os.date("%w", epoch)) or 0

        if w == 0 or w == 6 then
            weekend_total = weekend_total + sec
            weekend_days = weekend_days + 1
        else
            weekday_total = weekday_total + sec
            weekday_days = weekday_days + 1
        end
    end

    if weekend_days >= 4 and weekday_days >= 8 then
        local weekend_avg = weekend_total / weekend_days
        local weekday_avg = weekday_total / weekday_days
        local bigger = math.max(weekend_avg, weekday_avg)
        local smaller = math.min(weekend_avg, weekday_avg)

        if smaller > 0 and bigger / smaller >= 1.25 then
            local label =
                weekend_avg > weekday_avg
                and "Weekend active days"
                or "Weekday active days"

            section(
                "WEEKEND VS WEEKDAY",
                label
                .. " run longer on average.\nWeekend .... "
                .. human(weekend_avg)
                .. "\nWeekday .... "
                .. human(weekday_avg)
            )
        end
    end

    -- Dominant time-of-day behavior.
    local parts = {
        Morning = 0,
        Afternoon = 0,
        Evening = 0,
        ["Late night"] = 0,
    }
    local effective_total = 0

    for _, s in ipairs(effective) do
        local h = tonumber(os.date("%H", s.start_time)) or 0
        local p =
            (h >= 5 and h < 12) and "Morning"
            or (h >= 12 and h < 17) and "Afternoon"
            or (h >= 17 and h < 22) and "Evening"
            or "Late night"

        parts[p] = parts[p] + s.duration
        effective_total = effective_total + s.duration
    end

    if effective_total >= 10 * 3600 then
        local best_part
        local best_sec = 0

        for name, sec in pairs(parts) do
            if sec > best_sec then
                best_part = name
                best_sec = sec
            end
        end

        local share = best_sec / effective_total

        if best_part and share >= 0.45 then
            section(
                "TIME-OF-DAY TENDENCY",
                best_part
                .. " accounts for "
                .. string.format("%.0f%%", share * 100)
                .. " of your overlap-adjusted reading time."
            )
        end
    end

    local reliable, unpredictable = tag_patterns(bookmory_books)

    if reliable then
        section(
            "RELIABLE TASTE SIGNAL",
            reliable.label
            .. " averages "
            .. string.format("%.2f★", reliable.mean)
            .. " across "
            .. tostring(#reliable.ratings)
            .. " rated books.\nEvidence: "
            .. (
                #reliable.ratings >= 8
                and "strong"
                or "moderate"
            )
        )
    end

    if unpredictable and unpredictable.variance >= 0.35 then
        section(
            "UNPREDICTABLE TASTE SIGNAL",
            unpredictable.label
            .. " has one of your widest rating spreads across "
            .. tostring(#unpredictable.ratings)
            .. " books.\nEvidence: "
            .. (
                #unpredictable.ratings >= 8
                and "strong"
                or "moderate"
            )
        )
    end

    local fastest, comeback, slow_burn = timing_patterns(bookmory_books)

    if fastest then
        section(
            "FASTEST OBSESSION",
            fastest.title
            .. "\n"
            .. span(fastest.span)
            .. " from first to last logged Bookmory session • "
            .. string.format("%.1f★", fastest.rating)
        )
    end

    if comeback then
        section(
            "BIGGEST COMEBACK",
            comeback.title
            .. "\nReturned after a "
            .. span(comeback.gap)
            .. " break."
        )
    end

    if slow_burn then
        section(
            "SLOW-BURN FAVORITE",
            slow_burn.title
            .. "\n"
            .. span(slow_burn.span)
            .. " across the reading span • "
            .. string.format("%.1f★", slow_burn.rating)
        )
    end

    -- Binge tendency: largest one-day share for a book with enough time.
    local best_binge

    for _, group in pairs(group_by_title(raw)) do
        local total = merged_seconds(group.sessions)

        if total >= 2 * 3600 and #group.sessions >= 2 then
            local day_map =
                day_totals_from_merged(
                    merge_intervals(group.sessions)
                )
            local best_day = 0

            for _, sec in pairs(day_map) do
                best_day = math.max(best_day, sec)
            end

            local share = best_day / total

            if share >= 0.60
                and (
                    not best_binge
                    or share > best_binge.share
                ) then

                best_binge = {
                    title = group.title,
                    share = share,
                    day_time = best_day,
                    total = total,
                }
            end
        end
    end

    if best_binge then
        section(
            "BINGE TENDENCY",
            best_binge.title
            .. "\n"
            .. string.format(
                "%.0f%% of its logged elapsed time happened in one day (%s).",
                best_binge.share * 100,
                human(best_binge.day_time)
            )
        )
    end

    local drift = recent_tag_drift(bookmory_books)

    if drift then
        section(
            "RECENT TASTE DRIFT",
            drift.label
            .. " appears in "
            .. string.format("%.0f%%", drift.recent_share * 100)
            .. " of your recent rated books versus "
            .. string.format("%.0f%%", drift.older_share * 100)
            .. " earlier.\nEvidence: moderate"
        )
    end

    if #lines == 0 then
        return "Not enough evidence yet for reliable pattern observations."
    end

    return table.concat(lines, "\n")
end

function StatsPatterns:readingRecords(bookmory_books)
    local raw = unified_sessions()

    if #raw == 0 then
        return "No unified history yet.\n\nRun Sync Reading History first."
    end

    local effective = merge_intervals(raw)
    local lines = {}

    local function record(title, body)
        if #lines > 0 then
            table.insert(lines, "")
            table.insert(lines, "────────────────────")
            table.insert(lines, "")
        end

        table.insert(lines, title)
        table.insert(lines, body)
    end

    local longest

    for _, s in ipairs(raw) do
        if not longest or s.duration > longest.duration then
            longest = s
        end
    end

    if longest then
        record(
            "LONGEST SESSION",
            tostring(longest.title)
            .. "\n"
            .. tostring(longest.medium)
            .. " • "
            .. human(longest.duration)
            .. "\n"
            .. os.date("%b %d, %Y", longest.start_time)
        )
    end

    local daily = day_totals_from_merged(effective)
    local best_day
    local best_day_seconds = 0

    for day, sec in pairs(daily) do
        if sec > best_day_seconds then
            best_day = day
            best_day_seconds = sec
        end
    end

    if best_day then
        record(
            "MOST INTENSE READING DAY",
            best_day
            .. "\n"
            .. human(best_day_seconds)
        )
    end

    local monthly = {}

    for _, s in ipairs(effective) do
        local month = os.date("%Y-%m", s.start_time)
        monthly[month] = (monthly[month] or 0) + s.duration
    end

    local best_month
    local best_month_seconds = 0

    for month, sec in pairs(monthly) do
        if sec > best_month_seconds then
            best_month = month
            best_month_seconds = sec
        end
    end

    if best_month then
        local y, m = best_month:match("^(%d%d%d%d)%-(%d%d)$")
        local ts = os.time{
            year = tonumber(y),
            month = tonumber(m),
            day = 1,
            hour = 12,
        }

        record(
            "STRONGEST MONTH",
            os.date("%B %Y", ts)
            .. "\n"
            .. human(best_month_seconds)
        )
    end

    -- Streaks and breaks by active reading day.
    local dates = {}

    for day in pairs(daily) do
        table.insert(dates, {
            day = day,
            epoch = date_epoch(day),
        })
    end

    table.sort(
        dates,
        function(a, b)
            return a.epoch < b.epoch
        end
    )

    local best_streak = 0
    local current_streak = 0
    local streak_start
    local best_start
    local best_end
    local biggest_break = 0
    local break_from
    local break_to

    for i, item in ipairs(dates) do
        if i == 1 then
            current_streak = 1
            streak_start = item
        else
            local diff = item.epoch - dates[i - 1].epoch
            local days_apart = math.floor(diff / 86400 + 0.5)

            if days_apart <= 1 then
                current_streak = current_streak + 1
            else
                if current_streak > best_streak then
                    best_streak = current_streak
                    best_start = streak_start
                    best_end = dates[i - 1]
                end

                local break_days = math.max(0, days_apart - 1)

                if break_days > biggest_break then
                    biggest_break = break_days
                    break_from = dates[i - 1]
                    break_to = item
                end

                current_streak = 1
                streak_start = item
            end
        end
    end

    if current_streak > best_streak and #dates > 0 then
        best_streak = current_streak
        best_start = streak_start
        best_end = dates[#dates]
    end

    if best_streak >= 2 and best_start and best_end then
        record(
            "LONGEST ACTIVE-READING STREAK",
            tostring(best_streak)
            .. " reading days\n"
            .. os.date("%b %d, %Y", best_start.epoch)
            .. " – "
            .. os.date("%b %d, %Y", best_end.epoch)
        )
    end

    if biggest_break >= 2 and break_from and break_to then
        record(
            "LONGEST BREAK BETWEEN READING DAYS",
            tostring(biggest_break)
            .. " days\n"
            .. os.date("%b %d, %Y", break_from.epoch)
            .. " → "
            .. os.date("%b %d, %Y", break_to.epoch)
        )
    end

    local groups = group_by_title(raw)
    local most_time
    local most_sessions
    local most_revisited
    local longest_span
    local medium_best = {
        Kindle = nil,
        Audiobook = nil,
        ["External/Hybrid"] = nil,
    }

    for _, group in pairs(groups) do
        table.sort(
            group.sessions,
            function(a, b)
                return a.start_time < b.start_time
            end
        )

        local elapsed = merged_seconds(group.sessions)
        local count = #group.sessions
        local first = group.sessions[1].start_time
        local last =
            group.sessions[#group.sessions].start_time
            + group.sessions[#group.sessions].duration
        local calendar_span = math.max(0, last - first)

        if not most_time or elapsed > most_time.value then
            most_time = {
                title = group.title,
                value = elapsed,
            }
        end

        if not most_sessions or count > most_sessions.value then
            most_sessions = {
                title = group.title,
                value = count,
            }
        end

        if not longest_span or calendar_span > longest_span.value then
            longest_span = {
                title = group.title,
                value = calendar_span,
            }
        end

        local revisits = 0

        for i = 2, #group.sessions do
            local previous_end =
                group.sessions[i - 1].start_time
                + group.sessions[i - 1].duration
            local gap = group.sessions[i].start_time - previous_end

            if gap >= 7 * 86400 then
                revisits = revisits + 1
            end
        end

        if revisits > 0
            and (
                not most_revisited
                or revisits > most_revisited.value
            ) then

            most_revisited = {
                title = group.title,
                value = revisits,
            }
        end

        for medium in pairs(medium_best) do
            local medium_sessions = {}

            for _, s in ipairs(group.sessions) do
                if s.medium == medium then
                    table.insert(medium_sessions, s)
                end
            end

            local medium_time = merged_seconds(medium_sessions)
            local current = medium_best[medium]

            if medium_time > 0
                and (
                    not current
                    or medium_time > current.value
                ) then

                medium_best[medium] = {
                    title = group.title,
                    value = medium_time,
                }
            end
        end
    end

    if most_time then
        record(
            "MOST ELAPSED READING TIME ON ONE BOOK",
            most_time.title
            .. "\n"
            .. human(most_time.value)
        )
    end

    if most_sessions then
        record(
            "MOST SESSIONS FOR ONE BOOK",
            most_sessions.title
            .. "\n"
            .. tostring(most_sessions.value)
            .. " sessions"
        )
    end

    if most_revisited then
        record(
            "MOST REVISITED BOOK",
            most_revisited.title
            .. "\n"
            .. tostring(most_revisited.value)
            .. " returns after 7+ day gaps"
        )
    end

    if longest_span and longest_span.value >= 86400 then
        record(
            "LONGEST CALENDAR-SPAN READ",
            longest_span.title
            .. "\n"
            .. span(longest_span.value)
        )
    end

    for _, medium in ipairs({
        "Kindle",
        "Audiobook",
        "External/Hybrid",
    }) do
        local item = medium_best[medium]

        if item then
            record(
                "MOST " .. string.upper(medium) .. " TIME",
                item.title
                .. "\n"
                .. human(item.value)
            )
        end
    end

    -- Most books and most raw sessions represented in one day.
    local day_books = {}
    local day_sessions = {}

    for _, s in ipairs(raw) do
        local day = os.date("%Y-%m-%d", s.start_time)
        day_books[day] = day_books[day] or {}
        day_books[day][normalize(s.title)] = true
        day_sessions[day] = (day_sessions[day] or 0) + 1
    end

    local books_day
    local books_count = 0
    local sessions_day
    local sessions_count = 0

    for day, set in pairs(day_books) do
        local count = 0

        for key in pairs(set) do
            if key ~= "" then
                count = count + 1
            end
        end

        if count > books_count then
            books_count = count
            books_day = day
        end
    end

    for day, count in pairs(day_sessions) do
        if count > sessions_count then
            sessions_count = count
            sessions_day = day
        end
    end

    if books_day and books_count >= 2 then
        record(
            "MOST BOOKS WITH SESSIONS IN ONE DAY",
            books_day
            .. "\n"
            .. tostring(books_count)
            .. " books"
        )
    end

    if sessions_day and sessions_count >= 2 then
        record(
            "MOST SESSIONS IN ONE DAY",
            sessions_day
            .. "\n"
            .. tostring(sessions_count)
            .. " source sessions"
        )
    end

    -- Shortest high-rated Bookmory reading span with enough evidence.
    local quickest_favorite

    for _, book in ipairs(bookmory_books or {}) do
        local rating = latest_rating(book)
        local ss = bookmory_sessions(book)

        if rating and rating >= 4.5 and #ss >= 3 then
            local total = 0

            for _, s in ipairs(ss) do
                total = total + s.duration
            end

            local read_span =
                (ss[#ss].start_time + ss[#ss].duration)
                - ss[1].start_time

            if total >= 3600
                and read_span > 0
                and (
                    not quickest_favorite
                    or read_span < quickest_favorite.value
                ) then

                quickest_favorite = {
                    title = book.title or "Unknown title",
                    value = read_span,
                    rating = rating,
                }
            end
        end
    end

    if quickest_favorite then
        record(
            "FASTEST HIGH-RATED READ",
            quickest_favorite.title
            .. "\n"
            .. span(quickest_favorite.value)
            .. " • "
            .. string.format("%.1f★", quickest_favorite.rating)
        )
    end

    local best_author, best_tag =
        recurring_rating_records(bookmory_books)

    if best_author then
        record(
            "HIGHEST-RATED RECURRING AUTHOR",
            best_author.label
            .. "\n"
            .. string.format(
                "%.2f★ average across %d rated books",
                best_author.avg,
                best_author.count
            )
        )
    end

    if best_tag then
        record(
            "HIGHEST-RATED RECURRING TAG",
            best_tag.label
            .. "\n"
            .. string.format(
                "%.2f★ average across %d rated books",
                best_tag.avg,
                best_tag.count
            )
        )
    end

    return table.concat(lines, "\n")
end

return StatsPatterns
