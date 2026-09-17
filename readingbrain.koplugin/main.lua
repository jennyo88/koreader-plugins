local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local Screen = Device.screen

local PLUGIN_VERSION = "0.5.7"

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
local Stats = dofile(plugin_dir .. "/stats.lua")
local Brain = dofile(plugin_dir .. "/brain.lua")
local Discovery = dofile(plugin_dir .. "/discovery.lua")
local UpdateNotifier = dofile(plugin_dir .. "/update_notifier.lua")
local StatsPatterns = dofile(plugin_dir .. "/stats_patterns.lua")

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


local StatsDialog =
    InputContainer:extend{
        title = "",
        body = "",
        owner = nil,
    }

function StatsDialog:init()
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
            21
        )

    local body_face =
        Font:getFace(
            "cfont",
            15
        )

    local small_face =
        Font:getFace(
            "cfont",
            13
        )

    local title_widget =
        TextBoxWidget:new{
            text = self.title,
            face = title_face,
            width = content_width,
            alignment = "center",
            bold = true,
        }

    local divider =
        LineWidget:new{
            background =
                Blitbuffer.COLOR_DARK_GRAY,

            dimen =
                Geom:new{
                    w = content_width,
                    h = Screen:scaleBySize(1),
                },
        }

    local line_count = 1

    for _ in tostring(self.body):gmatch("\n") do
        line_count = line_count + 1
    end

    local use_scroll =
        line_count > 12
        or #tostring(self.body) > 900

    local body_widget

    if use_scroll then
        body_widget =
            ScrollTextWidget:new{
                text = self.body,
                face = body_face,
                width = content_width,
                height =
                    math.floor(
                        Screen:getHeight()
                        * 0.55
                    ),
                alignment = "left",
                dialog = self,
            }
    else
        body_widget =
            TextBoxWidget:new{
                text = self.body,
                face = body_face,
                width = content_width,
                alignment = "left",
            }
    end

    local buttons =
        ButtonTable:new{
            width = content_width,
            buttons = {
                {
                    {
                        text = _("Close"),
                        callback =
                            function()
                                if self.owner then
                                    self.owner:closeStatsDialog()
                                else
                                    UIManager:close(self)
                                end
                            end,
                    },
                },
            },
        }

    local hint =
        TextWidget:new{
            text = _("Reading Brain"),
            face = small_face,
            fgcolor =
                Blitbuffer.COLOR_DARK_GRAY,
        }

    local content =
        VerticalGroup:new{
            align = "center",

            title_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(10),
            },

            divider,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(14),
            },

            body_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(16),
            },

            buttons,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(8),
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

    self.card = card

    self[1] =
        CenterContainer:new{
            dimen =
                Screen:getSize(),

            card,
        }
end

function StatsDialog:onShow()
    UIManager:setDirty(
        self,
        function()
            return
                "flashui",
                self.card.dimen
        end
    )
end

function StatsDialog:onCloseWidget()
    UIManager:setDirty(
        nil,
        function()
            return
                "ui",
                self.card.dimen
        end
    )
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

local function authors_string(value)
    return Library:authorString(value)
end

local function book_key(title, authors)
    return Library:canonicalKey(title, authors)
end

function ReadingBrain:init()
    self.discovery_dialog = nil
    self.stats_dialog = nil

    self.update_notifier =
        UpdateNotifier:new{
            plugin_id = "readingbrain",
            plugin_name = "Reading Brain",
            current_version = PLUGIN_VERSION,
        }

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end

end

function ReadingBrain:onResume()
    if self.update_notifier then
        self.update_notifier:onWake()
    end
end

