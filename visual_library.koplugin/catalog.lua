-- Small, bounded, read-only catalog of local EPUB files.
-- Never opens books just to obtain metadata: doing so would create zero-minute reading sessions.
local lfs = require("libs/libkoreader-lfs")
local Catalog = {}

local function exists(path)
    return type(path) == "string" and lfs.attributes(path, "mode") == "file"
end

local function fallback_title(path)
    local base = path:match("([^/]+)$") or path
    base = base:gsub("%.%w+$", ""):gsub("_", " ")
    return base
end

function Catalog.scan(root, limit)
    limit = limit or 900
    local result, seen = {}, {}
    local function add(path)
        if not seen[path] and exists(path) and path:lower():match("%.epub$") then
            seen[path] = true
            result[#result + 1] = { path = path, title = fallback_title(path) }
        end
    end
    local function visit(dir, depth)
        if depth > 7 or #result >= limit then return end
        if lfs.attributes(dir, "mode") ~= "directory" then return end
        local ok, iter, state = pcall(lfs.dir, dir)
        if not ok then return end
        local entries = {}
        for name in iter, state do
            if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
                entries[#entries + 1] = name
            end
        end
        table.sort(entries)
        for _, name in ipairs(entries) do
            if #result >= limit then break end
            local path = dir:gsub("/$", "") .. "/" .. name
            local mode = lfs.attributes(path, "mode")
            if mode == "file" then
                add(path)
            elseif mode == "directory" and name ~= "koreader" and name ~= "system" and name ~= "extensions" and name ~= "sdr" then
                visit(path, depth + 1)
            end
        end
    end
    visit(root, 0)
    table.sort(result, function(a, b) return a.title:lower() < b.title:lower() end)
    return result, add
end

function Catalog.enrich(items, bookinfo)
    if not bookinfo then return end
    -- Read *existing* Cover Browser metadata only. Do not trigger extraction.
    for _, b in ipairs(items) do
        local ok, meta = pcall(function() return bookinfo:getDocProps(b.path) end)
        if ok and type(meta) == "table" then
            if type(meta.title) == "string" and meta.title ~= "" then b.title = meta.title end
            if type(meta.authors) == "string" then b.author = meta.authors end
            if type(meta.keywords) == "string" then b.keywords = meta.keywords end
            if type(meta.series) == "string" then b.series = meta.series end
        end
    end
    table.sort(items, function(a, b) return a.title:lower() < b.title:lower() end)
end

function Catalog.exists(path) return exists(path) end
function Catalog.fallback_title(path) return fallback_title(path) end
return Catalog
