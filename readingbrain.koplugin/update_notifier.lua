local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")

local UpdateNotifier = {}
UpdateNotifier.__index = UpdateNotifier

function UpdateNotifier:new(opts)
    local o = setmetatable({}, self)
    o.plugin_id = opts and opts.plugin_id or "readingbrain"
    o.plugin_name = opts and opts.plugin_name or "Reading Brain"
    o.current_version = opts and opts.current_version or "0.0.0"
    o.settings =
        LuaSettings:open(
            DataStorage:getSettingsDir()
            .. "/readingbrain_notifier.lua"
        )
    return o
end

function UpdateNotifier:isEnabled()
    return
        self.settings:isTrue(
            "enabled"
        )
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
    -- Recovery build: intentionally no automatic network activity.
    -- Manual update checks remain available under Settings & Updates.
end

return UpdateNotifier