function ReadingBrain:syncUnifiedHistory()
    local status = InfoMessage:new{
        text = _("Building unified reading history…"),
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
                .. "/mnt/us/readingbrain/",
        })

        return
    end

    local db_path, extract_err =
        Bookmory:extractDatabase(backup)

    if not db_path then
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "Could not read the Bookmory backup.\n\n"
                .. tostring(extract_err),
        })

        return
    end

    local bm_books, bm_err =
        Bookmory:readBooks(db_path)

    if not bm_books then
        Bookmory:cleanup(db_path)
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "Could not read the Bookmory database.\n\n"
                .. tostring(bm_err),
        })

        return
    end

    local kindle_books =
        Library:getBooks()

    local title_index =
        Library:buildTitleIndex(kindle_books)

    local ko_stats, stats_err =
        Stats:read()

    local brain_db =
        Brain:open()

    Brain:clearImportedData(brain_db)
    brain_db:exec("BEGIN;")

    local imported_bookmory = 0
    local matched_bookmory = 0

    -- Bookmory books + sessions.
    for _, bm in ipairs(bm_books) do
        local matched, match_status =
            Library:matchOne(
                bm.title,
                bm.authors,
                kindle_books,
                title_index
            )

        local canonical_title =
            matched and matched.title
            or bm.title
            or "Untitled"

        local canonical_authors =
            matched and authors_string(matched.authors)
            or authors_string(bm.authors)

        local key =
            book_key(
                canonical_title,
                canonical_authors
            )

        if key then
            Brain:upsertBook(brain_db, {
                book_key = key,
                title = canonical_title,
                authors = canonical_authors,
                kindle_file = matched and matched.file or nil,
                bookmory_format = bm.book_type,
                matched = match_status == "matched",
            })

            imported_bookmory =
                imported_bookmory + 1

            if match_status == "matched" then
                matched_bookmory =
                    matched_bookmory + 1
            end

            for _, session in ipairs(
                Bookmory:getSessions(bm)
            ) do
                if (tonumber(session.duration) or 0) > 0 then
                    session.book_key = key
                    Brain:insertSession(
                        brain_db,
                        session
                    )
                end
            end
        end
    end

    -- KOReader statistics.
    local imported_koreader_sessions = 0

    if ko_stats and ko_stats.available then
        for _, session in ipairs(ko_stats.sessions or {}) do
            local key =
                book_key(
                    session.title,
                    session.authors
                )

            if key
                and (tonumber(session.duration) or 0) > 0 then

                Brain:upsertBook(brain_db, {
                    book_key = key,
                    title = session.title or "Untitled",
                    authors = session.authors or "",
                    kindle_file = nil,
                    bookmory_format = nil,
                    matched = true,
                })

                Brain:insertSession(brain_db, {
                    book_key = key,
                    source = "KOReader",
                    medium = "Kindle",
                    start_time = session.start_time,
                    duration = session.duration,
                })

                imported_koreader_sessions =
                    imported_koreader_sessions + 1
            end
        end
    end

    Brain:setMeta(
        brain_db,
        "bookmory_backup",
        backup
    )

    Brain:setMeta(
        brain_db,
        "last_sync",
        tostring(os.time())
    )

    brain_db:exec("COMMIT;")
    brain_db:close()

    Bookmory:cleanup(db_path)
    UIManager:close(status)

    local summary =
        Brain:getSummary()

    local stats_note = ""

    if not ko_stats then
        stats_note =
            "\n\nKOReader statistics could not be read:\n"
            .. tostring(stats_err)
    elseif not ko_stats.available then
        stats_note =
            "\n\nKOReader statistics database was not available yet."
    end

    self:showCardDialog(
        "SYNC COMPLETE",
        "Bookmory backup\n"
        .. short_path(backup)
        .. "\n\n"
        .. string.format(
            "Bookmory books processed ... %d\n",
            imported_bookmory
        )
        .. string.format(
            "Matched to Kindle .......... %d\n",
            matched_bookmory
        )
        .. string.format(
            "KOReader sessions .......... %d\n",
            imported_koreader_sessions
        )
        .. string.format(
            "Unified sessions ........... %d\n",
            summary and summary.sessions or 0
        )
        .. string.format(
            "Unified reading time ....... %s",
            hours_minutes(
                summary and summary.seconds or 0
            )
        )
        .. stats_note
        .. "\n\nKOReader statistics were read only and were not modified."
    )
end

function ReadingBrain:showSummary()
    local summary =
        Brain:getSummary()

    if not summary then
        self:showCardDialog(
            "UNIFIED SUMMARY",
            "Reading Brain has not been synced yet.\n\n"
            .. "Choose:\n"
            .. "Sync Unified History"
        )
        return
    end

    self:showCardDialog(
        "UNIFIED SUMMARY",
        string.format(
            "Books .............. %d\n",
            summary.books
        )
        .. string.format(
            "Matched books ...... %d\n",
            summary.matched
        )
        .. string.format(
            "Sessions ........... %d\n\n",
            summary.sessions
        )
        .. "READING TIME\n"
        .. string.format(
            "Kindle ............. %s\n",
            hours_minutes(summary.kindle_seconds)
        )
        .. string.format(
            "Audiobook .......... %s\n",
            hours_minutes(summary.audio_seconds)
        )
        .. string.format(
            "External/Hybrid .... %s\n",
            hours_minutes(summary.hybrid_seconds)
        )
        .. "────────────────────\n"
        .. string.format(
            "Combined ........... %s",
            hours_minutes(summary.seconds)
        )
    )
