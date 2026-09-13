local DocSettings = require("docsettings")
local lfs = require("libs/libkoreader-lfs")

local Library = {}

local ROOT = "/mnt/us/koreader/books"

local function basename(path)
    return path:match("([^/]+)$") or path
end

local function dirname(path)
    return path:match("^(.*)/[^/]+$")
end

function Library:normalize(value)
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

function Library:authorString(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "table" then
        return table.concat(value, " ")
    end

    return ""
end

local function scan(path, results)
    results = results or {}

    local attr = lfs.attributes(path)
    if not attr or attr.mode ~= "directory" then
        return results
    end

    for name in lfs.dir(path) do
        if name ~= "." and name ~= ".." then
            local full = path .. "/" .. name
            local a = lfs.attributes(full)

            if a then
                if a.mode == "directory" then
                    if name:sub(1, 1) ~= "."
                        and not name:match("%.sdr$") then
                        scan(full, results)
                    end
                elseif a.mode == "file"
                    and name:lower():match("%.epub$") then
                    table.insert(results, full)
                end
            end
        end
    end

    return results
end

function Library:getBooks()
    local books = {}

    for _, file in ipairs(scan(ROOT)) do
        local item = {
            file = file,
            filename = basename(file),
            directory = dirname(file),
        }

        local ok, settings = pcall(function()
            return DocSettings:open(file)
        end)

        if ok and settings then
            local props = settings:readSetting("doc_props") or {}

            item.title = props.title
            item.authors = props.authors
            item.identifiers = props.identifiers
            item.series = props.series
            item.series_index = props.series_index
            item.percent_finished = settings:readSetting("percent_finished")
            item.status = (settings:readSetting("summary") or {}).status
        end

        if not item.title or item.title == "" then
            item.title = item.filename:gsub("%.[Ee][Pp][Uu][Bb]$", "")
        end

        item.normalized_title = self:normalize(item.title)
        item.normalized_authors = self:normalize(self:authorString(item.authors))

        table.insert(books, item)
    end

    return books
end

function Library:canonicalKey(title, authors)
    local t = self:normalize(title)
    local a = self:normalize(self:authorString(authors))

    if t == "" then
        return nil
    end

    return t .. "\0" .. a
end

function Library:buildTitleIndex(kindle_books)
    local index = {}

    for _, book in ipairs(kindle_books or {}) do
        local key = book.normalized_title

        if key ~= "" then
            index[key] = index[key] or {}
            table.insert(index[key], book)
        end
    end

    return index
end

function Library:matchOne(title, authors, kindle_books, title_index)
    title_index = title_index or self:buildTitleIndex(kindle_books)

    local nt = self:normalize(title)
    local na = self:normalize(self:authorString(authors))
    local candidates = title_index[nt] or {}

    if #candidates == 0 then
        return nil, "unmatched"
    end

    if #candidates == 1 then
        local candidate = candidates[1]
        local ca = candidate.normalized_authors or ""

        if na == ""
            or ca == ""
            or na == ca
            or ca:find(na, 1, true)
            or na:find(ca, 1, true) then
            return candidate, "matched"
        end

        return nil, "unmatched"
    end

    local matches = {}

    for _, candidate in ipairs(candidates) do
        local ca = candidate.normalized_authors or ""

        if na ~= ""
            and ca ~= ""
            and (
                na == ca
                or ca:find(na, 1, true)
                or na:find(ca, 1, true)
            ) then
            table.insert(matches, candidate)
        end
    end

    if #matches == 1 then
        return matches[1], "matched"
    end

    return nil, "ambiguous"
end

function Library:matchBookmory(bookmory_books, kindle_books)
    local title_index = self:buildTitleIndex(kindle_books)

    local summary = {
        matched = 0,
        ambiguous = 0,
        unmatched = 0,
    }

    local examples = {
        matched = {},
        ambiguous = {},
        unmatched = {},
    }

    for _, b in ipairs(bookmory_books or {}) do
        local _, status = self:matchOne(
            b.title,
            b.authors,
            kindle_books,
            title_index
        )

        summary[status] = summary[status] + 1

        if #examples[status] < 5 then
            table.insert(examples[status], b.title or "Untitled")
        end
    end

    return summary, examples
end

return Library
