-- Manual version check only; never starts Wi-Fi, downloads code or changes files.
-- The recovery updater supplied for Reading Brain did not install updates either.
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Updater = {}
local manifest_url = "https://raw.githubusercontent.com/jennyo88/koreader-plugins/main/minimalshelf.koplugin/update.json"
local repo_url = "https://github.com/jennyo88/koreader-plugins"

local function newer(a, b)
    local aa, ab, ac = tostring(a):match("^v?(%d+)%.(%d+)%.(%d+)$")
    local ba, bb, bc = tostring(b):match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not aa or not ba then return nil end
    local x, y = {tonumber(aa), tonumber(ab), tonumber(ac)}, {tonumber(ba), tonumber(bb), tonumber(bc)}
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] > y[i] end
    end
    return false
end

local function notice(text)
    UIManager:show(InfoMessage:new{ text = text })
end

function Updater:checkForUpdates(current_version)
    -- The only network path is this explicit menu callback.
    local okmgr, NetworkMgr = pcall(require, "ui/network/manager")
    if not okmgr or not NetworkMgr:isConnected() then
        notice(_("Wi-Fi is off. Connect manually, then select Check for updates again."))
        return
    end
    local okhttps, https = pcall(require, "ssl.https")
    local okltn, ltn12 = pcall(require, "ltn12")
    local okjson, json = pcall(require, "rapidjson")
    if not okhttps or not okltn or not okjson then
        notice(_("This KOReader version lacks the modules required for a GitHub check."))
        return
    end
    local chunks = {}
    local original_timeout = https.TIMEOUT
    https.TIMEOUT = 8
    local call_ok, fetched, code = pcall(https.request, {
        url = manifest_url,
        sink = ltn12.sink.table(chunks),
        headers = { ["User-Agent"] = "KOReader-MinimalShelf", ["Accept"] = "application/json" },
    })
    https.TIMEOUT = original_timeout
    if not call_ok or not fetched or tonumber(code) ~= 200 then
        notice(_("Could not fetch Minimal Shelf's version manifest from GitHub."))
        return
    end
    local parsed, manifest = pcall(json.decode, table.concat(chunks))
    if not parsed or type(manifest) ~= "table" or type(manifest.version) ~= "string" then
        notice(_("The downloaded update manifest is invalid."))
        return
    end
    local result = newer(manifest.version, current_version)
    if result == nil then
        notice(_("Could not compare plugin versions."))
    elseif not result then
        notice("Minimal Shelf " .. tostring(current_version) .. "\n\n" .. _("You are up to date."))
    else
        UIManager:show(ConfirmBox:new{
            text = "Minimal Shelf " .. tostring(current_version)
                .. " -> " .. manifest.version .. "\n\n"
                .. _("An update is available. Installation is manual in this build. Download your repository ZIP, replace only minimalshelf.koplugin, and restart KOReader.")
                .. "\n\n" .. repo_url,
            ok_text = _("OK"),
            cancel_text = _("Close"),
        })
    end
end

function Updater:confirmRestore()
    UIManager:show(ConfirmBox:new{
        text = _("Automatic restore is disabled. Restore a backed-up minimalshelf.koplugin folder manually if necessary."),
        ok_text = _("OK"),
        cancel_text = _("Close"),
    })
end

return Updater
