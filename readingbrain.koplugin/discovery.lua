local NetworkMgr = require("ui/network/manager")
local ltn12 = require("ltn12")
local rapidjson = require("rapidjson")
local socketurl = require("socket.url")
local socketutil = require("socketutil")
local https = require("ssl.https")
local lfs = require("libs/libkoreader-lfs")

local Discovery = {}

local SEARCH_URL = "https://openlibrary.org/search.json"
local CACHE_PATH = "/mnt/us/readingbrain/discovery_cache.json"

local function normalize(value)
    if type(value) ~= "string" then
        return ""
    end

    value = value:lower()
    value = value:gsub("&", " and ")
    value = value:gsub("[^%w%s]", " ")
    value = value:gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""

    return value
end

local function tags_for(book)
    local tags = {}

    if type(book.tags) == "string" then
        for tag in book.tags:gmatch("#([^#]+)") do
            tag = tag:match("^%s*(.-)%s*$")
            if tag and tag ~= "" then
                table.insert(tags, tag)
            end
        end
    elseif type(book.tags) == "table" then
        for _, tag in ipairs(book.tags) do
            if type(tag) == "string" and tag ~= "" then
                table.insert(tags, tag)
            end
        end
    end

    return tags
end

local function latest_rating(book)
    local rating = tonumber(book.last_read_done_star)

    if rating and rating > 0 then
        return rating
    end

    local reads = book.reads or {}

    for i = #reads, 1, -1 do
        local star = tonumber(reads[i].star)

        if star and star > 0 then
            return star
        end
    end

    return nil
end

function Discovery:buildProfile(bookmory_books)
    local tag_scores = {}
    local tag_counts = {}
    local author_scores = {}
    local read_titles = {}
    local rated_books = 0

    for _, book in ipairs(bookmory_books or {}) do
        local title = normalize(book.title)

        if title ~= "" then
            read_titles[title] = true
        end

        local rating = latest_rating(book)

        if rating then
            rated_books = rated_books + 1
            local weight = (rating - 3) * 2

            for _, tag in ipairs(tags_for(book)) do
                local key = normalize(tag)

                if key ~= "" then
                    tag_scores[key] = (tag_scores[key] or 0) + weight
                    tag_counts[key] = (tag_counts[key] or 0) + 1
                end
            end

            local authors = book.authors

            if type(authors) ~= "table" then
                authors = {}

                if type(book.author) == "string" and book.author ~= "" then
                    authors = { book.author }
                end
            end

            for _, author in ipairs(authors) do
                local key = normalize(author)

                if key ~= "" then
                    author_scores[key] = (author_scores[key] or 0) + weight
                end
            end
        end
    end

    local positive_tags = {}
    local negative_tags = {}

    for tag, score in pairs(tag_scores) do
        local count = tag_counts[tag] or 0

        if count >= 2 then
            local item = {
                tag = tag,
                score = score,
                count = count,
            }

            if score > 0 then
                table.insert(positive_tags, item)
            elseif score < 0 then
                table.insert(negative_tags, item)
            end
        end
    end

    table.sort(positive_tags, function(a, b)
        if a.score == b.score then
            return a.count > b.count
        end
        return a.score > b.score
    end)

    table.sort(negative_tags, function(a, b)
        return a.score < b.score
    end)

    return {
        rated_books = rated_books,
        tag_scores = tag_scores,
        tag_counts = tag_counts,
        author_scores = author_scores,
        positive_tags = positive_tags,
        negative_tags = negative_tags,
        read_titles = read_titles,
    }
end

local function request_json(url)
    local sink = {}

    socketutil:set_timeout(
        socketutil.LARGE_BLOCK_TIMEOUT,
        socketutil.LARGE_TOTAL_TIMEOUT
    )

    local ok, code, _, status = https.request{
        url = url,
        method = "GET",
        sink = ltn12.sink.table(sink),
        headers = {
            ["User-Agent"] = "KOReader-ReadingBrain-Discovery",
            ["Accept"] = "application/json",
            ["Connection"] = "close",
        },
    }

    socketutil:reset_timeout()

    if not ok or tonumber(code) ~= 200 then
        return nil,
            "HTTP "
            .. tostring(code or "?")
            .. ": "
            .. tostring(status or "request failed")
    end

    local parsed_ok, data = pcall(
        rapidjson.decode,
        table.concat(sink)
    )

    if not parsed_ok or type(data) ~= "table" then
        return nil, "Could not parse Open Library response."
    end

    return data
end

local function http_json_with_retry(url)
    local data, err = request_json(url)

    if data then
        return data
    end

    -- One retry is enough. More retries are unpleasant on e-ink and
    -- can make a temporary network issue look like a frozen Kindle.
    return request_json(url)
end

local function save_cache(candidates)
    local ok, encoded = pcall(
        rapidjson.encode,
        {
            saved_at = os.time(),
            candidates = candidates,
        }
    )

    if not ok or not encoded then
        return
    end

    local f = io.open(CACHE_PATH, "w")

    if f then
        f:write(encoded)
        f:close()
    end
end

