local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Updater = {}

function Updater:checkForUpdates(current_version)
    UIManager:show(
        InfoMessage:new{
            text =
                "Reading Brain "
                .. tostring(current_version or "")
                .. "\n\n"
                .. "Automatic updating is disabled in this recovery build.\n\n"
                .. "Use the full plugin ZIP from your GitHub repository when updating.",
        }
    )
end

function Updater:confirmRestore()
    UIManager:show(
        ConfirmBox:new{
            text =
                "Automatic restore is disabled in this recovery build.\n\n"
                .. "Use your previous Reading Brain folder backup if you need to roll back.",
            ok_text = _("OK"),
            cancel_text = _("Close"),
        }
    )
end

return Updater
