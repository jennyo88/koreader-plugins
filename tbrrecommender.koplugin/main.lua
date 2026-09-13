local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")

local PLUGIN_VERSION = "0.2.1"
local Screen = Device.screen

local source = debug.getinfo(1, "S").source

if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir =
    source:match("(.+)/[^/]+$")

if plugin_dir
    and plugin_dir:sub(1, 1) ~= "/" then

    plugin_dir =
        "/mnt/us/koreader/"
        .. plugin_dir
end

plugin_dir =
    plugin_dir
    or "/mnt/us/koreader/plugins/tbrrecommender.koplugin"

local Library =
    dofile(
        plugin_dir
        .. "/library.lua"
    )

local Recommender =
    dofile(
        plugin_dir
        .. "/recommender.lua"
    )


local function loadUpdater()
    local updater_path =
        plugin_dir
        .. "/updater.lua"

    local file =
        io.open(
            updater_path,
            "r"
        )

    if not file then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Updater file was not found.\n\n"
                    .. updater_path
                    .. "\n\nRun the installer again to install updater.lua.",
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
                    .. tostring(
                        updater_or_error
                    ),
            }
        )

        return nil
    end

    return updater_or_error
end


local function title_for(book)
    return book.title
        or (
            book.filename
            and book.filename:gsub(
                "%.epub$",
                ""
            )
        )
        or "Unknown title"
end


local function author_for(book)
    if type(book.authors)
        == "string" then

        return book.authors

    elseif type(book.authors)
        == "table" then

        return table.concat(
            book.authors,
            ", "
        )
    end

    return nil
end


local function details_for(book)
    local bits = {}

    local author =
        author_for(book)

    if author
        and author ~= "" then

        table.insert(
            bits,
            author
        )
    end

    if book.pages then
        table.insert(
            bits,
            tostring(
                book.pages
            )
            .. " pages"
        )
    end

    if book.series
        and book.series ~= "" then

        local series =
            book.series

        if book.series_index then
            series =
                series
                .. " #"
                .. tostring(
                    book.series_index
                )
        end

        table.insert(
            bits,
            series
        )
    end

    if book.recommendation_note
        and book.recommendation_note ~= "" then

        table.insert(
            bits,
            book.recommendation_note
        )
    end

    return table.concat(
        bits,
        " • "
    )
end


local function button_text_for(
    index,
    book
)
    local text =
        tostring(index)
        .. ". "
        .. title_for(book)

    local details =
        details_for(book)

    if details ~= "" then
        text =
            text
            .. "\n"
            .. details
    end

    return text
end


-- ---------------------------------------------------------
-- Pretty recommendation card
-- ---------------------------------------------------------

local RecommendationDialog =
    InputContainer:extend{
        header = "",
        books = nil,
        owner = nil,
    }


