-- Minimal Shelf cover gallery: on-demand UI, cache-only cover images.
-- No network requests, no book rendering, no background extraction.
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Button = require("ui/widget/button")
local Font = require("ui/font")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local _ = require("gettext")

local Gallery = {}

-- In normal installations Cover Browser is a bundled KOReader plugin.
-- Use only its already-extracted thumbnails and never render an EPUB here.
local function get_manager()
    local ok, manager = pcall(require, "bookinfomanager")
    if ok then return manager end
    -- On some KOReader builds the bundled plugin directory is not in
    -- package.path until Cover Browser has been initialized.
    local DataStorage = require("datastorage")
    local lfs = require("libs/libkoreader-lfs")
    local fullpath = DataStorage:getDataDir()
        .. "/plugins/coverbrowser.koplugin/bookinfomanager.lua"
    if lfs.attributes(fullpath, "mode") == "file" then
        local loaded, module = pcall(dofile, fullpath)
        if loaded and module then return module end
    end
    return nil
end

local function clipped(s, n)
    s = tostring(s or "")
    if #s > n then return s:sub(1, n - 3) .. "..." end
    return s
end

local function placeholder(book, width, height)
    local label = TextBoxWidget:new{
        text = tostring(book.title or ""),
        face = Font:getFace("cfont", 18),
        width = width - 24,
        height = height - 18,
        height_adjust = true,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    return FrameContainer:new{
        width = width,
        height = height,
        padding = 2,
        bordersize = 1,
        background = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{
            dimen = Geom:new{w = width - 8, h = height - 8},
            label,
        },
    }
end

local function image_for(manager, book, width, height)
    if not manager then return nil end
    local ok, info = pcall(function()
        return manager:getBookInfo(book.path, true)
    end)
    if not ok or not info then return nil end
    if not info.has_cover or info.ignore_cover or not info.cover_bb then
        if info.cover_bb then info.cover_bb:free() end
        return nil
    end
    local w = tonumber(info.cover_w)
    local h = tonumber(info.cover_h)
    if not w or not h or w <= 0 or h <= 0 then
        info.cover_bb:free()
        return nil
    end
    local scale = math.min(1, width / w, height / h)
    local ok_widget, widget = pcall(function()
        return ImageWidget:new{
            image = info.cover_bb,
            scale_factor = scale,
        }
    end)
    if not ok_widget then
        info.cover_bb:free()
        return nil
    end
    return widget
end

local CoverCard = InputContainer:extend{}

function CoverCard:init()
    local padding = Screen:scaleBySize(7)
    local cover_width = math.max(60, self.width - 2 * padding)
    local cover_height = math.max(80, self.height - Screen:scaleBySize(98))
    local visual = image_for(self.manager, self.book, cover_width, cover_height)
        or placeholder(self.book, math.min(cover_width, cover_height * 0.7), cover_height)
    local name = TextBoxWidget:new{
        text = tostring(self.book.title or ""),
        face = Font:getFace("cfont", 18),
        width = cover_width,
        height = Screen:scaleBySize(48),
        height_adjust = true,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    local caption = TextBoxWidget:new{
        text = tostring(self.badge(self.book) or ""),
        face = Font:getFace("cfont", 14),
        width = cover_width,
        height = Screen:scaleBySize(30),
        height_adjust = true,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    local body = VerticalGroup:new{
        CenterContainer:new{
            dimen = Geom:new{w = cover_width, h = cover_height},
            visual,
        },
        VerticalSpan:new{width = Screen:scaleBySize(5)},
        name,
        caption,
    }
    self[1] = FrameContainer:new{
        width = self.width,
        height = self.height,
        padding = padding,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{
            dimen = Geom:new{w = self.width - 2 * padding, h = self.height - 2 * padding},
            body,
        },
    }
    self.dimen = self[1]:getSize()
    self.ges_events = {
        TapSelect = {
            GestureRange:new{ges = "tap", range = self.dimen},
        },
    }
end

function CoverCard:onTapSelect()
    if self.on_open then self.on_open(self.book) end
    return true
end

local GalleryScreen = InputContainer:extend{
    modal = true,
    covers_fullscreen = true,
}

function GalleryScreen:gotoPage(delta)
    local target = self.page + delta
    if target < 1 or target > self.total_pages then return end
    local next_screen = GalleryScreen:new{
        title = self.title,
        books = self.books,
        badge = self.badge,
        on_open = self.on_open,
        on_sections = self.on_sections,
        manager = self.manager,
        page = target,
    }
    UIManager:close(self)
    UIManager:show(next_screen)
end

function GalleryScreen:onClose()
    UIManager:close(self)
    return true
end

function GalleryScreen:init()
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    local pad = Screen:scaleBySize(20)
    local gap = Screen:scaleBySize(12)
    local columns, rows = 2, 2
    local tile_w = math.floor((sw - 2 * pad - gap) / columns)
    local tile_h = math.floor((sh - Screen:scaleBySize(160) - 2 * pad - gap) / rows)
    local perpage = columns * rows
    self.page = self.page or 1
    self.total_pages = math.max(1, math.ceil(#self.books / perpage))

    local head = TextWidget:new{
        text = clipped(self.title, 40),
        face = Font:getFace("cfont", 25),
        bold = true,
    }
    local tiles = {}
    for row_index = 1, rows do
        local row = HorizontalGroup:new{}
        for col_index = 1, columns do
            local index = (self.page - 1) * perpage + (row_index - 1) * columns + col_index
            local book = self.books[index]
            if book then
                row[#row + 1] = CoverCard:new{
                    book = book,
                    width = tile_w,
                    height = tile_h,
                    manager = self.manager,
                    badge = self.badge,
                    on_open = function(selected)
                        UIManager:close(self)
                        self.on_open(selected)
                    end,
                }
            else
                row[#row + 1] = HorizontalSpan:new{width = tile_w}
            end
            if col_index < columns then
                row[#row + 1] = HorizontalSpan:new{width = gap}
            end
        end
        tiles[#tiles + 1] = row
        if row_index < rows then
            tiles[#tiles + 1] = VerticalSpan:new{width = gap}
        end
    end

    local prev = Button:new{
        text = _("Previous"),
        callback = function() self:gotoPage(-1) end,
        enabled = self.page > 1,
    }
    local close = Button:new{
        text = _("Close"),
        callback = function() self:onClose() end,
    }
    local next = Button:new{
        text = _("Next"),
        callback = function() self:gotoPage(1) end,
        enabled = self.page < self.total_pages,
    }
    local footer_items = {
        prev,
        HorizontalSpan:new{width = Screen:scaleBySize(16)},
        TextWidget:new{
            text = string.format("%d / %d", self.page, self.total_pages),
            face = Font:getFace("cfont", 16),
        },
        HorizontalSpan:new{width = Screen:scaleBySize(16)},
        next,
        HorizontalSpan:new{width = Screen:scaleBySize(16)},
    }
    if self.on_sections then
        local sections = Button:new{
            text = _("Sections"),
            callback = function()
                UIManager:close(self)
                self.on_sections()
            end,
        }
        table.insert(footer_items, HorizontalSpan:new{width = Screen:scaleBySize(12)})
        table.insert(footer_items, sections)
    end
    table.insert(footer_items, HorizontalSpan:new{width = Screen:scaleBySize(12)})
    table.insert(footer_items, close)
    local footer = HorizontalGroup:new(footer_items)

    local body = VerticalGroup:new{
        CenterContainer:new{dimen = Geom:new{w = sw - 2 * pad, h = Screen:scaleBySize(48)}, head},
        VerticalSpan:new{width = Screen:scaleBySize(8)},
    }
    for _, item in ipairs(tiles) do body[#body + 1] = item end
    body[#body + 1] = VerticalSpan:new{width = Screen:scaleBySize(12)}
    body[#body + 1] = CenterContainer:new{
        dimen = Geom:new{w = sw - 2 * pad, h = Screen:scaleBySize(60)},
        footer,
    }
    self[1] = FrameContainer:new{
        width = sw,
        height = sh,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{
            dimen = Geom:new{w = sw, h = sh},
            body,
        },
    }
    self.dimen = self[1]:getSize()
end

Gallery.getManager = get_manager

function Gallery.show(title, books, badge, on_open, on_sections)
    if not books or #books == 0 then return false end
    UIManager:show(GalleryScreen:new{
        title = title,
        books = books,
        badge = badge,
        on_open = on_open,
        on_sections = on_sections,
        manager = get_manager(),
    })
    return true
end

return Gallery
