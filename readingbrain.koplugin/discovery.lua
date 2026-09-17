local NetworkMgr = require("ui/network/manager")
local ltn12 = require("ltn12")
local rapidjson = require("rapidjson")
local socketurl = require("socket.url")
local socketutil = require("socketutil")
local https = require("ssl.https")
<<<<<<< HEAD
local lfs = require("libs/libkoreader-lfs")

local Discovery = {}

local SEARCH_URL = "https://openlibrary.org/search.json"
local CACHE_PATH = "/mnt/us/readingbrain/discovery_cache.json"
=======

local Discovery = {}

local SEARCH_URL =
    "https://openlibrary.org/search.json"
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

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

<<<<<<< HEAD
=======
local function authors_string(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "table" then
        return table.concat(value, ", ")
    end

    return ""
end

>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
local function tags_for(book)
    local tags = {}

    if type(book.tags) == "string" then
        for tag in book.tags:gmatch("#([^#]+)") do
            tag = tag:match("^%s*(.-)%s*$")
<<<<<<< HEAD
=======

>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
            if tag and tag ~= "" then
                table.insert(tags, tag)
            end
        end
    elseif type(book.tags) == "table" then
        for _, tag in ipairs(book.tags) do
<<<<<<< HEAD
            if type(tag) == "string" and tag ~= "" then
=======
            if type(tag) == "string"
                and tag ~= "" then

>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
                table.insert(tags, tag)
            end
        end
    end

    return tags
end

local function latest_rating(book)
<<<<<<< HEAD
    local rating = tonumber(book.last_read_done_star)
=======
    local rating =
        tonumber(book.last_read_done_star)
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

    if rating and rating > 0 then
        return rating
    end

    local reads = book.reads or {}

    for i = #reads, 1, -1 do
<<<<<<< HEAD
        local star = tonumber(reads[i].star)
=======
        local star =
            tonumber(reads[i].star)
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        if star and star > 0 then
            return star
        end
    end

    return nil
end

<<<<<<< HEAD
=======
local function contains_normalized(haystack, needle)
    haystack = normalize(haystack)
    needle = normalize(needle)

    return
        haystack ~= ""
        and needle ~= ""
        and (
            haystack == needle
            or haystack:find(
                needle,
                1,
                true
            ) ~= nil
        )
end

>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
function Discovery:buildProfile(bookmory_books)
    local tag_scores = {}
    local tag_counts = {}
    local author_scores = {}
    local read_titles = {}
    local rated_books = 0

    for _, book in ipairs(bookmory_books or {}) do
<<<<<<< HEAD
        local title = normalize(book.title)
=======
        local title =
            normalize(book.title)
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        if title ~= "" then
            read_titles[title] = true
        end

<<<<<<< HEAD
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
=======
        local rating =
            latest_rating(book)

        if rating then
            rated_books =
                rated_books + 1

            -- 3 stars is neutral. 4/5 add weight; 1/2 subtract it.
            local weight =
                (rating - 3) * 2

            for _, tag in ipairs(
                tags_for(book)
            ) do
                local key =
                    normalize(tag)

                if key ~= "" then
                    tag_scores[key] =
                        (tag_scores[key] or 0)
                        + weight

                    tag_counts[key] =
                        (tag_counts[key] or 0)
                        + 1
                end
            end

            local authors =
                book.authors
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

            if type(authors) ~= "table" then
                authors = {}

<<<<<<< HEAD
                if type(book.author) == "string" and book.author ~= "" then
                    authors = { book.author }
=======
                if type(book.author) == "string"
                    and book.author ~= "" then

                    authors = {
                        book.author,
                    }
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
                end
            end

            for _, author in ipairs(authors) do
<<<<<<< HEAD
                local key = normalize(author)

                if key ~= "" then
                    author_scores[key] = (author_scores[key] or 0) + weight
=======
                local key =
                    normalize(author)

                if key ~= "" then
                    author_scores[key] =
                        (author_scores[key] or 0)
                        + weight
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
                end
            end
        end
    end

    local positive_tags = {}
    local negative_tags = {}

    for tag, score in pairs(tag_scores) do
<<<<<<< HEAD
        local count = tag_counts[tag] or 0
=======
        local count =
            tag_counts[tag]
            or 0
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        if count >= 2 then
            local item = {
                tag = tag,
                score = score,
                count = count,
            }

            if score > 0 then
<<<<<<< HEAD
                table.insert(positive_tags, item)
            elseif score < 0 then
                table.insert(negative_tags, item)
=======
                table.insert(
                    positive_tags,
                    item
                )
            elseif score < 0 then
                table.insert(
                    negative_tags,
                    item
                )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
            end
        end
    end

<<<<<<< HEAD
    table.sort(positive_tags, function(a, b)
        if a.score == b.score then
            return a.count > b.count
        end
        return a.score > b.score
    end)

    table.sort(negative_tags, function(a, b)
        return a.score < b.score
    end)
=======
    table.sort(
        positive_tags,
        function(a, b)
            if a.score == b.score then
                return a.count > b.count
            end

            return a.score > b.score
        end
    )

    table.sort(
        negative_tags,
        function(a, b)
            return a.score < b.score
        end
    )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

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

<<<<<<< HEAD
local function request_json(url)
=======
local function http_json(url)
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
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
<<<<<<< HEAD
            ["Connection"] = "close",
=======
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        },
    }

    socketutil:reset_timeout()

