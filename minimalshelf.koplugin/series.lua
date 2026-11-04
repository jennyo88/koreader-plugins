-- Pure Lua sorting/classification. No IO or network calls.
local Series = {}

local function by_title(a, b)
    return (a.title or ""):lower() < (b.title or ""):lower()
end

local function by_series_number(a, b)
    local ai, bi = tonumber(a.series_index), tonumber(b.series_index)
    if ai and bi and ai ~= bi then return ai < bi end
    if ai and not bi then return true end
    if bi and not ai then return false end
    return by_title(a, b)
end

function Series.group(books)
    local lookup, result = {}, {}
    for _, book in ipairs(books or {}) do
        if type(book.series) == "string" and book.series:match("%S") then
            local name = book.series
            if not lookup[name] then
                local group = { name = name, books = {} }
                lookup[name] = group
                result[#result + 1] = group
            end
            local group = lookup[name]
            group.books[#group.books + 1] = book
        end
    end
    for _, group in ipairs(result) do
        table.sort(group.books, by_series_number)
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

-- A recommendation is the first unfinished volume of a series. Do not silently
-- recommend volume 4 after volume 2 if numbered volume 3 is absent locally.
-- Fractional numbering (2.5) is preserved; missing integer gaps are reported.
function Series.next(books)
    local results = {}
    for _, group in ipairs(Series.group(books)) do
        local first_unfinished
        local previous_integer
        local missing
        for _, book in ipairs(group.books) do
            local idx = tonumber(book.series_index)
            if idx and idx >= 1 and idx % 1 == 0 then
                if previous_integer and idx > previous_integer + 1 then
                    missing = previous_integer + 1
                elseif not previous_integer and idx > 1 then
                    missing = 1
                end
                previous_integer = idx
            end
            if book.status ~= "complete" then
                first_unfinished = book
                break
            end
        end
        if first_unfinished then
            results[#results + 1] = {
                group = group.name,
                book = first_unfinished,
                missing = missing,
            }
        end
    end
    table.sort(results, function(a, b) return a.group:lower() < b.group:lower() end)
    return results
end

function Series.short(books, max_pages, remaining_mode)
    local result = {}
    for _, book in ipairs(books or {}) do
        local pages = remaining_mode and book.remaining or book.total_pages
        if book.status ~= "complete" and type(pages) == "number"
            and pages > 0 and pages <= max_pages then
            result[#result + 1] = book
        end
    end
    table.sort(result, function(a, b)
        local x = (remaining_mode and a.remaining or a.total_pages) or math.huge
        local y = (remaining_mode and b.remaining or b.total_pages) or math.huge
        if x == y then return by_title(a, b) end
        return x < y
    end)
    return result
end

function Series.badge(book)
    local labels = {}
    if tonumber(book.series_index) then
        labels[#labels + 1] = "#" .. string.format("%g", book.series_index)
    end
    if book.total_pages then
        local approx = book.page_source == "calibre" and "~" or ""
        local source = book.page_source == "calibre" and " (Calibre)" or ""
        if book.status == "complete" then
            labels[#labels + 1] = "Read"
        elseif book.remaining ~= nil then
            labels[#labels + 1] = string.format("%s%d left%s", approx, book.remaining, source)
        else
            labels[#labels + 1] = string.format("%s%d pp%s", approx, book.total_pages, source)
        end
    else
        labels[#labels + 1] = "pages ?"
    end
    return table.concat(labels, "  |  ")
end

return Series
