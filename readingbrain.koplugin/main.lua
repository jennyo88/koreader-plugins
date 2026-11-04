local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Screen = Device.screen

local PLUGIN_VERSION = "0.7.0"

local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("(.+)/[^/]+$")
if plugin_dir and plugin_dir:sub(1, 1) ~= "/" then
    plugin_dir = "/mnt/us/koreader/" .. plugin_dir
end
plugin_dir = plugin_dir or "/mnt/us/koreader/plugins/readingbrain.koplugin"

local Bookmory = dofile(plugin_dir .. "/bookmory.lua")
local Library = dofile(plugin_dir .. "/library.lua")
local Stats = dofile(plugin_dir .. "/stats.lua")
local Brain = dofile(plugin_dir .. "/brain.lua")
local Discovery = dofile(plugin_dir .. "/discovery.lua")
local UpdateNotifier = dofile(plugin_dir .. "/update_notifier.lua")
local StatsPatterns = dofile(plugin_dir .. "/stats_patterns.lua")
local BackupHealth = dofile(plugin_dir .. "/backup_health.lua")
local Feedback = dofile(plugin_dir .. "/feedback.lua")
local BookPage = dofile(plugin_dir .. "/book_page.lua")

local function loadUpdater()
    local updater_path = plugin_dir .. "/updater.lua"
    local file = io.open(updater_path, "r")

    if not file then
        UIManager:show(InfoMessage:new{
            text = "Updater file was not found.\n\n"
                .. updater_path
                .. "\n\nRun the installer again to install updater.lua.",
        })
        return nil
    end

    file:close()

    local ok, updater_or_error = pcall(dofile, updater_path)

    if not ok then
        UIManager:show(InfoMessage:new{
            text = "Updater could not be loaded.\n\n"
                .. tostring(updater_or_error),
        })
        return nil
    end

    return updater_or_error
end


local StatsDialog =
    InputContainer:extend{
        title = "",
        body = "",
        owner = nil,
        button_rows = nil,
    }

function StatsDialog:init()
    local card_width =
        math.floor(
            Screen:getWidth()
            * 0.90
        )

    local content_width =
        card_width
        - Screen:scaleBySize(44)
