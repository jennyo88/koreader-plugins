local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Feedback = {}

local SETTINGS_PATH =
    DataStorage:getSettingsDir()
    .. "/readingbrain_discovery_feedback.lua"

local VALID = {
    want = true,
    dismiss = true,
    owned = true,
}

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

local function key_for(book)
    if type(book) ~= "table" then
        return ""
    end

    local key = tostring(book.key or "")

    if key ~= "" then
        return "ol:" .. key
    end

    return "title:" .. normalize(book.title or "")
end

local function open_settings()
    return LuaSettings:open(SETTINGS_PATH)
end

local function compact_book(book)
    return {
        key = book.key,
        title = book.title,
        authors = book.authors or {},
        year = book.year,
        score = book.score,
        reasons = book.reasons or {},
        confidence = book.confidence,
        saved_at = os.time(),
    }
end

local function saved_books(settings)
    local saved = settings:readSetting("saved_books")

    if type(saved) ~= "table" then
        return {}
    end

    return saved
end

local function remove_saved(saved, book_key)
    local result = {}

    for _, book in ipairs(saved or {}) do
        if key_for(book) ~= book_key then
            table.insert(result, book)
        end
    end

    return result
end

function Feedback:get(book)
    local key = key_for(book)

    if key == "" then
        return nil
    end

    local s = open_settings()
    return s:readSetting("book_" .. key)
end

function Feedback:set(book, value)
    if not VALID[value] then
        return false
    end

    local key = key_for(book)

    if key == "" then
        return false
    end

    local s = open_settings()
    s:saveSetting("book_" .. key, value)

    local saved = remove_saved(
        saved_books(s),
        key
    )

    if value == "want" then
        table.insert(saved, 1, compact_book(book))
    end

    s:saveSetting("saved_books", saved)
    s:flush()

    return true
end

function Feedback:clear(book)
    local key = key_for(book)

    if key == "" then
        return
    end

    local s = open_settings()
    s:delSetting("book_" .. key)
    s:saveSetting(
        "saved_books",
        remove_saved(
            saved_books(s),
            key
        )
    )
    s:flush()
end

function Feedback:listWanted()
    local s = open_settings()
    local saved = saved_books(s)
    local result = {}

    for _, book in ipairs(saved) do
        if self:get(book) == "want" then
            book.feedback = "want"
            table.insert(result, book)
        end
    end

    table.sort(
        result,
        function(a, b)
            return
                (tonumber(a.saved_at) or 0)
                > (tonumber(b.saved_at) or 0)
        end
    )

    return result
end

function Feedback:apply(candidates, include_wanted)
    local result = {}

    for _, candidate in ipairs(candidates or {}) do
        local state = self:get(candidate)

        if state ~= "dismiss"
            and state ~= "owned"
            and (include_wanted or state ~= "want") then

            candidate.feedback = state
            table.insert(result, candidate)
        end
    end

    table.sort(
        result,
        function(a, b)
            local ac = tonumber(a.confidence_rank) or 0
            local bc = tonumber(b.confidence_rank) or 0

            if ac ~= bc then
                return ac > bc
            end

            local as = tonumber(a.score) or 0
            local bs = tonumber(b.score) or 0

            if as == bs then
                return
                    tostring(a.title or "")
                    < tostring(b.title or "")
            end

            return as > bs
        end
    )

    return result
end

function Feedback:label(book)
    local state = self:get(book)

    if state == "want" then
        return "SAVED"
    elseif state == "dismiss" then
        return "NOT FOR ME"
    elseif state == "owned" then
        return "ALREADY OWN"
    end

    return nil
end

return Feedback