end

function ReadingBrain:showRecentSessions()
    local sessions =
        Brain:getRecentSessions(18)

    if #sessions == 0 then
        self:showCardDialog(
            "RECENT SESSIONS",
            "No unified sessions yet.\n\n"
            .. "Run Sync Unified History first."
        )
        return
    end

    local lines = {
        "RECENT READING SESSIONS",
        "",
    }

    for _, s in ipairs(sessions) do
        local date =
            os.date(
                "%b %d • %I:%M %p",
                s.start_time
            )

        table.insert(
            lines,
            date
            .. "\n"
            .. s.title
            .. "\n"
            .. s.medium
            .. " • "
            .. hours_minutes(s.duration)
            .. "\n"
        )
    end

    self:showCardDialog(
        "RECENT SESSIONS",
        table.concat(lines, "\n")
    )
end

function ReadingBrain:confirmRebuild()
    UIManager:show(ConfirmBox:new{
        text =
            "Rebuild Reading Brain's unified history?\n\n"
            .. "This only replaces Reading Brain's own imported cache.\n"
            .. "KOReader statistics and the Bookmory backup are never modified.",

        ok_text = _("Rebuild"),
        cancel_text = _("Cancel"),

        ok_callback = function()
            self:syncUnifiedHistory()
        end,
    })
end


function ReadingBrain:closeDiscoveryDialog()
    if self.discovery_dialog then
        UIManager:close(
            self.discovery_dialog
        )

        self.discovery_dialog = nil
    end
end

function ReadingBrain:loadBookmoryBooks()
    local backup =
        Bookmory:findLatestBackup()

    if not backup then
        return nil,
            "No .bookmory backup was found in /mnt/us/readingbrain/."
    end

    local db_path, err =
        Bookmory:extractDatabase(
            backup
        )

    if not db_path then
        return nil, err
    end

    local books, read_err =
        Bookmory:readBooks(
            db_path
        )

    Bookmory:cleanup(
        db_path
    )

    if not books then
        return nil, read_err
    end

    return books
end

function ReadingBrain:showTasteProfile()
    local books, err =
        self:loadBookmoryBooks()

    if not books then
        self:showCardDialog(
            "TASTE PROFILE",
            "Could not build taste profile.\n\n"
            .. tostring(err)
        )

        return
    end

    local profile =
        Discovery:buildProfile(
            books
        )

    self:showCardDialog(
        "TASTE PROFILE",
        Discovery:profileText(
            profile
        )
    )
end

