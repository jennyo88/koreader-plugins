local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ReadingDashboard = WidgetContainer:extend{
    name = "readingdashboard",
    is_doc_only = true,
}

local function safe_call(fn, default)
    local ok, value = pcall(fn)
    if ok and value ~= nil then
        return value
    end
    return default
end

local function percent(value)
    if type(value) ~= "number" then
        return nil
    end
    if value <= 1 then
        value = value * 100
    end
    return math.floor(value + 0.5)
end

function ReadingDashboard:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function ReadingDashboard:getBookTitle()
    local title = safe_call(function()
        if self.ui and self.ui.doc_props and self.ui.doc_props.display_title then
            return self.ui.doc_props.display_title
        end
    end)

    if title and title ~= "" then
        return title
    end

    title = safe_call(function()
        if self.ui and self.ui.document and self.ui.document.info then
            return self.ui.document.info.title
        end
    end)

    if title and title ~= "" then
        return title
    end

    return _("Current book")
end

function ReadingDashboard:getProgress()
    local current_page = safe_call(function()
        return self.ui:getCurrentPage()
    end)

    local page_count = safe_call(function()
        return self.ui.document:getPageCount()
    end)

    if type(current_page) == "number"
        and type(page_count) == "number"
        and page_count > 0 then
        return {
            current_page = current_page,
            page_count = page_count,
            percentage = percent(current_page / page_count),
        }
    end

    local progress = safe_call(function()
        if self.ui and self.ui.document and self.ui.document.getCurrentPos
            and self.ui.document.getFullHeight then
            local pos = self.ui.document:getCurrentPos()
            local full = self.ui.document:getFullHeight()
            if type(pos) == "number" and type(full) == "number" and full > 0 then
                return pos / full
            end
        end
    end)

    if progress then
        return {
            percentage = percent(progress),
        }
    end

    return {}
end

function ReadingDashboard:showDashboard()
    local book_title = self:getBookTitle()
    local progress = self:getProgress()

    local lines = {
        book_title,
        "",
        _("READING PROGRESS"),
    }

    if progress.percentage then
        table.insert(lines, string.format("%d%%", progress.percentage))
    else
        table.insert(lines, _("Progress unavailable"))
    end

    if progress.current_page and progress.page_count then
        table.insert(lines, string.format(
            _("Page %d of %d"),
            progress.current_page,
            progress.page_count
        ))
    end

    table.insert(lines, "")
    table.insert(lines, _("Reading Dashboard v0.1.0"))
    table.insert(lines, _("More statistics are coming next."))

    UIManager:show(InfoMessage:new{
        text = table.concat(lines, "\n"),
    })
end

function ReadingDashboard:addToMainMenu(menu_items)
    menu_items.reading_dashboard = {
        text = _("Reading Dashboard"),
        sorting_hint = "tools",
        callback = function()
            self:showDashboard()
        end,
    }
end

return ReadingDashboard
