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
    s:flush()
end

function Feedback:apply(candidates)
    local result = {}

    for _, candidate in ipairs(candidates or {}) do
        local state = self:get(candidate)

        if state ~= "dismiss"
            and state ~= "owned" then

            candidate.feedback = state
            candidate.want_priority = state == "want" and 1 or 0
            table.insert(result, candidate)
        end
    end

    table.sort(
        result,
        function(a, b)
            local aw = tonumber(a.want_priority) or 0
            local bw = tonumber(b.want_priority) or 0

            if aw ~= bw then
                return aw > bw
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
        return "WANT TO READ"
    elseif state == "dismiss" then
        return "NOT FOR ME"
    elseif state == "owned" then
        return "ALREADY OWN"
    end

    return nil
end

return Feedback
