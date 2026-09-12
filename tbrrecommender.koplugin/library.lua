local BookList = require("ui/widget/booklist")
local Device = require("device")
local DocSettings = require("docsettings")
local lfs = require("libs/libkoreader-lfs")

local Library = {}


-- ---------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------

Library.extensions = {
    epub = true,
}

Library.ignored_directories = {
    ["."] = true,
    [".."] = true,

    [".sdr"] = true,
    [".adds"] = true,
    [".git"] = true,

    ["koreader"] = true,
    ["system"] = true,
    ["documents/.sdr"] = true,
}


-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

local function basename(path)
    return path:match("([^/]+)$") or path
end


local function dirname(path)
    return path:match("^(.*)/[^/]+$")
end


local function extension(path)

    local ext =
        path:match("%.([^./]+)$")

    if not ext then
        return nil
    end

    return ext:lower()
end


local function isSupportedBook(path)

    local ext =
        extension(path)

    return ext
        and Library.extensions[ext]
        or false
end


local function shouldIgnoreDirectory(path)

    local name =
        basename(path)

    if Library.ignored_directories[name] then
        return true
    end

    -- KOReader sidecar folders.
    if name:match("%.sdr$") then
        return true
    end

    -- Hidden directories are ignored by default.
    if name:sub(1, 1) == "." then
        return true
    end

    return false
end


local function fileExists(path)

    local attr =
        lfs.attributes(path)

    return attr
        and attr.mode == "file"
end


-- ---------------------------------------------------------
-- Book state
-- ---------------------------------------------------------

function Library:getBookStatus(file)

    -- First use KOReader's book cache.
    local ok, status =
        pcall(
            BookList.getBookStatus,
            file
        )

    if ok and status then
        return status
    end


    -- Fall back to document settings when available.
    local settings_ok, doc_settings =
        pcall(
            DocSettings.open,
            DocSettings,
            file
        )

    if not settings_ok
        or not doc_settings then

        return nil
    end


    local summary =
        doc_settings:readSetting(
            "summary"
        )

    if summary
        and summary.status then

        return summary.status
    end


    return nil
end


function Library:hasBeenOpened(file)

    local ok, opened =
        pcall(
            BookList.hasBookBeenOpened,
            file
        )

    if ok then
        return opened == true
    end

    return false
end


function Library:isFinished(file)

    return
        self:getBookStatus(file)
        == "complete"
end


-- ---------------------------------------------------------
-- Metadata
-- ---------------------------------------------------------

function Library:getMetadata(file)

    local metadata = {
        file =
            file,

        filename =
            basename(file),

        directory =
            dirname(file),

        title =
            nil,

        authors =
            nil,

        series =
            nil,

        series_index =
            nil,

        pages =
            nil,

        percent_finished =
            nil,

        status =
            self:getBookStatus(file),

        been_opened =
            self:hasBeenOpened(file),
    }


    if not metadata.been_opened then
        return metadata
    end


    local ok, doc_settings =
        pcall(
            BookList.getDocSettings,
            file
        )

    if not ok
        or not doc_settings then

        return metadata
    end


    local props =
        doc_settings:readSetting(
            "doc_props"
        ) or {}


    metadata.title =
        props.title

    metadata.authors =
        props.authors

    metadata.series =
        props.series

    metadata.series_index =
        props.series_index

    metadata.pages =
        doc_settings:readSetting(
            "doc_pages"
        )

    metadata.percent_finished =
        doc_settings:readSetting(
            "percent_finished"
        )


    return metadata
end


-- ---------------------------------------------------------
-- Scanning
-- ---------------------------------------------------------

function Library:scanDirectory(path, results)

    results =
        results or {}


    local attr =
        lfs.attributes(path)

    if not attr
        or attr.mode ~= "directory" then

        return results
    end


    for entry in lfs.dir(path) do

        if entry ~= "."
            and entry ~= ".." then

            local full_path =
                path .. "/" .. entry

            local entry_attr =
                lfs.attributes(
                    full_path
                )


            if entry_attr then

                if entry_attr.mode == "directory" then

                    if not shouldIgnoreDirectory(
                        full_path
                    ) then

                        self:scanDirectory(
                            full_path,
                            results
                        )
                    end


                elseif entry_attr.mode == "file"
                    and isSupportedBook(
                        full_path
                    ) then

                    table.insert(
                        results,
                        full_path
                    )
                end
            end
        end
    end


    return results
end


-- ---------------------------------------------------------
-- Library root
-- ---------------------------------------------------------

function Library:getDefaultRoot()

    -- Kindle / KOReader user storage.
    if Device.home_dir then
        return Device.home_dir
    end

    return "/mnt/us"
end


-- ---------------------------------------------------------
-- Candidate books
-- ---------------------------------------------------------

function Library:getCandidates(root)

    root =
        root
        or self:getDefaultRoot()


    local files =
        self:scanDirectory(
            root
        )


    local books = {}


    for _, file in ipairs(files) do

        if fileExists(file)
            and not self:isFinished(
                file
            ) then

            table.insert(
                books,
                self:getMetadata(file)
            )
        end
    end


    table.sort(
        books,

        function(a, b)

            local a_name =
                a.title
                or a.filename
                or ""

            local b_name =
                b.title
                or b.filename
                or ""

            return
                a_name:lower()
                < b_name:lower()
        end
    )


    return books
end


-- ---------------------------------------------------------
-- Convenience filters
-- ---------------------------------------------------------

function Library:getUnopenedBooks(root)

    local books =
        self:getCandidates(root)

    local results = {}


    for _, book in ipairs(books) do

        if not book.been_opened then
            table.insert(
                results,
                book
            )
        end
    end


    return results
end


function Library:getStartedBooks(root)

    local books =
        self:getCandidates(root)

    local results = {}


    for _, book in ipairs(books) do

        if book.been_opened
            and book.status ~= "complete" then

            table.insert(
                results,
                book
            )
        end
    end


    return results
end


function Library:getSeriesBooks(root)

    local books =
        self:getCandidates(root)

    local results = {}


    for _, book in ipairs(books) do

        if book.series
            and book.series ~= "" then

            table.insert(
                results,
                book
            )
        end
    end


    return results
end


return Library