function ReadingBrain:discoverBooks()
    local status =
        InfoMessage:new{
            text =
                _("Finding books you may like…"),
        }

    UIManager:show(status)
    UIManager:forceRePaint()

    local books, err =
        self:loadBookmoryBooks()

    if not books then
        UIManager:close(status)

        UIManager:show(
            InfoMessage:new{
                text =
                    "Could not read Bookmory.\n\n"
                    .. tostring(err),
            }
        )

        return
    end

    local kindle_books =
        Library:getBooks()

    local recommendations, discover_err =
        Discovery:recommend(
            books,
            kindle_books,
            5
        )

    UIManager:close(status)

    if not recommendations then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Book discovery failed.\n\n"
                    .. tostring(
                        discover_err
                    ),
            }
        )

        return
    end

    if #recommendations == 0 then
        UIManager:show(
            InfoMessage:new{
                text =
                    "No new recommendations were found this time.",
            }
        )

        return
    end

    local buttons = {}

    for i, book in ipairs(
        recommendations
    ) do
        local selected =
            book

        local author =
            table.concat(
                selected.authors or {},
                ", "
            )

        local label =
            tostring(i)
            .. ". "
            .. tostring(
                selected.title
                or "Unknown title"
            )

        if author ~= "" then
            label =
                label
                .. "\n"
                .. author
        end

        label =
            label
            .. "\nMatch score: "
            .. string.format(
                "%.1f",
                selected.score
                or 0
            )

        table.insert(
            buttons,
            {
                {
                    text = label,

                    callback =
                        function()
                            local reason =
                                #(
                                    selected.reasons
                                    or {}
                                ) > 0
                                and table.concat(
                                    selected.reasons,
                                    "\n"
                                )
                                or "Strong overall taste match"

                            self:showCardDialog(
                                tostring(
                                    selected.title
                                    or "BOOK MATCH"
                                ),
                                (
                                    author ~= ""
                                    and author
                                    or "Unknown author"
                                )
                                .. (
                                    selected.year
                                    and (
                                        "\nFirst published: "
                                        .. tostring(
                                            selected.year
                                        )
                                    )
                                    or ""
                                )
                                .. "\n\nWHY READING BRAIN PICKED IT\n"
                                .. reason
                                .. "\n\nOpen Library work:\n"
                                .. tostring(
                                    selected.key
                                    or "Unknown"
                                )
                            )
                        end,
                },
            }
        )
    end

    table.insert(
        buttons,
        {
            {
                text =
                    _("Refresh"),

                callback =
                    function()
                        self:closeDiscoveryDialog()
                        self:discoverBooks()
                    end,
            },

            {
                text =
                    _("Close"),

                callback =
                    function()
                        self:closeDiscoveryDialog()
                    end,
            },
        }
    )

    local using_cache =
        recommendations[1]
        and recommendations[1].used_cache

    self.discovery_dialog =
        ButtonDialog:new{
            title =
                _("DISCOVER BOOKS")
                .. "\n"
                .. (
                    using_cache
                    and _("Cached results • based on your Bookmory ratings")
                    or _("Based on your Bookmory ratings")
                ),

            title_align =
                "center",

            buttons =
                buttons,
        }

    UIManager:show(
        self.discovery_dialog
    )
end


function ReadingBrain:withStatsContext(callback)
    local books, err = self:loadBookmoryBooks()
    if not books then
        UIManager:show(InfoMessage:new{ text = "Could not read Bookmory.\n\n" .. tostring(err) })
        return
    end
    local ok, result = pcall(callback, books)
    if not ok then
        UIManager:show(InfoMessage:new{ text = "Could not build reading statistics.\n\n" .. tostring(result) })
    end
end


function ReadingBrain:showCardDialog(title, text)
    self:closeStatsDialog()

    self.stats_dialog =
        StatsDialog:new{
            title = title,
            body = text,
            owner = self,
        }

    UIManager:show(
        self.stats_dialog
    )
end

function ReadingBrain:closeStatsDialog()
    if self.stats_dialog then
        UIManager:close(
            self.stats_dialog
        )

        self.stats_dialog = nil
    end
end

function ReadingBrain:showStatsText(title, text)
    self:showCardDialog(
        title,
        text
    )
end

function ReadingBrain:showThisYear()
    self:withStatsContext(function(books) self:showStatsText("THIS YEAR", StatsPatterns:thisYear(books)) end)
end
function ReadingBrain:showMonthlyReading()
    self:withStatsContext(function(books) self:showStatsText("MONTHLY READING", StatsPatterns:monthlyReading(books)) end)
end
function ReadingBrain:showReadingFormats()
    self:withStatsContext(function(books) self:showStatsText("READING FORMATS", StatsPatterns:readingFormats(books)) end)
end
function ReadingBrain:showRatings()
    self:withStatsContext(function(books) self:showStatsText("RATINGS", StatsPatterns:ratings(books)) end)
end
function ReadingBrain:showAuthorsGenres()
    self:withStatsContext(function(books) self:showStatsText("AUTHORS & GENRES", StatsPatterns:authorsAndGenres(books)) end)
end
function ReadingBrain:showReadingHabits()
    self:withStatsContext(function(books) self:showStatsText("READING HABITS", StatsPatterns:readingHabits(books)) end)
end
function ReadingBrain:showInterestingPatterns()
    self:withStatsContext(function(books) self:showStatsText("INTERESTING PATTERNS", StatsPatterns:interestingPatterns(books)) end)
