-- Matches Reading Brain's recovery-build power policy:
-- onWake never makes a network request or schedules an update check.
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")

local UpdateNotifier = {}
UpdateNotifier.__index = UpdateNotifier

function UpdateNotifier:new(opts)
    local o = setmetatable({}, self)
    o.plugin_id = opts and opts.plugin_id or "minimalshelf"
    o.plugin_name = opts and opts.plugin_name or "Minimal Shelf"
    o.current_version = opts and opts.current_version or "0.0.0"
    o.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/minimalshelf_notifier.lua")
    return o
end

function UpdateNotifier:isEnabled()
    return self.settings:isTrue("enabled")
end

function UpdateNotifier:setEnabled(value)
    if value then
        self.settings:makeTrue("enabled")
    else
        self.settings:makeFalse("enabled")
    end
    self.settings:flush()
end

function UpdateNotifier:onWake()
    -- Intentionally blank: no network access during wake or startup.
end

return UpdateNotifier
