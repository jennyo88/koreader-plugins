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

local function series_index_value(book)
    local value = tonumber(book.series_index)

    if value then
        return value
    end

    -- Books without a usable series index sort after indexed volumes.
    return math.huge
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

    short =
        shuffle(short)

    for _, book in ipairs(short) do
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

-- all_books must include completed books.
--
-- For each series, this selects only the earliest volume that is not
-- marked complete. This prevents later volumes from being recommended
-- while an earlier owned volume is still unread or unfinished.
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

        -- Only the earliest unfinished volume in this series is eligible.
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

return Recommender