end
function ReadingBrain:showReadingRecords()
    self:withStatsContext(function(books) self:showStatsText("READING RECORDS", StatsPatterns:readingRecords(books)) end)
end

function ReadingBrain:addToMainMenu(menu_items)
    menu_items.reading_brain = {
        text = _("Reading Brain"),
        sorting_hint = "tools",

        sub_item_table = {
            {
                text = _("Discover Books"),
                callback = function()
                    self:discoverBooks()
                end,
            },

            {
                text = _("Taste Profile"),
                callback = function()
                    self:showTasteProfile()
                end,
            },

            {
                text = _("Stats & Patterns"),
                sub_item_table = {
                    { text = _("This Year"), callback = function() self:showThisYear() end },
                    { text = _("Monthly Reading"), callback = function() self:showMonthlyReading() end },
                    { text = _("Reading Formats"), callback = function() self:showReadingFormats() end },
                    { text = _("Ratings"), callback = function() self:showRatings() end },
                    { text = _("Authors & Genres"), callback = function() self:showAuthorsGenres() end },
                    { text = _("Reading Habits"), callback = function() self:showReadingHabits() end },
                    { text = _("Interesting Patterns"), callback = function() self:showInterestingPatterns() end },
                    { text = _("Reading Records"), callback = function() self:showReadingRecords() end },
                },
            },

            {
                text = _("Sync Unified History"),
                callback = function()
                    self:confirmRebuild()
                end,
            },

            {
                text = _("Unified Summary"),
                callback = function()
                    self:showSummary()
                end,
            },

            {
                text = _("Recent Sessions"),
                callback = function()
                    self:showRecentSessions()
                end,
            },

            {
                text = _("Analyze Bookmory Backup"),
                callback = function()
                    -- Keep the old analyzer available by reusing the sync
                    -- summary without writing to KOReader statistics.
                    local backup = Bookmory:findLatestBackup()

                    if not backup then
                        UIManager:show(InfoMessage:new{
                            text =
                                "No .bookmory backup was found in /mnt/us/readingbrain/.",
                        })
                        return
                    end

                    local db_path, err =
                        Bookmory:extractDatabase(backup)

                    if not db_path then
                        UIManager:show(InfoMessage:new{
                            text = tostring(err),
                        })
                        return
                    end

                    local books, read_err =
                        Bookmory:readBooks(db_path)

                    if not books then
                        Bookmory:cleanup(db_path)
                        UIManager:show(InfoMessage:new{
                            text = tostring(read_err),
                        })
                        return
                    end

                    local bm = Bookmory:summarize(books)
                    local kindle = Library:getBooks()
                    local matches = Library:matchBookmory(books, kindle)

                    Bookmory:cleanup(db_path)

                    UIManager:show(InfoMessage:new{
                        text =
                            "BOOKMORY ANALYSIS\n\n"
                            .. string.format("Books ............... %d\n", bm.books)
                            .. string.format("Timed sessions ...... %d\n", bm.sessions)
                            .. string.format("Logged time ......... %s\n", hours_minutes(bm.seconds))
                            .. string.format("Audio-only sessions . %d\n", bm.audiobook_sessions)
                            .. string.format("External/hybrid ..... %d\n\n", bm.external_sessions)
                            .. string.format("Kindle EPUBs ........ %d\n", #kindle)
                            .. string.format("Matched ............. %d\n", matches.matched)
                            .. string.format("Needs review ........ %d\n", matches.ambiguous)
                            .. string.format("Not matched ......... %d", matches.unmatched),
                    })
                end,
            },

            {
                text = _("Notify on wake when update available"),
                checked_func = function()
                    return
                        self.update_notifier
                        and self.update_notifier:isEnabled()
                end,
                callback = function()
                    if self.update_notifier then
                        self.update_notifier:setEnabled(
                            not self.update_notifier:isEnabled()
                        )
                    end
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
                            .. "Unified reading history, book discovery, visual statistics, and reading-pattern analysis.\n\n"
                            .. "Reading Brain writes only to:\n"
                            .. "/mnt/us/readingbrain/readingbrain.sqlite3\n\n"
                            .. "It never writes to KOReader's statistics.sqlite3 or your Bookmory backup.\n\n"
                            .. "KOReader page statistics are grouped into sessions using a 10-minute inactivity gap.",
                    })
                end,
            },
        },
    }
end

return ReadingBrain
