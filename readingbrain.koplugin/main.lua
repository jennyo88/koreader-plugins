local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local PLUGIN_VERSION = "0.1.1"

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

local ReadingBrain = WidgetContainer:extend{
    name = "readingbrain",
    is_doc_only = false,
}

local function hours_minutes(seconds)
    local total = math.floor((tonumber(seconds) or 0) / 60)

    return string.format(
        "%dh %02dm",
        math.floor(total / 60),
        total % 60
    )
end

local function short_path(path)
    if not path then
        return ""
    end

    return path:gsub("^/mnt/us/", "")
end

function ReadingBrain:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function ReadingBrain:analyze()
    local status = InfoMessage:new{
        text = _("Reading Bookmory backup…"),
    }

    UIManager:show(status)
    UIManager:forceRePaint()

    local backup = Bookmory:findLatestBackup()

    if not backup then
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "No .bookmory backup was found.\n\n"
                .. "Copy your latest backup to:\n"
                .. "/mnt/us/readingbrain/\n\n"
                .. "Reading Brain is read-only in v"
                .. PLUGIN_VERSION
                .. ".",
        })

        return
    end

    local db_path, extract_err =
        Bookmory:extractDatabase(backup)

    if not db_path then
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "Could not read the backup.\n\n"
                .. tostring(extract_err),
        })

        return
    end

    local books, read_err =
        Bookmory:readBooks(db_path)

    if not books then
        Bookmory:cleanup(db_path)
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "Could not read the Bookmory database.\n\n"
                .. tostring(read_err),
        })

        return
    end

    local bm =
        Bookmory:summarize(books)

    local kindle_books =
        Library:getBooks()

    local matches =
        Library:matchBookmory(
            books,
            kindle_books
        )

    Bookmory:cleanup(db_path)
    UIManager:close(status)

    local text =
        "READING BRAIN\n"
        .. "Read-only prototype • v"
        .. PLUGIN_VERSION
        .. "\n\n"
        .. "Backup\n"
        .. short_path(backup)
        .. "\n\n"
        .. "BOOKMORY\n"
        .. string.format("Books ............... %d\n", bm.books)
        .. string.format("Reads ............... %d\n", bm.reads)
        .. string.format("Timed sessions ...... %d\n", bm.sessions)
        .. string.format("Logged time ......... %s\n", hours_minutes(bm.seconds))
        .. string.format("Audio-only titles ... %d\n", bm.audiobook_titles)
        .. string.format("Audio-only sessions . %d\n", bm.audiobook_sessions)
        .. string.format("External/hybrid ..... %d\n", bm.external_sessions)
        .. "\nKINDLE LIBRARY\n"
        .. string.format("EPUBs scanned ....... %d\n", #kindle_books)
        .. string.format("Matched ............. %d\n", matches.matched)
        .. string.format("Needs review ........ %d\n", matches.ambiguous)
        .. string.format("Not matched ......... %d\n", matches.unmatched)
        .. "\nNothing has been imported or written to KOReader statistics."

    UIManager:show(InfoMessage:new{
        text = text,
    })
end

function ReadingBrain:addToMainMenu(menu_items)
    menu_items.reading_brain = {
        text = _("Reading Brain"),
        sorting_hint = "tools",

        sub_item_table = {
            {
                text = _("Analyze Bookmory Backup"),
                callback = function()
                    self:analyze()
                end,
            },

            {
                text = _("Check for Updates"),
                callback = function()
                    local Updater = loadUpdater()

                    if Updater then
                        Updater:checkForUpdates(
                            PLUGIN_VERSION
                        )
                    end
                end,
            },

            {
                text = _("Restore Previous Version"),
                callback = function()
                    local Updater = loadUpdater()

                    if Updater then
                        Updater:confirmRestore()
                    end
                end,
            },

            {
                text = _("About"),
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text =
                            "Reading Brain v"
                            .. PLUGIN_VERSION
                            .. "\n\n"
                            .. "A read-only experiment for combining Bookmory and KOReader data.\n\n"
                            .. "It does NOT modify KOReader statistics.\n\n"
                            .. "Bookmory backups:\n"
                            .. "/mnt/us/readingbrain/",
                    })
                end,
            },
        },
    }
end

return ReadingBrain
