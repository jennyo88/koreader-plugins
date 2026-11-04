-- Minimal Shelf's read-only Calibre metadata.calibre reader.
-- Run only during an explicit offline library/page-count scan.
-- Does not open EPUBs, query metadata.db, or make network requests.
local CalibrePages = {}
CalibrePages.__index = CalibrePages

local MAX_METADATA_BYTES = 12 * 1024 * 1024

local function normalize(path)
    if type(path) ~= "string" then return nil end
    path = path:gsub("\\", "/"):gsub("/+", "/")
    path = path:gsub("/%./", "/"):gsub("^%./", "")
    return path:gsub("/$", "")
end

local function positive_pages(value)
    if type(value) ~= "string" and type(value) ~= "number" then return nil end
    local n = tonumber(value)
    if n and n == n and n >= 1 and n <= 200000 and n % 1 == 0 then
        return n
    end
end

-- Calibre's Count Pages plugin normally stores this in the custom #pages column:
--   user_metadata["#pages"]["#value#"] = 123
-- The optional aliases accommodate user-defined variants of the column name.
function CalibrePages.extractCount(entry)
    if type(entry) ~= "table" then return nil end
    local columns = entry.user_metadata
    if type(columns) == "table" then
        for _, key in ipairs({"#pages", "#page_count", "#pagecount"}) do
            local v = columns[key]
            if type(v) == "table" then
                local count = positive_pages(v["#value#"] or v.value)
                if count then return count end
            else
                local count = positive_pages(v)
                if count then return count end
            end
        end
    end
    -- Some device-side exporters provide one of these scalar fields.
    return positive_pages(entry.page_count) or positive_pages(entry.pages)
end

-- Index by full device path. Never match books only by title/basename:
-- a library can have multiple editions, formats and books with the same title.
function CalibrePages.indexEntries(base_dir, entries)
    local index = {}
    if type(entries) ~= "table" then return index end
    base_dir = normalize(base_dir)
    if not base_dir or base_dir:sub(1, 1) ~= "/" then return index end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and type(entry.lpath) == "string" then
            local rel = normalize(entry.lpath)
            if rel and rel ~= "" and rel:sub(1, 1) ~= "/"
                and rel ~= ".." and not rel:find("../", 1, true)
                and not rel:find("/..", 1, true) then
                local full = normalize(base_dir .. "/" .. rel)
                index[full] = {
                    pages = CalibrePages.extractCount(entry),
                    title = type(entry.title) == "string" and entry.title or nil,
                    authors = type(entry.authors) == "string" and entry.authors or nil,
                    series = type(entry.series) == "string" and entry.series or nil,
                    series_index = tonumber(entry.series_index),
                }
            end
        end
    end
    return index
end

function CalibrePages.new()
    return setmetatable({ files = {}, folders = {} }, CalibrePages)
end

function CalibrePages:loadMetadata(path, base)
    if self.files[path] ~= nil then return self.files[path] end
    self.files[path] = false -- failed/missing files aren't opened again this scan

    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    if not size or size > MAX_METADATA_BYTES then f:close(); return nil end
    f:seek("set", 0)
    local data = f:read("*a")
    f:close()
    if not data or #data == 0 then return nil end
    local okmod, json = pcall(require, "rapidjson")
    if not okmod then return nil end
    local ok, decoded = pcall(json.decode, data)
    if not ok or type(decoded) ~= "table" then return nil end
    local entries = type(decoded.books) == "table" and decoded.books or decoded
    local index = CalibrePages.indexEntries(base, entries)
    self.files[path] = index
    return index
end

function CalibrePages:get(filepath)
    filepath = normalize(filepath)
    if not filepath or filepath:sub(1, 1) ~= "/" then return nil end
    local dir = filepath:match("^(.*)/[^/]+$") or "/"
    for _ = 1, 9 do
        if self.folders[dir] == nil then
            local index
            -- Calibre's USB/device metadata can use either spelling.
            for _, filename in ipairs({"metadata.calibre", ".metadata.calibre"}) do
                local candidate = (dir == "/" and "" or dir) .. "/" .. filename
                local data = self:loadMetadata(candidate, dir)
                if data then
                    index = index or {}
                    for k, v in pairs(data) do index[k] = v end
                end
            end
            self.folders[dir] = index or false
        end
        local index = self.folders[dir]
        if index and index[filepath] then return index[filepath] end
        if dir == "/" or dir == "" then break end
        dir = dir:match("^(.*)/[^/]+$") or "/"
        if dir == "" then dir = "/" end
    end
end

return CalibrePages
