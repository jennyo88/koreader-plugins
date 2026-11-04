-- Read-only library index. Scanning and metadata reads are explicitly invoked.
-- Never opens or renders books just to count pages.
local lfs = require("libs/libkoreader-lfs")
local DocSettings = require("docsettings")
local Catalog = {}
local extensions = { epub=true, pdf=true, mobi=true, azw3=true,
    fb2=true, djvu=true, cbz=true, txt=true, html=true }
local skip_dirs = { [".sdr"]=true, ["koreader"]=true, ["system"]=true,
    ["extensions"]=true, [".git"]=true }

local function file_title(path)
    return ((path:match("([^/]+)$") or path):gsub("%.[^.]+$", ""):gsub("_", " "))
end

local function safe_prop(meta, key)
    return type(meta) == "table" and meta[key] or nil
end

-- Optional, read-only access to Cover Browser's existing metadata cache.
-- We only look at SQLite on a user-requested scan; we never extract covers.
local function open_cover_cache()
    local DataStorage = require("datastorage")
    local path = DataStorage:getSettingsDir() .. "/bookinfo_cache.sqlite3"
    if lfs.attributes(path, "mode") ~= "file" then return nil end
    local ok_module, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_module then return nil end
    local ok_db, db = pcall(SQ3.open, path)
    if not ok_db or not db then return nil end
    local ok_stmt, stmt = pcall(function()
        return db:prepare("SELECT title, authors, series, series_index, pages " ..
            "FROM bookinfo WHERE directory=? AND filename=? AND in_progress=0;")
    end)
    if not ok_stmt or not stmt then db:close(); return nil end
    local cache = {db = db, stmt = stmt}
    function cache:getDocProps(filepath)
        local directory, filename = filepath:match("^(.-/)([^/]+)$")
        if not directory then return nil end
        local row = self.stmt:bind(directory, filename):step()
        local props
        if row then
            props = {
                title = row[1], authors = row[2], series = row[3],
                series_index = tonumber(row[4]), pages = tonumber(row[5]),
            }
        end
        self.stmt:clearbind():reset()
        return props
    end
    function cache:close() self.db:close() end
    return cache
end

local function info_for(path, book_info, calibre_reader)
    local book = { path = path, title = file_title(path), status = "unread" }
    local physical_pages

    if book_info then
        local ok, meta = pcall(book_info.getDocProps, book_info, path)
        if ok and type(meta) == "table" then
            if type(meta.title) == "string" and meta.title ~= "" then book.title = meta.title end
            if type(meta.authors) == "string" then book.author = meta.authors end
            if type(meta.series) == "string" then book.series = meta.series end
            book.series_index = tonumber(meta.series_index)
            -- Cover Browser doesn't compute reliable reflowable-book pages
            -- before a book has been rendered with the reader settings.
            if not path:lower():match("%.epub$") and not path:lower():match("%.fb2$")
               and not path:lower():match("%.mobi$") and not path:lower():match("%.azw3$") then
                local n = tonumber(meta.pages)
                if n and n > 0 and n < 200000 then physical_pages = math.floor(n) end
            end
        end
    end

    local calibre_pages
    if calibre_reader then
        local ok, meta = pcall(calibre_reader.get, calibre_reader, path)
        if ok and type(meta) == "table" then
            -- Calibre metadata can also supply missing series data for PDFs.
            if not book.series and type(meta.series) == "string" then book.series = meta.series end
            if not book.series_index then book.series_index = tonumber(meta.series_index) end
            if book.title == file_title(path) and type(meta.title) == "string"
                and meta.title ~= "" then book.title = meta.title end
            if not book.author and type(meta.authors) == "string" then book.author = meta.authors end
            calibre_pages = tonumber(meta.pages)
        end
    end

    local fraction
    local ok, has_sidecar = pcall(DocSettings.hasSidecarFile, DocSettings, path)
    if ok and has_sidecar then
        local opened, doc = pcall(DocSettings.open, DocSettings, path)
        if opened and doc then
            local props = doc:readSetting("doc_props")
            if not book.series then book.series = safe_prop(props, "series") end
            if not book.series_index then book.series_index = tonumber(safe_prop(props, "series_index")) end
            if type(safe_prop(props, "title")) == "string" and props.title ~= "" then book.title = props.title end
            local pages = tonumber(doc:readSetting("doc_pages"))
            if pages and pages > 0 and pages < 200000 then
                book.total_pages = math.floor(pages)
                book.page_source = "screen"
            end
            fraction = tonumber(doc:readSetting("percent_finished"))
            local summary = doc:readSetting("summary")
            if type(summary) == "table" and summary.status == "complete" then
                book.status = "complete"
            elseif fraction and fraction > 0 then
                book.status = "reading"
            end
        end
    end

    if not book.total_pages then
        if calibre_pages and calibre_pages > 0 and calibre_pages < 200000 then
            book.total_pages = math.floor(calibre_pages)
            book.page_source = "calibre"
        elseif physical_pages then
            book.total_pages = physical_pages
            book.page_source = "document"
        end
    end

    if book.total_pages then
        if book.status == "complete" then
            book.remaining = 0
        elseif fraction and fraction >= 0 and fraction <= 1 then
            book.remaining = math.max(0, math.ceil(book.total_pages * (1 - fraction)))
        else
            book.remaining = book.total_pages
        end
    end
    return book
end

-- Exposed for pure metadata precedence tests; doesn't read or write files.
Catalog.infoFor = info_for

function Catalog.scan(root, max_books, book_info, calibre_reader)
    max_books = max_books or 500
    if type(root) ~= "string" or lfs.attributes(root, "mode") ~= "directory" then
        return nil, "Library folder not found: " .. tostring(root)
    end
    local paths, visited = {}, {}
    local function visit(dir, depth)
        if depth > 7 or #paths >= max_books or visited[dir] then return end
        visited[dir] = true
        local ok, iter, state = pcall(lfs.dir, dir)
        if not ok or not iter then return end
        local names = {}
        for name in iter, state do
            if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            if #paths >= max_books then break end
            local path = dir:gsub("/$", "") .. "/" .. name
            local mode = lfs.attributes(path, "mode")
            if mode == "directory" then
                if not skip_dirs[name:lower()] and not name:lower():match("%.sdr$") then
                    visit(path, depth + 1)
                end
            elseif mode == "file" then
                local suffix = name:lower():match("%.([^.]+)$")
                if extensions[suffix] then paths[#paths + 1] = path end
            end
        end
    end
    visit(root, 0)
    local cache = book_info or open_cover_cache()
    local calibre = calibre_reader or (Catalog.CalibrePages and Catalog.CalibrePages.new())
    local result = {}
    local counts = {screen = 0, calibre = 0, document = 0, unknown = 0}
    for _, path in ipairs(paths) do
        local book = info_for(path, cache, calibre)
        result[#result + 1] = book
        local source = book.page_source or "unknown"
        counts[source] = counts[source] + 1
    end
    if not book_info and cache then cache:close() end
    table.sort(result, function(a, b) return a.title:lower() < b.title:lower() end)
    return result, nil, counts
end

return Catalog
