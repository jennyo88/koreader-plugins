local BookList = require("ui/widget/booklist")
local DocSettings = require("docsettings")
local lfs = require("libs/libkoreader-lfs")

local Library = {}

Library.extensions = {
    epub = true,
}

local ignored_names = {
    ["."] = true,
    [".."] = true,
    [".adds"] = true,
    [".git"] = true,
    ["koreader"] = true,
    ["system"] = true,
}

local function basename(path)
    return path:match("([^/]+)$") or path
end

local function dirname(path)
    return path:match("^(.*)/[^/]+$")
end

local function extension(path)
    local ext = path:match("%.([^./]+)$")
    return ext and ext:lower() or nil
end

local function is_dir(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end

local function should_ignore_dir(path)
    local name = basename(path)

    if ignored_names[name] then
        return true
    end

    if name:sub(1, 1) == "." then
        return true
    end

    if name:match("%.sdr$") then
        return true
    end

    return false
end

local function supported(path)
    local ext = extension(path)
    return ext and Library.extensions[ext] == true
end

local function sort_books(books)
    table.sort(books, function(a, b)
        local at = (a.title or a.filename or ""):lower()
        local bt = (b.title or b.filename or ""):lower()
        return at < bt
    end)

    return books
end

function Library:getDefaultRoot()
    if is_dir("/mnt/us/koreader/books") then
        return "/mnt/us/koreader/books"
    end

    return "/mnt/us"
end

function Library:getBookStatus(file)
    local ok, status = pcall(function()
        if BookList.getBookStatus then
            return BookList:getBookStatus(file)
        end
    end)

    if ok and status then
        return status
    end

    local settings_ok, settings = pcall(function()
        return DocSettings:open(file)
    end)

    if settings_ok and settings then
        local summary = settings:readSetting("summary")

        if summary and summary.status then
            return summary.status
        end
    end

    return nil
end

function Library:hasBeenOpened(file)
    local ok, opened = pcall(function()
        if BookList.hasBookBeenOpened then
            return BookList:hasBookBeenOpened(file)
        end
    end)

    if ok and opened ~= nil then
        return opened == true
    end

    local settings_ok, settings = pcall(function()
        return DocSettings:open(file)
    end)

    if not settings_ok or not settings then
        return false
    end

    return settings:readSetting("percent_finished") ~= nil
        or settings:readSetting("last_xpointer") ~= nil
        or settings:readSetting("last_page") ~= nil
end

function Library:isFinished(file)
    return self:getBookStatus(file) == "complete"
end

function Library:getMetadata(file)
    local book = {
        file = file,
        filename = basename(file),
        directory = dirname(file),
        title = nil,
        authors = nil,
        series = nil,
        series_index = nil,
        pages = nil,
        percent_finished = nil,
        status = self:getBookStatus(file),
        been_opened = self:hasBeenOpened(file),
    }

    local ok, settings = pcall(function()
        return DocSettings:open(file)
    end)

    if not ok or not settings then
        return book
    end

    local props = settings:readSetting("doc_props") or {}

    book.title = props.title
    book.authors = props.authors
    book.series = props.series
    book.series_index = props.series_index
    book.pages = settings:readSetting("doc_pages")
    book.percent_finished = settings:readSetting("percent_finished")

    return book
end

function Library:scanDirectory(path, results)
    results = results or {}

    if not is_dir(path) then
        return results
    end

    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            local full = path .. "/" .. entry
            local attr = lfs.attributes(full)

            if attr then
                if attr.mode == "directory" then
                    if not should_ignore_dir(full) then
                        self:scanDirectory(full, results)
                    end
                elseif attr.mode == "file" and supported(full) then
                    table.insert(results, full)
                end
            end
        end
    end

    return results
end

-- Returns every supported book, including completed books.
-- Continue a Series needs this so it can understand which earlier
-- volumes have already been finished.
function Library:getAllBooks(root)
    root = root or self:getDefaultRoot()

    local books = {}

    for _, file in ipairs(self:scanDirectory(root)) do
        table.insert(books, self:getMetadata(file))
    end

    return sort_books(books)
end

-- Normal TBR candidates exclude completed books.
function Library:getCandidates(root)
    local books = {}

    for _, book in ipairs(self:getAllBooks(root)) do
        if book.status ~= "complete" then
            table.insert(books, book)
        end
    end

    return sort_books(books)
end

return Library
