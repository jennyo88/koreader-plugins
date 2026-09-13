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

local function author_string(value)
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
            local props =
                settings:readSetting("doc_props")
                or {}

            item.title = props.title
            item.authors = props.authors
            item.identifiers =
                props.identifiers
        end

        if not item.title or item.title == "" then
            item.title =
                item.filename:gsub(
                    "%.[Ee][Pp][Uu][Bb]$",
                    ""
                )
        end

        item.normalized_title =
            normalize(item.title)

        item.normalized_authors =
            normalize(
                author_string(
                    item.authors
                )
            )

        table.insert(
            books,
            item
        )
    end

    return books
end

function Library:matchBookmory(bookmory_books, kindle_books)
    local title_index = {}

    for _, book in ipairs(kindle_books or {}) do
        local key =
            book.normalized_title

        if key ~= "" then
            title_index[key] =
                title_index[key]
                or {}

            table.insert(
                title_index[key],
                book
            )
        end
    end

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
        local title =
            normalize(
                b.title
            )

        local authors =
            normalize(
                author_string(
                    b.authors
                )
            )

        local candidates =
            title_index[title]
            or {}

        local matches = {}

        if #candidates == 1 then
            local candidate =
                candidates[1]

            -- Exact title is enough when one side lacks usable author
            -- metadata. When both sides have authors, require overlap.
            if authors == ""
                or candidate.normalized_authors == ""
                or authors == candidate.normalized_authors
                or candidate.normalized_authors:find(
                    authors,
                    1,
                    true
                )
                or authors:find(
                    candidate.normalized_authors,
                    1,
                    true
                ) then

                table.insert(
                    matches,
                    candidate
                )
            end
        elseif #candidates > 1 then
            for _, candidate in ipairs(candidates) do
                if authors ~= ""
                    and candidate.normalized_authors ~= ""
                    and (
                        authors == candidate.normalized_authors
                        or candidate.normalized_authors:find(
                            authors,
                            1,
                            true
                        )
                        or authors:find(
                            candidate.normalized_authors,
                            1,
                            true
                        )
                    ) then

                    table.insert(
                        matches,
                        candidate
                    )
                end
            end
        end

        if #matches == 1 then
            summary.matched =
                summary.matched
                + 1

            if #examples.matched < 5 then
                table.insert(
                    examples.matched,
                    b.title or "Untitled"
                )
            end

        elseif #matches > 1
            or #candidates > 1 then

            summary.ambiguous =
                summary.ambiguous
                + 1

            if #examples.ambiguous < 5 then
                table.insert(
                    examples.ambiguous,
                    b.title or "Untitled"
                )
            end

        else
            summary.unmatched =
                summary.unmatched
                + 1

            if #examples.unmatched < 5 then
                table.insert(
                    examples.unmatched,
                    b.title or "Untitled"
                )
            end
        end
    end

    return summary, examples
end

return Library
