local lfs = require("libs/libkoreader-lfs")

local Library = {}
local ROOT = "/mnt/us/koreader/books"

local function trim(s)
    s = tostring(s or "")
    return s:match("^%s*(.-)%s*$") or ""
end

local function normalize(s)
    s = trim(s):lower()
    s = s:gsub("&", " and ")
    s = s:gsub("[^%w%s]", " ")
    s = s:gsub("%s+", " ")
    return trim(s)
end

function Library:authorString(value)
    if type(value) == "table" then
        local out = {}
        for _, v in ipairs(value) do
            local s = trim(v)
            if s ~= "" then
                table.insert(out, s)
            end
        end
        return table.concat(out, ", ")
    end
    return trim(value)
end

function Library:canonicalKey(title, authors)
    local t = normalize(title)
    if t == "" then
        return nil
    end
    return t .. " :: " .. normalize(self:authorString(authors))
end

local function scan(dir, out)
    local ok, iter, obj = pcall(lfs.dir, dir)
    if not ok or not iter then
        return
    end

    for name in iter, obj do
        if name ~= "." and name ~= ".." then
            local path = dir .. "/" .. name
            local mode = lfs.attributes(path, "mode")

            if mode == "directory" then
                scan(path, out)
            elseif mode == "file" and name:lower():match("%.epub$") then
                local title =
                    name:gsub("%.[Ee][Pp][Uu][Bb]$", "")
                        :gsub("_", " ")

                table.insert(out, {
                    file = path,
                    title = title,
                    authors = "",
                })
            end
        end
    end
end

function Library:getBooks()
    local out = {}
    scan(ROOT, out)
    return out
end

function Library:buildTitleIndex(books)
    local out = {}
    for _, book in ipairs(books or {}) do
        local key = normalize(book.title)
        if key ~= "" then
            out[key] = out[key] or {}
            table.insert(out[key], book)
        end
    end
    return out
end

function Library:matchOne(title, authors, books, title_index)
    local matches =
        (title_index or self:buildTitleIndex(books or {}))
        [normalize(title)]
        or {}

    if #matches == 1 then
        return matches[1], "matched"
    elseif #matches > 1 then
        return nil, "ambiguous"
    end

    return nil, "unmatched"
end

function Library:matchBookmory(bookmory_books, kindle_books)
    local index = self:buildTitleIndex(kindle_books or {})
    local result = {
        matched = 0,
        ambiguous = 0,
        unmatched = 0,
    }

    for _, book in ipairs(bookmory_books or {}) do
        local _, status =
            self:matchOne(
                book.title,
                book.authors,
                kindle_books,
                index
            )

        result[status] =
            (result[status] or 0) + 1
    end

    return result
end

return Library
