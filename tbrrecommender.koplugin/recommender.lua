local Recommender = {}

math.randomseed(os.time())

local function copy(list)
    local out = {}

    for i, value in ipairs(list or {}) do
        out[i] = value
    end

    return out
end

local function shuffle(list)
    local out = copy(list)

    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end

    return out
end

local function first_n(list, count)
    local out = {}

    for i = 1, math.min(count or 3, #list) do
        out[i] = list[i]
    end

    return out
end

local function normalize_series_name(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = name:match("^%s*(.-)%s*$")

    if normalized == "" then
        return nil
    end

    return normalized
end

local function normalize_author(author)
    if type(author) == "string" then
        return author:lower()
    elseif type(author) == "table" then
        return table.concat(author, ", "):lower()
    end

    return nil
end

local function series_index_value(book)
    local value = tonumber(book.series_index)

    if value then
        return value
    end

    return math.huge
end

local function progress_percent(book)
    local p = tonumber(book.percent_finished)

    if not p then
        return nil
    end

    if p <= 1 then
        p = p * 100
    end

    return p
end

function Recommender:surpriseMe(books, count)
    return first_n(
        shuffle(books),
        count or 3
    )
end

function Recommender:quickRead(books, count)
    local known = {}
    local unknown = {}

    for _, book in ipairs(books or {}) do
        if type(book.pages) == "number"
            and book.pages > 0 then

            table.insert(
                known,
                book
            )
        else
            table.insert(
                unknown,
                book
            )
        end
    end

    table.sort(
        known,
        function(a, b)
            if a.pages == b.pages then
                return
                    (a.title or a.filename or "")
                    <
                    (b.title or b.filename or "")
            end

            return a.pages < b.pages
        end
    )

    local pool = {}
    local short_limit =
        math.min(
            #known,
            10
        )

    local short = {}

    for i = 1, short_limit do
        table.insert(
            short,
            known[i]
        )
    end

    short = shuffle(short)

    for _, book in ipairs(short) do
        book.recommendation_note =
            "Shorter read"

        table.insert(
            pool,
            book
        )
    end

    if #pool < (count or 3) then
        for _, book in ipairs(
            shuffle(unknown)
        ) do
            table.insert(
                pool,
                book
            )
        end
    end

    return first_n(
        pool,
        count or 3
    )
end

-- For each series, only the earliest unfinished volume is eligible.
function Recommender:continueSeries(all_books, count)
    local grouped = {}

    for _, book in ipairs(all_books or {}) do
        local series =
            normalize_series_name(
                book.series
            )

        if series then
            if not grouped[series] then
                grouped[series] = {}
            end

            table.insert(
                grouped[series],
                book
            )
        end
    end

    local eligible = {}

    for series_name, books in pairs(grouped) do
        table.sort(
            books,
            function(a, b)
                local ai =
                    series_index_value(a)

                local bi =
                    series_index_value(b)

                if ai == bi then
                    return
                        (a.title or a.filename or "")
                        <
                        (b.title or b.filename or "")
                end

                return ai < bi
            end
        )

        for _, book in ipairs(books) do
            if book.status ~= "complete" then
                book.recommendation_note =
                    "Next unread volume"

                book.recommendation_series =
                    series_name

                table.insert(
                    eligible,
                    book
                )

                break
            end
        end
    end

    return first_n(
        shuffle(eligible),
        count or 3
    )
end

function Recommender:unopened(books, count)
    local unopened = {}

    for _, book in ipairs(books or {}) do
        if not book.been_opened then
            book.recommendation_note =
                "Never opened"

            table.insert(
                unopened,
                book
            )
        end
    end

    return first_n(
        shuffle(unopened),
        count or 3
    )
end

-- Books with real reading progress but not complete.
function Recommender:continueStarted(books, count)
    local started = {}

    for _, book in ipairs(books or {}) do
        local progress =
            progress_percent(book)

        if book.been_opened
            and book.status ~= "complete"
            and progress
            and progress > 0
            and progress < 100 then

            book.recommendation_note =
                string.format(
                    "Continue at %.0f%%",
                    progress
                )

            table.insert(
                started,
                book
            )
        end
    end

    -- Prefer books with the most progress so finishing one feels achievable.
    table.sort(
        started,
        function(a, b)
            return
                (progress_percent(a) or 0)
                >
                (progress_percent(b) or 0)
        end
    )

    return first_n(
        started,
        count or 3
    )
end

-- Try to offer books that are unlike what the reader already has in progress.
-- We avoid authors and series represented among currently-started books.
function Recommender:somethingDifferent(books, count)
    local active_authors = {}
    local active_series = {}

    for _, book in ipairs(books or {}) do
        local progress =
            progress_percent(book)

        if book.been_opened
            and book.status ~= "complete"
            and progress
            and progress > 0
            and progress < 100 then

            local author =
                normalize_author(
                    book.authors
                )

            if author then
                active_authors[author] =
                    true
            end

            local series =
                normalize_series_name(
                    book.series
                )

            if series then
                active_series[
                    series:lower()
                ] = true
            end
        end
    end

    local different = {}

    for _, book in ipairs(books or {}) do
        if not book.been_opened then
            local author =
                normalize_author(
                    book.authors
                )

            local series =
                normalize_series_name(
                    book.series
                )

            local same_author =
                author
                and active_authors[author]

            local same_series =
                series
                and active_series[
                    series:lower()
                ]

            if not same_author
                and not same_series then

                book.recommendation_note =
                    "Something different"

                table.insert(
                    different,
                    book
                )
            end
        end
    end

    -- If metadata is sparse, fall back to unopened books.
    if #different == 0 then
        return self:unopened(
            books,
            count
        )
    end

    return first_n(
        shuffle(different),
        count or 3
    )
end

-- A gentler short-read mode:
-- prefer unopened books among the shorter half of known page counts.
function Recommender:shortAndEasy(books, count)
    local candidates = {}

    for _, book in ipairs(books or {}) do
        if not book.been_opened
            and type(book.pages) == "number"
            and book.pages > 0 then

            table.insert(
                candidates,
                book
            )
        end
    end

    -- If KOReader does not know the page counts
    -- for any unopened books, fall back safely
    -- to Quick Read.
    if #candidates == 0 then

        return self:quickRead(
            books,
            count
        )
    end

    table.sort(
        candidates,
        function(a, b)
            return a.pages < b.pages
        end
    )

    local half =
        math.max(
            1,
            math.ceil(#candidates / 2)
        )

    local shorter = {}

    for i = 1, half do

        local book =
            candidates[i]

        if book then

            book.recommendation_note =
                "Short & easy pick"

            table.insert(
                shorter,
                book
            )
        end
    end

    return first_n(
        shuffle(shorter),
        count or 3
    )
end

return Recommender
