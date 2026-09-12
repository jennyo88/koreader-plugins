local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local PLUGIN_VERSION = "0.1.0"

local source = debug.getinfo(1, "S").source

if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("(.+)/[^/]+$")

if plugin_dir and plugin_dir:sub(1, 1) ~= "/" then
    plugin_dir = "/mnt/us/koreader/" .. plugin_dir
end

plugin_dir =
    plugin_dir
    or "/mnt/us/koreader/plugins/tbrrecommender.koplugin"

local Library =
    dofile(plugin_dir .. "/library.lua")

local Recommender =
    dofile(plugin_dir .. "/recommender.lua")


local TBRRecommender =
    WidgetContainer:extend{
        name = "tbrrecommender",
        is_doc_only = false,
    }


local function title_for(book)
    return book.title
        or (
            book.filename
            and book.filename:gsub("%.epub$", "")
        )
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

    local author =
        author_for(book)

    if author and author ~= "" then
        table.insert(bits, author)
    end

    if book.pages then
        table.insert(
            bits,
            tostring(book.pages) .. " pages"
        )
    end

    if book.series and book.series ~= "" then
        local series =
            book.series

        if book.series_index then
            series =
                series
                .. " #"
                .. tostring(book.series_index)
        end

        table.insert(bits, series)
    end

    if not book.been_opened then
        table.insert(bits, "Unopened")
    end

    return table.concat(bits, " • ")
end


function TBRRecommender:init()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end


function TBRRecommender:getBooks()
    return Library:getCandidates(
        "/mnt/us/koreader/books"
    )
end


function TBRRecommender:showRecommendations(
    header,
    books
)

    if not books or #books == 0 then
        UIManager:show(
            InfoMessage:new{
                text =
                    _("No matching unread books were found."),
            }
        )
        return
    end


    local lines = {
        header,
        "",
    }


    for i, book in ipairs(books) do
        table.insert(
            lines,
            string.format(
                "%d. %s",
                i,
                title_for(book)
            )
        )

        local details =
            details_for(book)

        if details ~= "" then
            table.insert(
                lines,
                "   " .. details
            )
        end

        if i < #books then
            table.insert(
                lines,
                ""
            )
        end
    end


    UIManager:show(
        InfoMessage:new{
            text =
                table.concat(
                    lines,
                    "\n"
                ),
        }
    )
end


function TBRRecommender:runMode(mode)

    local books =
        self:getBooks()


    if #books == 0 then
        UIManager:show(
            InfoMessage:new{
                text =
                    _(
                        "No unread EPUBs were found in /mnt/us/koreader/books."
                    ),
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
                books,
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
                    _("About"),

                callback =
                    function()

                        UIManager:show(
                            InfoMessage:new{
                                text =
                                    "TBR Recommender"
                                    .. "\n\nVersion "
                                    .. PLUGIN_VERSION
                                    .. "\n\nScans:"
                                    .. "\n/mnt/us/koreader/books"
                                    .. "\n\nRecommends unread EPUBs already on your Kindle.",
                            }
                        )
                    end,
            },
        },
    }
end


return TBRRecommender
