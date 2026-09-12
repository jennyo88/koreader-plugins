local PLUGIN_VERSION = "0.5.0"

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Screen = Device.screen


-- ---------------------------------------------------------
-- Locate plugin directory
-- ---------------------------------------------------------

local source = debug.getinfo(1, "S").source

if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("(.+)/[^/]+$")

-- KOReader may report plugin paths relative to /mnt/us/koreader.
if plugin_dir and plugin_dir:sub(1, 1) ~= "/" then
    plugin_dir = "/mnt/us/koreader/" .. plugin_dir
end

-- Final fallback for Kindle.
if not plugin_dir then
    plugin_dir =
        "/mnt/us/koreader/plugins/readingdashboard.koplugin"
end


local function loadUpdater()
    local updater_path =
        plugin_dir .. "/updater.lua"

    local file = io.open(updater_path, "r")

    if not file then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Updater file was not found.\n\n"
                    .. updater_path
                    .. "\n\n"
                    .. "Run the installer again to install updater.lua.",
            }
        )

        return nil
    end

    file:close()

    local ok, updater_or_error =
        pcall(
            dofile,
            updater_path
        )

    if not ok then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Updater could not be loaded.\n\n"
                    .. tostring(updater_or_error),
            }
        )

        return nil
    end

    return updater_or_error
end


-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

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

    local hours =
        math.floor(seconds / 3600)

    local minutes =
        math.floor(
            (seconds % 3600) / 60
        )

    local secs =
        seconds % 60

    if hours > 0 then
        return string.format(
            "%dh %02dm",
            hours,
            minutes
        )

    elseif minutes > 0 then
        return string.format(
            "%dm %02ds",
            minutes,
            secs
        )

    else
        return string.format(
            "%ds",
            secs
        )
    end
end


-- ---------------------------------------------------------
-- Progress bar
-- ---------------------------------------------------------

local ProgressBar =
    WidgetContainer:extend{
        percentage = 0,
        width = 300,
        height = 12,
    }


function ProgressBar:init()

    local progress =
        math.max(
            0,
            math.min(
                self.percentage or 0,
                100
            )
        )

    local inner_width =
        self.width - 4

    local filled_width =
        math.floor(
            inner_width
            * progress
            / 100
        )

    local empty_width =
        inner_width
        - filled_width

    local group =
        HorizontalGroup:new{}


    if filled_width > 0 then
        table.insert(
            group,

            LineWidget:new{
                background =
                    Blitbuffer.COLOR_BLACK,

                dimen =
                    Geom:new{
                        w = filled_width,
                        h = self.height - 4,
                    },
            }
        )
    end


    if empty_width > 0 then
        table.insert(
            group,

            LineWidget:new{
                background =
                    Blitbuffer.COLOR_LIGHT_GRAY,

                dimen =
                    Geom:new{
                        w = empty_width,
                        h = self.height - 4,
                    },
            }
        )
    end


    self[1] =
        FrameContainer:new{
            bordersize =
                Screen:scaleBySize(1),

            padding =
                Screen:scaleBySize(1),

            background =
                Blitbuffer.COLOR_WHITE,

            group,
        }
end


-- ---------------------------------------------------------
-- Dashboard popup
-- ---------------------------------------------------------

local DashboardDialog =
    InputContainer:extend{

        title = "",

        percentage = 0,

        current_page = nil,
        page_count = nil,
        pages_remaining = nil,

        time_read = nil,
        average_time = nil,
        time_remaining = nil,
    }