local function load_cache()
    local a = lfs.attributes(CACHE_PATH)

    if not a or a.mode ~= "file" then
        return nil
    end

    local f = io.open(CACHE_PATH, "r")

    if not f then
        return nil
    end

    local body = f:read("*a")
    f:close()

    local ok, decoded = pcall(
        rapidjson.decode,
        body
    )

    if not ok or type(decoded) ~= "table"
        or type(decoded.candidates) ~= "table" then

        return nil
    end

    return decoded.candidates
end

function Discovery:fetchCandidates(profile)
    if not NetworkMgr:isOnline() then
        local cached = load_cache()

        if cached then
            return cached, nil, true
        end

        return nil, "Wi-Fi is not connected."
    end

    local subjects = {}

    for i = 1, math.min(2, #profile.positive_tags) do
        table.insert(subjects, profile.positive_tags[i].tag)
    end

    if #subjects == 0 then
        subjects = {
            "fantasy",
            "historical fiction",
        }
    end

    local candidates = {}
    local seen = {}
    local last_err

    for _, subject in ipairs(subjects) do
        local query =
            'subject:"'
            .. subject
            .. '" language:eng'

        local url =
            SEARCH_URL
            .. "?q="
            .. socketurl.escape(query)
            .. "&fields=key,title,author_name,first_publish_year,subject"
            .. "&limit=25"

        local data, err = http_json_with_retry(url)

        if data then
            for _, doc in ipairs(data.docs or {}) do
                local key = doc.key or normalize(doc.title)
                local normalized_title = normalize(doc.title)

                if normalized_title ~= ""
                    and not profile.read_titles[normalized_title]
                    and not seen[key] then

                    seen[key] = true

                    table.insert(candidates, {
                        key = doc.key,
                        title = doc.title,
                        authors = doc.author_name or {},
                        year = doc.first_publish_year,
                        subjects = doc.subject or {},
                    })
                end
            end
        else
            -- Do not fail the whole discovery run just because one
            -- Open Library query timed out.
            last_err = err
        end
    end

    if #candidates > 0 then
        save_cache(candidates)
        return candidates, nil, false
    end

    local cached = load_cache()

    if cached then
        return cached, nil, true
    end

    return nil, last_err or "Open Library did not return any books."
end

function Discovery:excludeOwned(candidates, kindle_books)
    local owned = {}

    for _, book in ipairs(kindle_books or {}) do
        owned[normalize(book.title)] = true
    end

    local result = {}

    for _, candidate in ipairs(candidates or {}) do
        if not owned[normalize(candidate.title)] then
            table.insert(result, candidate)
        end
    end

    return result
end

function Discovery:scoreCandidates(profile, candidates)
    local scored = {}

    for _, candidate in ipairs(candidates or {}) do
        local score = 0
        local reasons = {}
        local matched_tags = {}

        for _, subject in ipairs(candidate.subjects or {}) do
            local key = normalize(subject)
            local weight = profile.tag_scores[key]

            if weight then
                score = score + weight

                if weight >= 2 and #matched_tags < 3 then
                    table.insert(matched_tags, subject)
                end
            end
        end

        local author_bonus = 0

        for _, author in ipairs(candidate.authors or {}) do
            local weight = profile.author_scores[normalize(author)]

            if weight and weight > 0 then
                author_bonus = math.max(
                    author_bonus,
                    weight * 0.5
                )
            end
        end

        score = score + author_bonus

        if #matched_tags > 0 then
            table.insert(
                reasons,
                "Matches: "
                .. table.concat(matched_tags, ", ")
            )
        end

        if author_bonus > 0 then
            table.insert(
                reasons,
                "Author you've rated well"
            )
        else
            score = score + 0.5
        end

        candidate.score = score
        candidate.reasons = reasons

        table.insert(scored, candidate)
    end

    table.sort(scored, function(a, b)
        if a.score == b.score then
            return (a.title or "") < (b.title or "")
        end

        return a.score > b.score
    end)

    return scored
end

function Discovery:recommend(bookmory_books, kindle_books, count)
    local profile = self:buildProfile(bookmory_books)

    local candidates, err, used_cache =
        self:fetchCandidates(profile)

    if not candidates then
        return nil, err, profile
    end

    candidates = self:excludeOwned(
        candidates,
        kindle_books
    )

    local scored = self:scoreCandidates(
        profile,
        candidates
    )

    local result = {}

    for i = 1, math.min(count or 5, #scored) do
        local item = scored[i]
        item.used_cache = used_cache and true or false
        table.insert(result, item)
    end

    return result, nil, profile
end

function Discovery:profileText(profile)
    local lines = {
        "TASTE PROFILE",
        "",
        "Rated books: " .. tostring(profile.rated_books or 0),
        "",
        "STRONG POSITIVE",
    }

    for i = 1, math.min(8, #profile.positive_tags) do
        local item = profile.positive_tags[i]

        table.insert(
            lines,
            "• "
            .. item.tag
            .. "  +"
            .. string.format("%.0f", item.score)
        )
    end

    table.insert(lines, "")
    table.insert(lines, "NEGATIVE TENDENCY")

    for i = 1, math.min(6, #profile.negative_tags) do
        local item = profile.negative_tags[i]

        table.insert(
            lines,
            "• "
            .. item.tag
            .. "  "
            .. string.format("%.0f", item.score)
        )
    end

    return table.concat(lines, "\n")
end

return Discovery
