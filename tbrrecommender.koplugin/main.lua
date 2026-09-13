local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")

local PLUGIN_VERSION = "0.1.3"

local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("(.+)/[^/]+$")
if plugin_dir and plugin_dir:sub(1, 1) ~= "/" then
    plugin_dir = "/mnt/us/koreader/" .. plugin_dir
end
plugin_dir = plugin_dir or "/mnt/us/koreader/plugins/tbrrecommender.koplugin"

local Library = dofile(plugin_dir .. "/library.lua")
local Recommender = dofile(plugin_dir .. "/recommender.lua")

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

local TBRRecommender = WidgetContainer:extend{
    name = "tbrrecommender",
    is_doc_only = false,
}

local function title_for(book)
    return book.title
        or (book.filename and book.filename:gsub("%.epub$", ""))
        or "Unknown title"
end

local function author_for(book)
    if type(book.authors) == "string" then
        return book.authors
    elseif type(book.authors) == "table" then
        return table.concat(book.authors, ", ")
    end
    return nil
end

local function details_for(book)
    local bits = {}
    local author = author_for(book)

    if author and author ~= "" then
        table.insert(bits, author)
    end

    if book.pages then
        table.insert(bits, tostring(book.pages) .. " pages")
    end

    if book.series and book.series ~= "" then
        local series = book.series
        if book.series_index then
            series = series .. " #" .. tostring(book.series_index)
        end
        table.insert(bits, series)
    end

    if book.recommendation_note
        and book.recommendation_note ~= "" then

        table.insert(
            bits,
            book.recommendation_note
        )
    end

    if not book.been_opened then
        table.insert(bits, "Unopened")
    end

    return table.concat(bits, " • ")
end

local function button_text_for(book)
    local title = title_for(book)
    local details = details_for(book)

    if details ~= "" then
        return title .. "\n" .. details
    end

    return title
end

function TBRRecommender:init()
    self.recommendation_dialog = nil
    self.last_mode = nil

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function TBRRecommender:getBooks()
    return Library:getCandidates("/mnt/us/koreader/books")
end

function TBRRecommender:closeRecommendationDialog()
    if self.recommendation_dialog then
        UIManager:close(self.recommendation_dialog)
        self.recommendation_dialog = nil
    end
end

function TBRRecommender:openBook(book)
    if not book or not book.file then
        UIManager:show(InfoMessage:new{
            text = _("Could not find this book's file."),
        })
        return
    end

    self:closeRecommendationDialog()

    local ok, err = pcall(function()
        filemanagerutil.openFile(
            self.ui,
            book.file,
            nil,
            true
        )
    end)

    if not ok then
        UIManager:show(InfoMessage:new{
            text = _("Could not open the selected book.")
                .. "\n\n"
                .. tostring(err),
        })
    end
end

function TBRRecommender:pickAgain()
    self:closeRecommendationDialog()

    if self.last_mode then
        self:runMode(self.last_mode)
    end
end

function TBRRecommender:showRecommendations(header, books)
    if not books or #books == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No matching unread books were found."),
        })
        return
    end

    local buttons = {}

    for _, book in ipairs(books) do
        local selected_book = book

        table.insert(buttons, {
            {
                text = button_text_for(selected_book),
                callback = function()
                    self:openBook(selected_book)
                end,
            },
        })
    end

    table.insert(buttons, {
        {
            text = _("Pick Again"),
            callback = function()
                self:pickAgain()
            end,
        },
        {
            text = _("Close"),
            callback = function()
                self:closeRecommendationDialog()
            end,
        },
    })

    self.recommendation_dialog = ButtonDialog:new{
        title = header .. "\n" .. _("Tap a book to open it"),
        title_align = "center",
        buttons = buttons,
    }

    UIManager:show(self.recommendation_dialog)
end

function TBRRecommender:runMode(mode)
    self.last_mode = mode

    local books = self:getBooks()

    if #books == 0 and mode ~= "series" then
        UIManager:show(InfoMessage:new{
            text = _("No unread EPUBs were found in /mnt/us/koreader/books."),
        })
        return
    end

    if mode == "surprise" then
        self:showRecommendations(
            _("SURPRISE ME"),
            Recommender:surpriseMe(books, 3)
        )
    elseif mode == "quick" then
        self:showRecommendations(
            _("QUICK READ"),
            Recommender:quickRead(books, 3)
        )
    elseif mode == "series" then
        local all_books =
            Library:getAllBooks(
                "/mnt/us/koreader/books"
            )

        self:showRecommendations(
            _("CONTINUE A SERIES"),
            Recommender:continueSeries(
                all_books,
                3
            )
        )
    elseif mode == "unopened" then
        self:showRecommendations(
            _("UNOPENED BOOKS"),
            Recommender:unopened(books, 3)
        )
    end
end

function TBRRecommender:addToMainMenu(menu_items)
    menu_items.tbr_recommender = {
        text = _("TBR Recommender"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Surprise Me"),
                callback = function()
                    self:runMode("surprise")
                end,
            },
            {
                text = _("Quick Read"),
                callback = function()
                    self:runMode("quick")
                end,
            },
            {
                text = _("Continue a Series"),
                callback = function()
                    self:runMode("series")
                end,
            },
            {
                text = _("Unopened Books"),
                callback = function()
                    self:runMode("unopened")
                end,
            },
            {
                text = _("Check for Updates"),
                callback = function()
                    local Updater = loadUpdater()
                    if Updater then
                        Updater:checkForUpdates(PLUGIN_VERSION)
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
                        text = "TBR Recommender"
                            .. "\n\nVersion "
                            .. PLUGIN_VERSION
                            .. "\n\nScans:"
                            .. "\n/mnt/us/koreader/books"
                            .. "\n\nTap a recommendation to open it directly."
                            .. "\nUse Pick Again for another set of three.",
                    })
                end,
            },
        },
    }
end

return TBRRecommender