<<<<<<< HEAD
    if not ok or tonumber(code) ~= 200 then
=======
    if not ok
        or tonumber(code) ~= 200 then

>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        return nil,
            "HTTP "
            .. tostring(code or "?")
            .. ": "
            .. tostring(status or "request failed")
    end

<<<<<<< HEAD
    local parsed_ok, data = pcall(
        rapidjson.decode,
        table.concat(sink)
    )

    if not parsed_ok or type(data) ~= "table" then
        return nil, "Could not parse Open Library response."
=======
    local parsed_ok, data =
        pcall(
            rapidjson.decode,
            table.concat(sink)
        )

    if not parsed_ok
        or type(data) ~= "table" then

        return nil,
            "Could not parse Open Library response."
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
    end

    return data
end

<<<<<<< HEAD
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
=======
function Discovery:fetchCandidates(profile)
    if not NetworkMgr:isOnline() then
        return nil,
            "Wi-Fi is not connected."
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
    end

    local subjects = {}

<<<<<<< HEAD
    for i = 1, math.min(2, #profile.positive_tags) do
        table.insert(subjects, profile.positive_tags[i].tag)
=======
    for i = 1,
        math.min(
            5,
            #profile.positive_tags
        ) do

        table.insert(
            subjects,
            profile.positive_tags[i].tag
        )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
    end

    if #subjects == 0 then
        subjects = {
            "fantasy",
            "historical fiction",
<<<<<<< HEAD
=======
            "romance",
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        }
    end

    local candidates = {}
    local seen = {}
<<<<<<< HEAD
    local last_err
=======
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

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
<<<<<<< HEAD
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
=======
            .. "&limit=18"

        local data, err =
            http_json(url)

        if not data then
            return nil, err
        end

        for _, doc in ipairs(
            data.docs or {}
        ) do
            local key =
                doc.key
                or normalize(doc.title)

            local normalized_title =
                normalize(doc.title)

            if normalized_title ~= ""
                and not profile.read_titles[
                    normalized_title
                ]
                and not seen[key] then

                seen[key] = true

                table.insert(
                    candidates,
                    {
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
                        key = doc.key,
                        title = doc.title,
                        authors = doc.author_name or {},
                        year = doc.first_publish_year,
                        subjects = doc.subject or {},
<<<<<<< HEAD
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
=======
                    }
                )
            end
        end
    end

    return candidates
end

function Discovery:excludeOwned(
    candidates,
    kindle_books
)
    local owned = {}

    for _, book in ipairs(
        kindle_books or {}
    ) do
        owned[
            normalize(book.title)
        ] = true
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
    end

    local result = {}

<<<<<<< HEAD
    for _, candidate in ipairs(candidates or {}) do
        if not owned[normalize(candidate.title)] then
            table.insert(result, candidate)
=======
    for _, candidate in ipairs(
        candidates or {}
    ) do
        if not owned[
            normalize(candidate.title)
        ] then

            table.insert(
                result,
                candidate
            )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        end
    end

    return result
end

<<<<<<< HEAD
function Discovery:scoreCandidates(profile, candidates)
    local scored = {}

    for _, candidate in ipairs(candidates or {}) do
=======
function Discovery:scoreCandidates(
    profile,
    candidates
)
    local scored = {}

    for _, candidate in ipairs(
        candidates or {}
    ) do
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        local score = 0
        local reasons = {}
        local matched_tags = {}

<<<<<<< HEAD
        for _, subject in ipairs(candidate.subjects or {}) do
            local key = normalize(subject)
            local weight = profile.tag_scores[key]
=======
        for _, subject in ipairs(
            candidate.subjects or {}
        ) do
            local key =
                normalize(subject)

            local weight =
                profile.tag_scores[key]
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

            if weight then
                score = score + weight

<<<<<<< HEAD
                if weight >= 2 and #matched_tags < 3 then
                    table.insert(matched_tags, subject)
=======
                if weight >= 2
                    and #matched_tags < 3 then

                    table.insert(
                        matched_tags,
                        subject
                    )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
                end
            end
        end

        local author_bonus = 0

<<<<<<< HEAD
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
=======
        for _, author in ipairs(
            candidate.authors or {}
        ) do
            local a =
                normalize(author)

            local weight =
                profile.author_scores[a]

            if weight and weight > 0 then
                author_bonus =
                    math.max(
                        author_bonus,
                        weight * 0.5
                    )
            end
        end

        score =
            score
            + author_bonus
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        if #matched_tags > 0 then
            table.insert(
                reasons,
                "Matches: "
<<<<<<< HEAD
                .. table.concat(matched_tags, ", ")
=======
                .. table.concat(
                    matched_tags,
                    ", "
                )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
            )
        end

        if author_bonus > 0 then
            table.insert(
                reasons,
                "Author you've rated well"
            )
<<<<<<< HEAD
        else
=======
        end

        -- Slight novelty bonus for an unfamiliar author.
        if author_bonus == 0 then
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
            score = score + 0.5
        end

        candidate.score = score
        candidate.reasons = reasons

<<<<<<< HEAD
        table.insert(scored, candidate)
    end

    table.sort(scored, function(a, b)
        if a.score == b.score then
            return (a.title or "") < (b.title or "")
        end

        return a.score > b.score
    end)
=======
        table.insert(
            scored,
            candidate
        )
    end

    table.sort(
        scored,
        function(a, b)
            if a.score == b.score then
                return
                    (a.title or "")
                    <
                    (b.title or "")
            end

            return a.score > b.score
        end
    )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

    return scored
end

<<<<<<< HEAD
function Discovery:recommend(bookmory_books, kindle_books, count)
    local profile = self:buildProfile(bookmory_books)

    local candidates, err, used_cache =
        self:fetchCandidates(profile)
=======
function Discovery:recommend(
    bookmory_books,
    kindle_books,
    count
)
    local profile =
        self:buildProfile(
            bookmory_books
        )

    local candidates, err =
        self:fetchCandidates(
            profile
        )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

    if not candidates then
        return nil, err, profile
    end

<<<<<<< HEAD
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
=======
    candidates =
        self:excludeOwned(
            candidates,
            kindle_books
        )

    local scored =
        self:scoreCandidates(
            profile,
            candidates
        )

    local result = {}

    for i = 1,
        math.min(
            count or 5,
            #scored
        ) do

        table.insert(
            result,
            scored[i]
        )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
    end

    return result, nil, profile
end

function Discovery:profileText(profile)
    local lines = {
        "TASTE PROFILE",
        "",
<<<<<<< HEAD
        "Rated books: " .. tostring(profile.rated_books or 0),
=======
        "Rated books: "
            .. tostring(
                profile.rated_books
                or 0
            ),
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
        "",
        "STRONG POSITIVE",
    }

<<<<<<< HEAD
    for i = 1, math.min(8, #profile.positive_tags) do
        local item = profile.positive_tags[i]
=======
    for i = 1,
        math.min(
            8,
            #profile.positive_tags
        ) do

        local item =
            profile.positive_tags[i]
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        table.insert(
            lines,
            "• "
            .. item.tag
            .. "  +"
<<<<<<< HEAD
            .. string.format("%.0f", item.score)
        )
    end

    table.insert(lines, "")
    table.insert(lines, "NEGATIVE TENDENCY")

    for i = 1, math.min(6, #profile.negative_tags) do
        local item = profile.negative_tags[i]
=======
            .. string.format(
                "%.0f",
                item.score
            )
        )
    end

    table.insert(
        lines,
        ""
    )

    table.insert(
        lines,
        "NEGATIVE TENDENCY"
    )

    for i = 1,
        math.min(
            6,
            #profile.negative_tags
        ) do

        local item =
            profile.negative_tags[i]
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef

        table.insert(
            lines,
            "• "
            .. item.tag
            .. "  "
<<<<<<< HEAD
            .. string.format("%.0f", item.score)
        )
    end

    return table.concat(lines, "\n")
=======
            .. string.format(
                "%.0f",
                item.score
            )
        )
    end

    return table.concat(
        lines,
        "\n"
    )
>>>>>>> bc9c6802435641f0095d2b252f628b341e0b0eef
end

return Discovery
