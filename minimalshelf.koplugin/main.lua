-- Minimal Shelf: Kindle Paperwhite 3 oriented, offline by default.
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local _ = require("gettext")
local version = "0.3.0"

local MinimalShelf = WidgetContainer:extend{
    name = "minimalshelf",
    is_doc_only = false,
}

local function message(s)
    UIManager:show(InfoMessage:new{ text = s })
end

function MinimalShelf:init()
    -- pluginloader supplies self.path before the instance is initialized.
    local root = self.path or "plugins/minimalshelf.koplugin"
    self.Catalog = dofile(root .. "/catalog.lua")
    self.Catalog.CalibrePages = dofile(root .. "/calibre_pages.lua")
    self.Series = dofile(root .. "/series.lua")
    self.Gallery = dofile(root .. "/covergallery.lua")
    self.Updater = dofile(root .. "/updater.lua")
    local Notifier = dofile(root .. "/update_notifier.lua")
    self.notifier = Notifier:new{ plugin_id = "minimalshelf", plugin_name = "Minimal Shelf", current_version = version }
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/minimalshelf_settings.lua")
    self.books = self.settings:readSetting("cached_books") or {}
    self.ui.menu:registerToMainMenu(self)
end

function MinimalShelf:onWake()
    if self.notifier then self.notifier:onWake() end
end

function MinimalShelf:libraryRoot()
    return self.settings:readSetting("library_root")
        or G_reader_settings:readSetting("home_dir")
        or "/mnt/us/documents"
end

-- Menu is the built-in fullscreen KOReader list widget, not a cover-art grid.
function MinimalShelf:showMenu(title, entries)
    local view = Menu:new{ title = title, item_table = entries, items_per_page = 8 }
    function view:onMenuSelect(item)
        if item.callback then item.callback() end
    end
    function view:onMenuHold(item)
        if item.callback then item.callback() end
    end
    UIManager:show(view)
    return view
end

function MinimalShelf:openBook(book)
    local function open()
        if self.ui.document and self.ui.switchDocument then
            self.ui:switchDocument(book.path)
        else
            local FileManager = require("apps/filemanager/filemanager")
            FileManager:openFile(book.path)
        end
    end
    local ok, err = pcall(open)
    if not ok then message(_("Could not open book: ") .. tostring(err)) end
end

function MinimalShelf:bookList(title, books)
    -- Default to the cover gallery; keep the native text menu as a fallback.
    if #books > 0 and not self.settings:isTrue("text_lists") then
        local ok, rendered = pcall(function()
            return self.Gallery.show(title, books, self.Series.badge,
                function(book) self:openBook(book) end)
        end)
        if ok and rendered then return end
        message(_("Cover view unavailable. Showing titles instead."))
    end
    local entries = {}
    for _, book in ipairs(books or {}) do
        local item = book
        entries[#entries + 1] = {
            text = item.title .. "\n" .. self.Series.badge(item),
            callback = function() self:openBook(item) end,
        }
    end
    if #entries == 0 then
        entries[1] = {text = _("No matching books. Refresh the library from Settings.")}
    end
    self:showMenu(title, entries)
end

