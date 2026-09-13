local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local NetworkMgr = require("ui/network/manager")
local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")
local ltn12 = require("ltn12")
local rapidjson = require("rapidjson")
local socketutil = require("socketutil")
local https = require("ssl.https")

local UpdateNotifier = {}

local MANIFEST_URL =
    "https://raw.githubusercontent.com/jennyo88/koreader-plugins/main/manifest.json"

local CHECK_INTERVAL = 12 * 60 * 60

local function parse_version(version)
    local result = {}

    for piece in tostring(version or "0")
        :gsub("^v", "")
        :gmatch("([^.]+)") do

        table.insert(
            result,
            tonumber(piece:match("^(%d+)")) or 0
        )
    end

    return result
end

local function is_newer(remote, current)
    local a = parse_version(remote)
    local b = parse_version(current)
    local count = math.max(#a, #b)

    for i = 1, count do
        local av = a[i] or 0
        local bv = b[i] or 0

        if av > bv then
            return true
        elseif av < bv then
            return false
        end
    end

    return false
end

local function fetch_manifest()
    local sink = {}

    socketutil:set_timeout(
        socketutil.LARGE_BLOCK_TIMEOUT,
        socketutil.LARGE_TOTAL_TIMEOUT
    )

    local ok, code, _, status = https.request{
        url = MANIFEST_URL,
        method = "GET",
        sink = ltn12.sink.table(sink),
        headers = {
            ["User-Agent"] = "KOReader-ReadingBrain-Notifier",
            ["Accept"] = "application/json",
        },
    }

    socketutil:reset_timeout()

    if not ok or tonumber(code) ~= 200 then
        return nil,
            "HTTP "
            .. tostring(code or "?")
            .. ": "
            .. tostring(status or "request failed")
    end

    local parsed_ok, manifest =
        pcall(
            rapidjson.decode,
            table.concat(sink)
        )

    if not parsed_ok
        or type(manifest) ~= "table" then

        return nil, "Could not parse manifest.json."
    end

    return manifest
end

function UpdateNotifier:new(args)
    local o = {
        plugin_id = args.plugin_id,
        plugin_name = args.plugin_name,
        current_version = args.current_version,
        checking = false,
    }

    o.settings = LuaSettings:open(
        DataStorage:getSettingsDir()
        .. "/"
        .. o.plugin_id
        .. "_update_notice.lua"
    )

    setmetatable(o, {
        __index = self,
    })

    return o
end

function UpdateNotifier:isEnabled()
    if not self.settings:has("enabled") then
        self.settings:saveSetting(
            "enabled",
            true
        ):flush()
    end

    return self.settings:nilOrFalse(
        "enabled"
    )
end

function UpdateNotifier:setEnabled(enabled)
    self.settings:saveSetting(
        "enabled",
        enabled and true or false
    ):flush()
end

function UpdateNotifier:isDue()
    local last =
        tonumber(
            self.settings:readSetting(
                "last_check",
                0
            )
        )
        or 0

    return
        os.time() - last
        >= CHECK_INTERVAL
end

function UpdateNotifier:recordCheck()
    self.settings:saveSetting(
        "last_check",
        os.time()
    ):flush()
end

function UpdateNotifier:checkIfDue()
    if self.checking
        or not self:isEnabled()
        or not self:isDue()
        or not NetworkMgr:isOnline() then

        return
    end

    self.checking = true

    UIManager:scheduleIn(
        0.2,
        function()
            local manifest =
                fetch_manifest()

            self.checking = false

            if not manifest then
                return
            end

            self:recordCheck()

            local plugins =
                manifest.plugins
                or manifest

            local entry =
                type(plugins) == "table"
                and plugins[self.plugin_id]
                or nil

            local remote =
                type(entry) == "table"
                and entry.version
                or nil

            if remote
                and is_newer(
                    remote,
                    self.current_version
                ) then

                Notification:notify(
                    self.plugin_name
                    .. " "
                    .. tostring(remote)
                    .. " available"
                )
            end
        end
    )
end

function UpdateNotifier:scheduleStartupCheck()
    UIManager:scheduleIn(
        6,
        function()
            self:checkIfDue()
        end
    )
end

return UpdateNotifier
