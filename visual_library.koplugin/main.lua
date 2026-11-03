-- Visual Library for KOReader, initial public prototype.
-- This plugin does not replace or modify Bookshelf's data.
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local Catalog = require("catalog")
local Moods = require("moods")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")

local settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/visual_library.lua")
local active_instance, active_screen
local boot_seen = false
local return_from_book = false
local patch_installed = false

local VisualLibrary = WidgetContainer:extend{ name = "visual_library", is_doc_only = false }

local function close_screen()
    if active_screen then
        local screen = active_screen
        active_screen = nil
        UIManager:close(screen)
    end
end

local function save(key, value)
    settings:saveSetting(key, value)
    settings:flush()
end

local function start_menu_hook()
    if patch_installed then return end
    local ok, FMMenu = pcall(require, "apps/filemanager/filemanagermenu")
    if not ok or type(FMMenu.getStartWithMenuTable) ~= "function" then return end
    patch_installed = true
    local original = FMMenu.getStartWithMenuTable
    FMMenu.getStartWithMenuTable = function(menu)
        local result = original(menu)
        if type(result) ~= "table" or type(result.sub_item_table) ~= "table" then return result end
        -- KOReader's default label only knows about its built-in startup options.
        -- Reflect our additional selection in the parent menu label as well.
        local original_text_func = result.text_func
        result.text_func = function(...)
            if G_reader_settings:readSetting("start_with") == "visual_library" then
                return _("Start with: visual library")
            end
            return original_text_func and original_text_func(...) or _("Start with")
        end
        for _, entry in ipairs(result.sub_item_table) do
            if entry._visual_library then return result end
            local callback = entry.callback
            if callback and not entry._visual_wrapped then
                entry._visual_wrapped = true
                entry.callback = function(...)
                    callback(...)
                    if G_reader_settings:readSetting("start_with") ~= "visual_library" then close_screen() end
                end
            end
        end
        table.insert(result.sub_item_table, {
            text = _("visual library"), radio = true, _visual_library = true,
            checked_func = function()
                return G_reader_settings:readSetting("start_with") == "visual_library"
            end,
            callback = function(touchmenu)
                G_reader_settings:saveSetting("start_with", "visual_library")
                G_reader_settings:flush()
                if touchmenu and touchmenu.closeMenu then touchmenu:closeMenu() end
                UIManager:nextTick(function()
                    if active_instance then active_instance:showVisual("home") end
                end)
            end,
        })
        return result
    end
end

function VisualLibrary:init()
    if self.ui and not self.ui.document then
        active_instance = self
        self.ui.menu:registerToMainMenu(self)
        start_menu_hook()
        -- The FileManager finishes constructing itself before the callback runs.
        if self.ui.registerPostInitCallback then
            self.ui:registerPostInitCallback(function()
                local should_boot = not boot_seen and G_reader_settings:readSetting("start_with") == "visual_library"
                boot_seen = true
                local should_return = return_from_book
                return_from_book = false
                if should_boot or should_return then
                    UIManager:nextTick(function()
                        if active_instance == self then self:showVisual("home") end
                    end)
                end
            end)
        end
    end
end

function VisualLibrary:addToMainMenu(items)
    if self.ui.document then return end
    items.visual_library = {
        text = _("Visual Library"),
        sub_item_table = {
            { text = _("Open Visual Library"), callback = function() self:showVisual("home") end },
            { text = _("Mood Picker"), callback = function() self:showVisual("moods") end },
            { text = _("Reading queue"), callback = function() self:showVisual("queue") end },
            { text = _("Refresh EPUB catalog"), callback = function()
                self._catalog = nil
                self:loadCatalog(true)
                UIManager:show(require("ui/widget/infomessage"):new{ text = _("Visual Library catalog refreshed.") })
            end },
        },
    }
end

function VisualLibrary:loadCatalog(force)
    if self._catalog and not force then return self._catalog end
    local root = settings:readSetting("root_dir") or G_reader_settings:readSetting("home_dir")
    if not root or lfs.attributes(root, "mode") ~= "directory" then
        root = (self.ui and self.ui.file_chooser and self.ui.file_chooser.path) or "/mnt/us/documents"
    end
    local books = Catalog.scan(root, 900)
    local last = G_reader_settings:readSetting("lastfile")
    if Catalog.exists(last) then
        local found = false
        for _, b in ipairs(books) do if b.path == last then found = true; break end end
        if not found then books[#books + 1] = {path = last, title = Catalog.fallback_title(last)} end
    end
    -- Cover Browser normally loads this module from its own package path.
    local ok, bim = pcall(require, "bookinfomanager")
    self._bookinfo = ok and bim or nil
    Catalog.enrich(books, self._bookinfo)
    self._catalog = books
    self._root = root
    return books
end

function VisualLibrary:showVisual(page)
    if not (self.ui and not self.ui.document) then return end
    self:loadCatalog()
    close_screen()
    local screen_ui = require("visualui")
    local widget = screen_ui:new{ plugin = self, page = page or "home", settings = settings,
        catalog = self._catalog, bookinfo = self._bookinfo }
    active_screen = widget
    UIManager:show(widget)
end

function VisualLibrary:openBook(path)
    if not Catalog.exists(path) then
        UIManager:show(require("ui/widget/infomessage"):new{ text = _("Book file not found. Refresh the library.") })
        return
    end
    close_screen()
    return_from_book = true
    local ReaderUI = require("apps/reader/readerui")
    ReaderUI:showReader(path)
end

-- Exposed for the UI and tests.
function VisualLibrary:getStore() return settings end
function VisualLibrary:getMoods() return Moods end
function VisualLibrary:closeVisual() close_screen() end
return VisualLibrary