function DashboardDialog:init()

    local screen_width =
        Screen:getWidth()

    local card_width =
        math.floor(
            screen_width * 0.82
        )

    local content_width =
        card_width
        - Screen:scaleBySize(48)


    -- -----------------------------------------------------
    -- Fonts
    -- -----------------------------------------------------

    local title_face =
        Font:getFace(
            "cfont",
            24
        )

    local percent_face =
        Font:getFace(
            "cfont",
            44
        )

    local section_face =
        Font:getFace(
            "cfont",
            16
        )

    local stat_face =
        Font:getFace(
            "cfont",
            18
        )

    local small_face =
        Font:getFace(
            "cfont",
            15
        )


    -- -----------------------------------------------------
    -- Book title
    -- -----------------------------------------------------

    local title_widget =
        TextBoxWidget:new{
            text = self.title,

            face =
                title_face,

            width =
                content_width,

            alignment =
                "center",

            bold = true,
        }


    -- -----------------------------------------------------
    -- Percentage
    -- -----------------------------------------------------

    local percentage_widget =
        TextWidget:new{
            text =
                string.format(
                    "%d%%",
                    self.percentage or 0
                ),

            face =
                percent_face,

            bold = true,
        }


    -- -----------------------------------------------------
    -- Progress bar
    -- -----------------------------------------------------

    local progress_bar =
        ProgressBar:new{

            percentage =
                self.percentage or 0,

            width =
                math.floor(
                    content_width * 0.82
                ),

            height =
                Screen:scaleBySize(14),
        }


    -- -----------------------------------------------------
    -- Page information
    -- -----------------------------------------------------

    local page_text = ""

    if self.current_page
        and self.page_count then

        page_text =
            string.format(
                _("Page %d of %d"),
                self.current_page,
                self.page_count
            )
    end


    local page_widget =
        TextWidget:new{
            text =
                page_text,

            face =
                small_face,
        }


    local remaining_text = ""

    if self.pages_remaining then
        remaining_text =
            string.format(
                _("%d pages remaining"),
                self.pages_remaining
            )
    end


    local remaining_widget =
        TextWidget:new{
            text =
                remaining_text,

            face =
                small_face,
        }


    -- -----------------------------------------------------
    -- Stat row helper
    -- -----------------------------------------------------

    local function statRow(
        label,
        value
    )

        local label_widget =
            TextWidget:new{
                text =
                    label,

                face =
                    stat_face,
            }


        local value_widget =
            TextWidget:new{
                text =
                    value or "—",

                face =
                    stat_face,

                bold = true,
            }


        local spacing =
            content_width
            - label_widget:getSize().w
            - value_widget:getSize().w


        if spacing < 0 then
            spacing = 0
        end


        return
            HorizontalGroup:new{

                label_widget,

                HorizontalSpan:new{
                    width =
                        spacing,
                },

                value_widget,
            }
    end


    -- -----------------------------------------------------
    -- Reading section
    -- -----------------------------------------------------

    local reading_header =
        TextWidget:new{
            text =
                _("READING"),

            face =
                section_face,

            bold = true,
        }


    local divider =
        LineWidget:new{
            background =
                Blitbuffer.COLOR_DARK_GRAY,

            dimen =
                Geom:new{
                    w =
                        content_width,

                    h =
                        Screen:scaleBySize(1),
                },
        }


    local time_read_row =
        statRow(
            _("Time read"),
            self.time_read
        )


    local average_row =
        statRow(
            _("Avg. per page"),
            self.average_time
        )


    local remaining_row =
        statRow(
            _("Time remaining"),
            self.time_remaining
        )


    -- -----------------------------------------------------
    -- Tap hint
    -- -----------------------------------------------------

    local close_hint =
        TextWidget:new{
            text =
                _("Tap to close"),

            face =
                small_face,

            fgcolor =
                Blitbuffer.COLOR_DARK_GRAY,
        }


    -- -----------------------------------------------------
    -- Main layout
    -- -----------------------------------------------------

    local content =
        VerticalGroup:new{

            align =
                "center",

            title_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(22),
            },

            percentage_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(12),
            },

            progress_bar,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(10),
            },

            page_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(4),
            },

            remaining_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(28),
            },

            reading_header,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(6),
            },

            divider,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(14),
            },

            time_read_row,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(10),
            },

            average_row,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(10),
            },

            remaining_row,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(24),
            },

            close_hint,
        }


    local card =
        FrameContainer:new{

            padding =
                Screen:scaleBySize(24),

            bordersize =
                Screen:scaleBySize(2),

            radius =
                Size.radius.window,

            background =
                Blitbuffer.COLOR_WHITE,

            content,
        }


    self.card =
        card


    self[1] =
        CenterContainer:new{

            dimen =
                Screen:getSize(),

            card,
        }


    -- Tap anywhere to close.

    self.ges_events.Tap = {
        GestureRange:new{
            ges =
                "tap",

            range =
                Geom:new{
                    x = 0,
                    y = 0,

                    w =
                        Screen:getWidth(),

                    h =
                        Screen:getHeight(),
                },
        },
    }
end


function DashboardDialog:onTap()

    UIManager:close(
        self
    )

    return true
end


function DashboardDialog:onShow()

    UIManager:setDirty(
        self,

        function()
            return
                "flashui",
                self.card.dimen
        end
    )
end


function DashboardDialog:onCloseWidget()

    UIManager:setDirty(
        nil,

        function()
            return
                "ui",
                self.card.dimen
        end
    )
end


-- ---------------------------------------------------------
-- Plugin
-- ---------------------------------------------------------

local ReadingDashboard =
    WidgetContainer:extend{

        name =
            "readingdashboard",

        is_doc_only =
            true,
    }


-- ---------------------------------------------------------
-- Dispatcher action
-- ---------------------------------------------------------

function ReadingDashboard:onDispatcherRegisterActions()

    Dispatcher:registerAction(

        "reading_dashboard_open",

        {
            category =
                "none",

            event =
                "OpenReadingDashboard",

            title =
                _("Open Reading Dashboard"),

            general =
                true,
        }
    )
end


-- ---------------------------------------------------------
-- Init
-- ---------------------------------------------------------

function ReadingDashboard:init()

    self:onDispatcherRegisterActions()

    if self.ui
        and self.ui.menu then

        self.ui.menu:registerToMainMenu(
            self
        )
    end
