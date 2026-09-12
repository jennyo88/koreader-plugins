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

local function formatTime(seconds)
    if type(seconds) ~= "number" then
        return nil
    end

    seconds = math.floor(seconds + 0.5)

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

function ReadingDashboard:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function ReadingDashboard:getBookTitle()
    local title = safe_call(function()
        if self.ui
            and self.ui.doc_props
            and self.ui.doc_props.display_title then
            return self.ui.doc_props.display_title
        end
    end)

    if title and title ~= "" then
        return title
    end

    title = safe_call(function()
        if self.ui
            and self.ui.document
            and self.ui.document.info then
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
            pages_remaining = math.max(page_count - current_page, 0),
        }
    end

    return {}
end

function ReadingDashboard:getStatistics()
    local stats = self.ui and self.ui.statistics

    if not stats then
        return {}
    end

    local book_read_time = tonumber(stats.book_read_time)
    local book_read_pages = tonumber(stats.book_read_pages)
    local avg_time = tonumber(stats.avg_time)

    -- Include reading data still held in memory during the current session.
    local mem_read_time = tonumber(stats.mem_read_time) or 0
    local mem_read_pages = tonumber(stats.mem_read_pages) or 0

    if book_read_time then
        book_read_time = book_read_time + mem_read_time
    end

    if book_read_pages then
        book_read_pages = book_read_pages + mem_read_pages
    end

    -- Recalculate average from the latest available values when possible.
    if book_read_time
        and book_read_pages
        and book_read_pages > 0 then
        avg_time = book_read_time / book_read_pages
    end

    return {
        book_read_time = book_read_time,
        book_read_pages = book_read_pages,
        avg_time = avg_time,
    }
end

function ReadingDashboard:showDashboard()
    local book_title = self:getBookTitle()
    local progress = self:getProgress()
    local stats = self:getStatistics()

    local lines = {
        book_title,
        "",
        _("PROGRESS"),
    }

    if progress.percentage
        and progress.current_page
        and progress.page_count then

        table.insert(
            lines,
            string.format(
                _("%d%%   •   Page %d of %d"),
                progress.percentage,
                progress.current_page,
                progress.page_count
            )
        )

    elseif progress.percentage then
        table.insert(
            lines,
            string.format(
                _("%d%%"),
                progress.percentage
            )
        )
    else
        table.insert(lines, _("Progress unavailable"))
    end

    if progress.pages_remaining then
        table.insert(
            lines,
            string.format(
                _("%d pages remaining"),
                progress.pages_remaining
            )
        )
    end

    table.insert(lines, "")
    table.insert(lines, _("READING"))

    if stats.book_read_time then
        table.insert(
            lines,
            string.format(
                _("Time read        %s"),
                formatTime(stats.book_read_time)
            )
        )
    end

    if stats.avg_time then
        table.insert(
            lines,
            string.format(
                _("Avg. per page    %s"),
                formatTime(stats.avg_time)
            )
        )
    end

    if stats.avg_time and progress.pages_remaining then
        local estimated_remaining =
            stats.avg_time * progress.pages_remaining

        table.insert(
            lines,
            string.format(
                _("Time remaining   %s"),
                formatTime(estimated_remaining)
            )
        )
    end

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
