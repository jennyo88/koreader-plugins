local json = require("json")

local Discovery = {}

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

local function tags(book)
    local out = {}

    if type(book.tags) == "string" then
        for tag in book.tags:gmatch("#([^#]+)") do
            tag =
                tag:lower()
                    :match("^%s*(.-)%s*$")

            if tag and tag ~= "" then
                table.insert(out, tag)
            end
        end
    end

    return out
end

function Discovery:buildProfile(books)
    local weights = {}
    local rated = 0

    for _, book in ipairs(books or {}) do
        local r = rating(book)

        if r then
            rated = rated + 1
            local weight = (r - 3) * 2

            for _, tag in ipairs(tags(book)) do
                weights[tag] =
                    (weights[tag] or 0)
                    + weight
            end
        end
    end

    return {
        rated = rated,
        weights = weights,
    }
end

function Discovery:profileText(profile)
    local list = {}

    for tag, score in pairs(profile.weights or {}) do
        table.insert(
            list,
            {
                tag = tag,
                score = score,
            }
        )
    end

    table.sort(
        list,
        function(a, b)
            return a.score > b.score
        end
    )

    local out = {
        "Rated books ........ "
            .. tostring(profile.rated or 0),
        "",
        "STRONGEST POSITIVE SIGNALS",
    }

    for i = 1, math.min(10, #list) do
        if list[i].score > 0 then
            table.insert(
                out,
                list[i].tag
                .. " ........ "
                .. string.format("%.1f", list[i].score)
            )
        end
    end

    return table.concat(out, "\n")
end

local function norm(s)
    s = tostring(s or ""):lower()
    s = s:gsub("[^%w%s]", " ")
    s = s:gsub("%s+", " ")
    return s:match("^%s*(.-)%s*$") or ""
end

function Discovery:recommend(bookmory_books, kindle_books, limit)
    -- Stable recovery behavior: use Open Library only when socket.http is available.
    local ok_http, http = pcall(require, "socket.http")
    local ok_url, url = pcall(require, "socket.url")

    if not ok_http or not ok_url then
        return nil, "Online discovery is unavailable on this KOReader build."
    end

    local profile = self:buildProfile(bookmory_books)

    local ranked = {}
    for tag, score in pairs(profile.weights or {}) do
        if score > 0 then
            table.insert(
                ranked,
                {
                    tag = tag,
                    score = score,
                }
            )
        end
    end

    table.sort(
        ranked,
        function(a, b)
            return a.score > b.score
        end
    )

    if #ranked == 0 then
        return {}, nil
    end

    local owned = {}
    for _, book in ipairs(bookmory_books or {}) do
        owned[norm(book.title)] = true
    end
    for _, book in ipairs(kindle_books or {}) do
        owned[norm(book.title)] = true
    end

    local candidates = {}
    local seen = {}

    for i = 1, math.min(2, #ranked) do
        local tag = ranked[i].tag
        local query =
            "https://openlibrary.org/search.json?limit=20&subject="
            .. url.escape(tag)

        http.TIMEOUT = 8
        local body, code = http.request(query)

        if tonumber(code) == 200 and body then
            local ok, data = pcall(json.decode, body)

            if ok and type(data) == "table" then
                for _, doc in ipairs(data.docs or {}) do
                    local title = doc.title

                    if title
                        and not owned[norm(title)]
                        and not seen[norm(title)] then

                        seen[norm(title)] = true

                        table.insert(
                            candidates,
                            {
                                title = title,
                                authors = doc.author_name or {},
                                year = doc.first_publish_year,
                                key = doc.key,
                                score = ranked[i].score,
                                reasons = {
                                    "Matches your positive Bookmory tag: "
                                    .. tag,
                                },
                                used_cache = false,
                            }
                        )
                    end
                end
            end
        end
    end

    table.sort(
        candidates,
        function(a, b)
            return (a.score or 0) > (b.score or 0)
        end
    )

    local out = {}
    for i = 1, math.min(limit or 5, #candidates) do
        table.insert(out, candidates[i])
    end

    return out
end

return Discovery