end


-- ---------------------------------------------------------
-- Gesture / dispatcher handler
-- ---------------------------------------------------------

function ReadingDashboard:onOpenReadingDashboard()

    self:showDashboard()

    return true
end


-- ---------------------------------------------------------
-- Book title
-- ---------------------------------------------------------

function ReadingDashboard:getBookTitle()

    local title =
        safe_call(
            function()

                if self.ui
                    and self.ui.doc_props
                    and self.ui.doc_props.display_title then

                    return
                        self.ui.doc_props.display_title
                end
            end
        )


    if title
        and title ~= "" then

        return title
    end


    title =
        safe_call(
            function()

                if self.ui
                    and self.ui.document
                    and self.ui.document.info then

                    return
                        self.ui.document.info.title
                end
            end
        )


    if title
        and title ~= "" then

        return title
    end


    return
        _("Current book")
end


-- ---------------------------------------------------------
-- Reading progress
-- ---------------------------------------------------------

function ReadingDashboard:getProgress()

    local current_page =
        safe_call(
            function()
                return
                    self.ui:getCurrentPage()
            end
        )


    local page_count =
        safe_call(
            function()
                return
                    self.ui.document:getPageCount()
            end
        )


    if type(current_page) == "number"
        and type(page_count) == "number"
        and page_count > 0 then

        return {

            current_page =
                current_page,

            page_count =
                page_count,

            percentage =
                percent(
                    current_page
                    / page_count
                ),

            pages_remaining =
                math.max(
                    page_count
                    - current_page,

                    0
                ),
        }
    end


    return {}
end


-- ---------------------------------------------------------
-- Reading statistics
-- ---------------------------------------------------------

function ReadingDashboard:getStatistics()

    local stats =
        self.ui
        and self.ui.statistics


    if not stats then
        return {}
    end


    local book_read_time =
        tonumber(
            stats.book_read_time
        )


    local book_read_pages =
        tonumber(
            stats.book_read_pages
        )


    local avg_time =
        tonumber(
            stats.avg_time
        )


    local mem_read_time =
        tonumber(
            stats.mem_read_time
        ) or 0


    local mem_read_pages =
        tonumber(
            stats.mem_read_pages
        ) or 0


    if book_read_time then
        book_read_time =
            book_read_time
            + mem_read_time
    end


    if book_read_pages then
        book_read_pages =
            book_read_pages
            + mem_read_pages
    end


    if book_read_time
        and book_read_pages
        and book_read_pages > 0 then

        avg_time =
            book_read_time
            / book_read_pages
    end


    return {

        book_read_time =
            book_read_time,

        book_read_pages =
            book_read_pages,

        avg_time =
            avg_time,
    }
end


-- ---------------------------------------------------------
-- Show dashboard
-- ---------------------------------------------------------

function ReadingDashboard:showDashboard()

    local title =
        self:getBookTitle()


    local progress =
        self:getProgress()


    local stats =
        self:getStatistics()


    local time_read = "—"

    if stats.book_read_time then
        time_read =
            formatTime(
                stats.book_read_time
            )
    end


    local average_time = "—"

    if stats.avg_time then
        average_time =
            formatTime(
                stats.avg_time
            )
    end


    local time_remaining = "—"

    if stats.avg_time
        and progress.pages_remaining then

        time_remaining =
            formatTime(
                stats.avg_time
                * progress.pages_remaining
            )
    end


    local dialog =
        DashboardDialog:new{

            title =
                title,

            percentage =
                progress.percentage or 0,

            current_page =
                progress.current_page,

            page_count =
                progress.page_count,

            pages_remaining =
                progress.pages_remaining,

            time_read =
                time_read,

            average_time =
                average_time,

            time_remaining =
                time_remaining,
        }


    UIManager:show(
        dialog
    )
end


-- ---------------------------------------------------------
-- Main menu
-- ---------------------------------------------------------

function ReadingDashboard:addToMainMenu(
    menu_items
)

    menu_items.reading_dashboard = {

        text =
            _("Reading Dashboard"),

        sorting_hint =
            "tools",

        sub_item_table = {

            {
                text =
                    _("Open Dashboard"),

                callback =
                    function()
                        self:showDashboard()
                    end,
            },


            {
                text =
                    _("Check for Updates"),


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
                text =
                    _("Restore Previous Version"),

                callback = function()
                    local Updater = loadUpdater()

                    if Updater then
                        Updater:confirmRestore()
                    end
                end,
            },


            {
                text =
                    _("About"),

                callback =
                    function()

                        UIManager:show(
                            InfoMessage:new{

                                text =
                                    "Reading Dashboard"
                                    .. "\n\n"
                                    .. "Version "
                                    .. PLUGIN_VERSION
                                    .. "\n\n"
                                    .. "github.com/jennyo88/koreader-plugins",
                            }
                        )
                    end,
            },
        },
    }
end


return ReadingDashboard