function RecommendationDialog:init()
    local card_width =
        math.floor(
            Screen:getWidth()
            * 0.90
        )

    local content_width =
        card_width
        - Screen:scaleBySize(44)

    local title_face =
        Font:getFace(
            "cfont",
            23
        )

    local small_face =
        Font:getFace(
            "cfont",
            15
        )

    local title_widget =
        TextWidget:new{
            text =
                _("YOUR NEXT READS"),

            face =
                title_face,

            bold =
                true,
        }

    local mode_widget =
        TextWidget:new{
            text =
                self.header,

            face =
                small_face,

            bold =
                true,
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

    local button_rows = {}

    for i, book in ipairs(
        self.books or {}
    ) do
        local selected_book =
            book

        table.insert(
            button_rows,
            {
                {
                    text =
                        button_text_for(
                            i,
                            selected_book
                        ),

                    align =
                        "left",

                    callback =
                        function()
                            self.owner:openBook(
                                selected_book
                            )
                        end,
                },
            }
        )
    end

    table.insert(
        button_rows,
        {
            {
                text =
                    _("Pick Again"),

                callback =
                    function()
                        self.owner:pickAgain()
                    end,
            },

            {
                text =
                    _("Close"),

                callback =
                    function()
                        self.owner:closeRecommendationDialog()
                    end,
            },
        }
    )

    local button_table =
        ButtonTable:new{
            width =
                content_width,

            buttons =
                button_rows,
        }

    local hint =
        TextWidget:new{
            text =
                _("Tap a book to open it"),

            face =
                small_face,

            fgcolor =
                Blitbuffer.COLOR_DARK_GRAY,
        }

    local content =
        VerticalGroup:new{
            align =
                "center",

            title_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(7),
            },

            mode_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(12),
            },

            divider,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(12),
            },

            button_table,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(12),
            },

            hint,
        }

    local card =
        FrameContainer:new{
            padding =
                Screen:scaleBySize(22),

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
end


function RecommendationDialog:onShow()
    UIManager:setDirty(
        self,
        function()
            return
                "flashui",
                self.card.dimen
        end
    )
end


function RecommendationDialog:onCloseWidget()
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

local TBRRecommender =
    WidgetContainer:extend{
        name =
            "tbrrecommender",

        is_doc_only =
            false,
    }


function TBRRecommender:init()
    self.recommendation_dialog =
        nil

    self.last_mode =
        nil

    if self.ui
        and self.ui.menu then

        self.ui.menu:registerToMainMenu(
            self
        )
    end
end


function TBRRecommender:getBooks()
    return Library:getCandidates(
        "/mnt/us/koreader/books"
    )
end


function TBRRecommender:getAllBooks()
    return Library:getAllBooks(
        "/mnt/us/koreader/books"
    )
end


function TBRRecommender:closeRecommendationDialog()
    if self.recommendation_dialog then
        UIManager:close(
            self.recommendation_dialog
        )

        self.recommendation_dialog =
            nil
    end
end


function TBRRecommender:openBook(book)
    if not book
        or not book.file then

        UIManager:show(
            InfoMessage:new{
                text =
                    _("Could not find this book's file."),
            }
        )

        return
    end

    self:closeRecommendationDialog()

    local ok, err =
        pcall(
            function()
                filemanagerutil.openFile(
                    self.ui,
                    book.file,
                    nil,
                    true
                )
            end
        )

    if not ok then
        UIManager:show(
            InfoMessage:new{
                text =
                    _("Could not open the selected book.")
                    .. "\n\n"
                    .. tostring(err),
            }
        )
    end
end


function TBRRecommender:pickAgain()
    self:closeRecommendationDialog()

    if self.last_mode then
        self:runMode(
            self.last_mode
        )
    end
end


function TBRRecommender:showRecommendations(
    header,
    books
)
    if not books
        or #books == 0 then

        UIManager:show(
            InfoMessage:new{
                text =
                    _("No matching books were found for this mode."),
            }
        )

        return
    end

    self.recommendation_dialog =
        RecommendationDialog:new{
            header =
                header,

            books =
                books,

            owner =
                self,
        }

    UIManager:show(
        self.recommendation_dialog
    )
end


function TBRRecommender:runMode(mode)
    self.last_mode =
        mode

    local books =
        self:getBooks()

    if #books == 0
        and mode ~= "series" then

        UIManager:show(
            InfoMessage:new{
                text =
                    _("No unread EPUBs were found in /mnt/us/koreader/books."),
            }
        )

        return
    end

    if mode == "surprise" then
        self:showRecommendations(
            _("SURPRISE ME"),

            Recommender:surpriseMe(
                books,
                3
            )
        )

    elseif mode == "quick" then
        self:showRecommendations(
            _("QUICK READ"),

            Recommender:quickRead(
                books,
                3
            )
        )

    elseif mode == "series" then
        self:showRecommendations(
            _("CONTINUE A SERIES"),

            Recommender:continueSeries(
                self:getAllBooks(),
                3
            )
        )

    elseif mode == "unopened" then
        self:showRecommendations(
            _("UNOPENED BOOKS"),

            Recommender:unopened(
                books,
                3
            )
        )

    elseif mode == "started" then
        self:showRecommendations(
            _("CONTINUE SOMETHING STARTED"),

            Recommender:continueStarted(
                books,
                3
            )
        )

    elseif mode == "different" then
        self:showRecommendations(
            _("SOMETHING DIFFERENT"),

            Recommender:somethingDifferent(
                books,
                3
            )
        )

    elseif mode == "easy" then
        self:showRecommendations(
            _("SHORT & EASY"),

            Recommender:shortAndEasy(
                books,
                3
            )
        )
    end
end


function TBRRecommender:addToMainMenu(
    menu_items
)
    menu_items.tbr_recommender = {
        text =
            _("TBR Recommender"),

        sorting_hint =
            "tools",

        sub_item_table = {
            {
                text =
                    _("Surprise Me"),

                callback =
                    function()
                        self:runMode(
                            "surprise"
                        )
                    end,
            },

            {
                text =
                    _("Quick Read"),

                callback =
                    function()
                        self:runMode(
                            "quick"
                        )
                    end,
            },

            {
                text =
                    _("Continue a Series"),

                callback =
                    function()
                        self:runMode(
                            "series"
                        )
                    end,
            },

            {
                text =
                    _("Continue Something Started"),

                callback =
                    function()
                        self:runMode(
                            "started"
                        )
                    end,
            },

            {
                text =
                    _("Something Different"),

                callback =
                    function()
                        self:runMode(
                            "different"
                        )
                    end,
            },

            {
                text =
                    _("Short & Easy"),

                callback =
                    function()
                        self:runMode(
                            "easy"
                        )
                    end,
            },

            {
                text =
                    _("Unopened Books"),

                callback =
                    function()
                        self:runMode(
                            "unopened"
                        )
                    end,
            },

            {
                text =
                    _("Check for Updates"),

                callback =
                    function()
                        local Updater =
                            loadUpdater()

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

                callback =
                    function()
                        local Updater =
                            loadUpdater()

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
                                    "TBR Recommender"
                                    .. "\n\nVersion "
                                    .. PLUGIN_VERSION
                                    .. "\n\nLibrary:"
                                    .. "\n/mnt/us/koreader/books"
                                    .. "\n\nSmarter TBR modes plus tappable recommendations.",
                            }
                        )
                    end,
            },
        },
    }
end


return TBRRecommender