function MinimalShelf:showSeries()
    local groups = self.Series.group(self.books)
    local entries = {}
    for _, group in ipairs(groups) do
        local current = group
        entries[#entries + 1] = {
            text = current.name .. "  (" .. tostring(#current.books) .. ")",
            callback = function() self:bookList(current.name, current.books) end,
        }
    end
    if #entries == 0 then entries[1] = { text = _("No series metadata found yet.") } end
    self:showMenu(_("Book series"), entries)
end

function MinimalShelf:showNext()
    local suggestions = self.Series.next(self.books)
    if not self.settings:isTrue("text_lists") then
        local books = {}
        for _, item in ipairs(suggestions) do
            books[#books + 1] = item.book
        end
        if #books > 0 then
            local ok, rendered = pcall(function()
                return self.Gallery.show(_("Next in series"), books, self.Series.badge,
                    function(book) self:openBook(book) end)
            end)
            if ok and rendered then return end
        end
    end
    local entries = {}
    for _, suggestion in ipairs(self.Series.next(self.books)) do
        local item = suggestion
        local warning = item.missing and ("  [missing #" .. item.missing .. "]") or ""
        entries[#entries + 1] = {
            text = item.group .. warning .. "\n" .. item.book.title .. "  " .. self.Series.badge(item.book),
            callback = function() self:openBook(item.book) end,
        }
    end
    if #entries == 0 then entries[1] = {text = _("No next-in-series suggestions.")} end
    self:showMenu(_("Next in series"), entries)
end

function MinimalShelf:showShort()
    local limit = tonumber(self.settings:readSetting("short_limit")) or 100
    local remaining = self.settings:isTrue("short_remaining")
    self:bookList((remaining and _("Pages left: ") or _("Total pages: ")) .. tostring(limit),
        self.Series.short(self.books, limit, remaining))
end

function MinimalShelf:refreshLibrary(pages_only)
    local root = self:libraryRoot()
    UIManager:show(ConfirmBox:new{
        text = (pages_only
            and _("Extract available page counts now? Saved KOReader pagination takes priority, then Calibre #pages metadata, then fixed-layout pages.")
            or _("Refresh the library now?"))
            .. "\n\n" .. _("Offline scan only. This will not open books or turn on Wi-Fi.")
            .. "\n\n" .. root,
        ok_text = pages_only and _("Extract") or _("Scan"),
        ok_callback = function()
            local books, err, counts = self.Catalog.scan(root, 400)
            if not books then message(err) return end
            self.books = books
            self.settings:saveSetting("cached_books", books)
            self.settings:flush()
            message(string.format(
                _("Indexed %d books.\n\nKOReader pages: %d\nCalibre pages: %d\nDocument pages: %d\nUnknown: %d"),
                #books, counts.screen, counts.calibre, counts.document, counts.unknown
            ))
        end,
    })
end

function MinimalShelf:showPageCounts()
    local ordered = {}
    for _, book in ipairs(self.books) do ordered[#ordered + 1] = book end
    table.sort(ordered, function(a, b)
        local ap, bp = a.total_pages or math.huge, b.total_pages or math.huge
        if ap ~= bp then return ap < bp end
        return a.title:lower() < b.title:lower()
    end)
    self:bookList(_("Page counts (layout / Calibre)"), ordered)
end

function MinimalShelf:chooseFolder()
    local PathChooser = require("ui/widget/pathchooser")
    UIManager:show(PathChooser:new{
        select_directory = true,
        path = self:libraryRoot(),
        onConfirm = function(path)
            self.settings:saveSetting("library_root", path)
            self.settings:flush()
            message(_("Library folder saved. Select Refresh library to scan it."))
        end,
    })
end

function MinimalShelf:extractCovers()
    local manager = self.Gallery.getManager()
    if not manager then
        message(_("Enable KOReader's bundled Cover Browser plugin, then restart KOReader to extract cover thumbnails."))
        return
    end
    -- Cover Browser presents its own extraction confirmation and offers
    -- recursive scanning. This is deliberately never run automatically.
    local Trapper = require("ui/trapper")
    Trapper:wrap(function()
        manager:extractBooksInDirectory(self:libraryRoot())
    end)
end

function MinimalShelf:showSettings()
    local limit = tonumber(self.settings:readSetting("short_limit")) or 100
    local remaining = self.settings:isTrue("short_remaining")
    self:showMenu(_("Minimal Shelf settings"), {
        { text = _("Refresh library (offline)"), callback = function() self:refreshLibrary(false) end },
        { text = _("Extract page counts (offline)"), callback = function() self:refreshLibrary(true) end },
        { text = _("Extract book covers (manual, offline)"), callback = function()
            self:extractCovers()
        end },
        { text = _("Choose library folder"), callback = function() self:chooseFolder() end },
        { text = _("Short-read cutoff: ") .. limit .. _(" pages"), callback = function()
            local new_limit = (limit == 75 and 100) or (limit == 100 and 150) or 75
            self.settings:saveSetting("short_limit", new_limit)
            self.settings:flush()
            message(string.format(_("Short-read limit: %d pages. Reopen settings to see the new value."), new_limit))
        end },
        { text = _("Short reads by: ") .. (remaining and _("pages left") or _("total pages")), callback = function()
            self.settings:saveSetting("short_remaining", not remaining)
            self.settings:flush()
            message(_("Updated. Reopen settings to see the new value."))
        end },
        { text = self.settings:isTrue("text_lists")
              and _("Book display: Text lists") or _("Book display: Covers"),
          callback = function()
            self.settings:saveSetting("text_lists", not self.settings:isTrue("text_lists"))
            self.settings:flush()
            message(_("Book display changed. Reopen a book list to see it."))
        end },
        { text = _("Check for updates (manual Wi-Fi)"), callback = function()
            self.Updater:checkForUpdates(version)
        end },
        { text = _("Restore previous version"), callback = function()
            self.Updater:confirmRestore()
        end },
    })
end

-- Prefer books already in progress, then next volumes, then the rest.
-- No additional scanning occurs when the home screen opens.
function MinimalShelf:homeBooks()
    local featured, seen = {}, {}
    local function append(book)
        if book and not seen[book.path] and book.status ~= "complete" then
            featured[#featured + 1] = book
            seen[book.path] = true
        end
    end
    for _, book in ipairs(self.books) do
        if book.status == "reading" then append(book) end
    end
    for _, suggestion in ipairs(self.Series.next(self.books)) do
        append(suggestion.book)
    end
    for _, book in ipairs(self.Series.short(self.books,
            tonumber(self.settings:readSetting("short_limit")) or 100, false)) do
        append(book)
    end
    for _, book in ipairs(self.books) do append(book) end
    return featured
end

function MinimalShelf:showHome()
    if #self.books > 0 and not self.settings:isTrue("text_lists") then
        local ok, rendered = pcall(function()
            return self.Gallery.show(_("Minimal Shelf"), self:homeBooks(),
                self.Series.badge,
                function(book) self:openBook(book) end,
                function() self:showSectionsMenu() end)
        end)
        if ok and rendered then return end
    end
    self:showSectionsMenu()
end

function MinimalShelf:showSectionsMenu()
    local reading = {}
    for _, book in ipairs(self.books) do
        if book.status == "reading" then reading[#reading + 1] = book end
    end
    local root = self:libraryRoot()
    self:showMenu("Minimal Shelf  " .. version, {
        { text = _("Continue reading") .. "  (" .. #reading .. ")", callback = function()
            self:bookList(_("Continue reading"), reading)
        end },
        { text = _("Next in series"), callback = function() self:showNext() end },
        { text = _("Book series"), callback = function() self:showSeries() end },
        { text = _("Short reads"), callback = function() self:showShort() end },
        { text = _("Page counts"), callback = function() self:showPageCounts() end },
        { text = _("All indexed books") .. "  (" .. #self.books .. ")", callback = function()
            self:bookList(_("All indexed books"), self.books)
        end },
        { text = _("Settings & updates"), callback = function() self:showSettings() end },
        { text = #self.books == 0 and (_("First time? Refresh library") .. "\n" .. root)
              or (_("Library folder: ") .. root), callback = function() self:refreshLibrary() end },
    })
end

function MinimalShelf:addToMainMenu(menu_items)
    menu_items.minimalshelf = {
        text = _("Minimal Shelf"),
        sorting_hint = "more_tools",
        callback = function() self:showHome() end,
    }
end

return MinimalShelf
