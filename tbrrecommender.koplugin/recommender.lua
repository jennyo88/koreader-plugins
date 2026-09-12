local Recommender = {}

math.randomseed(os.time())

local function copy(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
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

local function first_n(list, n)
    local out = {}
    for i = 1, math.min(n or 3, #list) do out[i] = list[i] end
    return out
end

function Recommender:surpriseMe(books, count)
    return first_n(shuffle(books), count or 3)
end

function Recommender:quickRead(books, count)
    local known, unknown = {}, {}

    for _, book in ipairs(books or {}) do
        if type(book.pages) == "number" and book.pages > 0 then
            table.insert(known, book)
        else
            table.insert(unknown, book)
        end
    end

    table.sort(known, function(a, b)
        return a.pages < b.pages
    end)

    local pool = {}
    for i = 1, math.min(10, #known) do
        table.insert(pool, known[i])
    end

    pool = shuffle(pool)

    if #pool < (count or 3) then
        for _, book in ipairs(shuffle(unknown)) do
            table.insert(pool, book)
        end
    end

    return first_n(pool, count or 3)
end

function Recommender:continueSeries(books, count)
    local series_books = {}

    for _, book in ipairs(books or {}) do
        if book.series and book.series ~= "" then
            table.insert(series_books, book)
        end
    end

    return first_n(shuffle(series_books), count or 3)
end

function Recommender:unopened(books, count)
    local unopened = {}

    for _, book in ipairs(books or {}) do
        if not book.been_opened then
            table.insert(unopened, book)
        end
    end

    return first_n(shuffle(unopened), count or 3)
end

return Recommender
