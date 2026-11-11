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

local PLUGIN_VERSION = "0.8.0"

local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
    source = source:sub(2)
end

local plugin_dir = source:match("(.+)/[^/]+$")
if plugin_dir and plugin_dir:sub(1, 1) ~= "/" then
    plugin_dir = "/mnt/us/koreader/" .. plugin_dir
end
plugin_dir = plugin_dir or "/mnt/us/koreader/plugins/readingbrain.koplugin"

local module_errors = {}

local function loadPluginModule(filename)
    local ok, module_or_error =
        pcall(
            dofile,
            plugin_dir .. "/" .. filename
        )

    if ok then
        return module_or_error
    end

    module_errors[filename] = tostring(module_or_error)
    return nil
end

local Bookmory = loadPluginModule("bookmory.lua")
local Library = loadPluginModule("library.lua")
local Stats = loadPluginModule("stats.lua")
local Brain = loadPluginModule("brain.lua")
local Discovery = loadPluginModule("discovery.lua")
local StatsPatterns = loadPluginModule("stats_patterns.lua")
local BackupHealth = loadPluginModule("backup_health.lua")
local Feedback = loadPluginModule("feedback.lua")

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
        subtitle = nil,
        body = "",
        footer = nil,
        owner = nil,
        button_rows = nil,
    }

function StatsDialog:init()
    local card_width =
        math.floor(
            Screen:getWidth()
            * 0.92
        )

    local content_width =
        card_width
        - Screen:scaleBySize(44)

    local title_face =
        Font:getFace(
            "cfont",
            20
        )

    local body_face =
        Font:getFace(
            "cfont",
            15
        )

    local small_face =
        Font:getFace(
            "cfont",
            12
        )

    local title_widget =
        TextBoxWidget:new{
            text = self.title,
            face = title_face,
            width = content_width,
            alignment = "center",
            bold = true,
        }

    local subtitle_widget

    if self.subtitle
        and tostring(self.subtitle) ~= "" then

        subtitle_widget =
            TextBoxWidget:new{
                text = tostring(self.subtitle),
                face = small_face,
                width = content_width,
                alignment = "center",
                fgcolor =
                    Blitbuffer.COLOR_DARK_GRAY,
            }
    end

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

    local button_rows =
        self.button_rows
        or {
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
        }

    local buttons =
        ButtonTable:new{
            width = content_width,
            buttons = button_rows,
        }

    local hint =
        TextWidget:new{
            text =
                self.footer
                or _("Reading Brain"),
            face = small_face,
            fgcolor =
                Blitbuffer.COLOR_DARK_GRAY,
        }

    local content =
        VerticalGroup:new{
            align = "center",

            title_widget,

            subtitle_widget
            and VerticalSpan:new{
                width =
                    Screen:scaleBySize(5),
            }
            or VerticalSpan:new{
                width = 0,
            },

            subtitle_widget
            or VerticalSpan:new{
                width = 0,
            },

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(9),
            },

            divider,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(11),
            },

            body_widget,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(12),
            },

            buttons,

            VerticalSpan:new{
                width =
                    Screen:scaleBySize(6),
            },

            hint,
        }

    local card =
        FrameContainer:new{
            padding =
                Screen:scaleBySize(18),

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

local function basename(path)
    return tostring(path or ""):match("([^/]+)$") or tostring(path or "")
end

local function stats_provenance_text()
    if not Bookmory then
        return "Bookmory backup • unavailable"
    end

    local backup, backup_time =
        Bookmory:findLatestBackup()

    local lines = {}

    if backup then
        table.insert(
            lines,
            "Bookmory backup • "
            .. Bookmory:formatBackupDate(
                backup,
                backup_time
            )
        )
    else
        table.insert(
            lines,
            "Bookmory backup • Missing"
        )
    end

    if not Brain then
        table.insert(
            lines,
            "History synced • unavailable"
        )

        return table.concat(lines, "\n")
    end

    local sync = Brain:getSyncInfo()
    local synced_time = tonumber(sync.backup_time) or 0

    if synced_time <= 0
        and sync.backup then

        synced_time =
            Bookmory:getBackupTimestamp(
                sync.backup
            )
            or 0
    end

    if synced_time > 0 then
        table.insert(
            lines,
            "History synced • "
            .. os.date(
                "%b %d, %Y",
                synced_time
            )
        )
    else
        table.insert(
            lines,
            "History synced • Never"
        )
    end

    if backup
        and backup_time
        and (
            synced_time <= 0
            or backup_time > synced_time
            or basename(backup) ~= basename(sync.backup)
        ) then

        table.insert(
            lines,
            "NEW BACKUP • Sync for current history"
        )
    end

    return table.concat(lines, "\n")
end

local function authors_string(value)
    return Library:authorString(value)
end

local function book_key(title, authors)
    return Library:canonicalKey(title, authors)
end

local function modulesReady(feature, modules)
    local missing = {}

    for _, item in ipairs(modules or {}) do
        if not item.module then
            local detail = module_errors[item.file]

            table.insert(
                missing,
                item.file
                .. (
                    detail
                    and ("\n" .. detail)
                    or ""
                )
            )
        end
    end

    if #missing == 0 then
        return true
    end

    UIManager:show(
        InfoMessage:new{
            text =
                tostring(feature)
                .. " is unavailable because a Reading Brain module could not be loaded.\n\n"
                .. table.concat(missing, "\n\n")
                .. "\n\nThe rest of Reading Brain can remain available.",
        }
    )

    return false
end

local function moduleStatusText()
    local failed = {}

    for filename, err in pairs(module_errors) do
        table.insert(
            failed,
            filename .. ": " .. tostring(err)
        )
    end

    table.sort(failed)

    if #failed == 0 then
        return "All modules loaded successfully."
    end

    return
        "Module problems:\n"
        .. table.concat(failed, "\n")
end

function ReadingBrain:init()
    self.discovery_dialog = nil
    self.stats_dialog = nil
    self.bookmory_cache = nil
    self.kindle_cache = nil

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function ReadingBrain:syncUnifiedHistory()
    if not modulesReady(
        "Sync Reading History",
        {
            { file = "bookmory.lua", module = Bookmory },
            { file = "library.lua", module = Library },
            { file = "stats.lua", module = Stats },
            { file = "brain.lua", module = Brain },
            { file = "backup_health.lua", module = BackupHealth },
        }
    ) then
        return
    end

    local status = InfoMessage:new{
        text = _("Building unified reading history…"),
    }

    UIManager:show(status)
    UIManager:forceRePaint()

    local backup, backup_time =
        Bookmory:findLatestBackup()

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

    local bm_books, bm_err =
        self:loadBookmoryBooks(true)

    if not bm_books then
        UIManager:close(status)

        UIManager:show(InfoMessage:new{
            text =
                "Could not read the Bookmory backup.\n\n"
                .. tostring(bm_err),
        })

        return
    end

    local kindle_books =
        self:getKindleBooks(true)

    local title_index =
        Library:buildTitleIndex(kindle_books)

    local ko_stats, stats_err = Stats:read()
    local brain_db = Brain:open()

    local imported_bookmory = 0
    local matched_bookmory = 0
    local imported_koreader_sessions = 0

    brain_db:exec("BEGIN;")

    local imported_ok, import_err =
        pcall(
            function()
                Brain:clearImportedData(brain_db)

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

                if ko_stats and ko_stats.available then
                    for _, session in ipairs(
                        ko_stats.sessions or {}
                    ) do
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
                    "bookmory_backup_time",
                    tostring(backup_time or 0)
                )

                Brain:setMeta(
                    brain_db,
                    "last_sync",
                    tostring(os.time())
                )
            end
        )

    if imported_ok then
        brain_db:exec("COMMIT;")
    else
        brain_db:exec("ROLLBACK;")
    end

    brain_db:close()
    UIManager:close(status)

    if not imported_ok then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Reading history could not be rebuilt.\n\n"
                    .. tostring(import_err)
                    .. "\n\nThe previous Reading Brain cache was kept.",
            }
        )
        return
    end

    BackupHealth:markSynced(
        backup,
        backup_time
    )

    local summary = Brain:getSummary()
    local stats_note = ""

    if not ko_stats then
        stats_note =
            "\n\nKOReader statistics could not be read:\n"
            .. tostring(stats_err)
    elseif not ko_stats.available then
        stats_note =
            "\n\nKOReader statistics database was not available yet."
    end

    local timing = ""

    if summary then
        timing =
            string.format(
                "Unified sessions ........... %d\n",
                summary.sessions
            )
            .. string.format(
                "Elapsed reading time ........ %s\n",
                hours_minutes(summary.elapsed_seconds)
            )
            .. string.format(
                "Source logged time .......... %s",
                hours_minutes(summary.seconds)
            )

        if (summary.overlap_seconds or 0) > 0 then
            timing =
                timing
                .. string.format(
                    "\nOverlap adjusted ............ %s",
                    hours_minutes(summary.overlap_seconds)
                )
        end
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
        .. timing
        .. stats_note
        .. "\n\nKOReader statistics and the Bookmory backup were read only.",
        nil,
        "Bookmory data • "
        .. Bookmory:formatBackupDate(
            backup,
            backup_time
        )
    )
end

function ReadingBrain:confirmRebuild()
    UIManager:show(ConfirmBox:new{
        text =
            "Sync Reading Brain's unified history?\n\n"
            .. "This only replaces Reading Brain's own imported cache.\n"
            .. "KOReader statistics and the Bookmory backup are never modified.",

        ok_text = _("Sync"),
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

function ReadingBrain:loadBookmoryBooks(force)
    if not Bookmory then
        return nil, module_errors["bookmory.lua"] or "Bookmory module is unavailable."
    end

    local backup, backup_time =
        Bookmory:findLatestBackup()

    if not backup then
        return nil,
            "No .bookmory backup was found in /mnt/us/readingbrain/."
    end

    local cache_key =
        tostring(backup)
        .. " :: "
        .. tostring(backup_time or 0)

    if not force
        and self.bookmory_cache
        and self.bookmory_cache.key == cache_key then

        return
            self.bookmory_cache.books,
            nil,
            backup,
            backup_time
    end

    local db_path, err =
        Bookmory:extractDatabase(backup)

    if not db_path then
        return nil, err
    end

    local books, read_err =
        Bookmory:readBooks(db_path)

    Bookmory:cleanup(db_path)

    if not books then
        return nil, read_err
    end

    self.bookmory_cache = {
        key = cache_key,
        books = books,
    }

    return books, nil, backup, backup_time
end

function ReadingBrain:getKindleBooks(force)
    if not Library then
        return {}
    end

    local now = os.time()

    if not force
        and self.kindle_cache
        and now - (self.kindle_cache.time or 0) < 300 then

        return self.kindle_cache.books
    end

    local books = Library:getBooks()

    self.kindle_cache = {
        time = now,
        books = books,
    }

    return books
end

function ReadingBrain:showTasteProfile()
    if not modulesReady(
        "Taste Profile",
        {
            { file = "bookmory.lua", module = Bookmory },
            { file = "discovery.lua", module = Discovery },
        }
    ) then
        return
    end

    local books, err = self:loadBookmoryBooks()

    if not books then
        self:showCardDialog(
            "TASTE PROFILE",
            "Could not build taste profile.\n\n"
            .. tostring(err)
        )
        return
    end

    local profile = Discovery:buildProfile(books)

    self:showCardDialog(
        "TASTE PROFILE",
        Discovery:profileText(profile),
        nil,
        stats_provenance_text()
    )
end

function ReadingBrain:discoverBooks()
    if not modulesReady(
        "Discover Books",
        {
            { file = "bookmory.lua", module = Bookmory },
            { file = "library.lua", module = Library },
            { file = "discovery.lua", module = Discovery },
            { file = "feedback.lua", module = Feedback },
        }
    ) then
        return
    end

    local status = InfoMessage:new{
        text = _("Finding books you may like…"),
    }

    UIManager:show(status)
    UIManager:forceRePaint()

    local books, err = self:loadBookmoryBooks()

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

    local kindle_books = self:getKindleBooks()

    local pool, discover_err =
        Discovery:recommend(
            books,
            kindle_books,
            50
        )

    UIManager:close(status)

    if not pool then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Book discovery failed.\n\n"
                    .. tostring(discover_err),
            }
        )
        return
    end

    local ranked = Feedback:apply(pool)
    local recommendations = {}

    for i = 1, math.min(5, #ranked) do
        table.insert(
            recommendations,
            ranked[i]
        )
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

    for i, book in ipairs(recommendations) do
        local selected = book
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
            label = label .. "\n" .. author
        end

        if selected.feedback == "want" then
            label = label .. "\nWANT TO READ"
        else
            label =
                label
                .. "\nMatch score: "
                .. string.format(
                    "%.1f",
                    selected.score or 0
                )
        end

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

                            local detail =
                                (
                                    author ~= ""
                                    and author
                                    or "Unknown author"
                                )
                                .. (
                                    selected.year
                                    and (
                                        "\nFirst published: "
                                        .. tostring(selected.year)
                                    )
                                    or ""
                                )
                                .. "\n\nWHY READING BRAIN PICKED IT\n"
                                .. reason

                            local current =
                                Feedback:label(selected)

                            if current then
                                detail =
                                    detail
                                    .. "\n\nSTATUS\n"
                                    .. current
                            end

                            self:closeDiscoveryDialog()

                            self.discovery_dialog =
                                ButtonDialog:new{
                                    title =
                                        tostring(
                                            selected.title
                                            or "BOOK MATCH"
                                        ),
                                    title_align = "center",
                                    buttons = {
                                        {
                                            {
                                                text = detail,
                                                enabled = false,
                                            },
                                        },
                                        {
                                            {
                                                text = _("Want to Read"),
                                                callback =
                                                    function()
                                                        Feedback:set(
                                                            selected,
                                                            "want"
                                                        )
                                                        self:closeDiscoveryDialog()
                                                        self:discoverBooks()
                                                    end,
                                            },
                                            {
                                                text = _("Not for Me"),
                                                callback =
                                                    function()
                                                        Feedback:set(
                                                            selected,
                                                            "dismiss"
                                                        )
                                                        self:closeDiscoveryDialog()
                                                        self:discoverBooks()
                                                    end,
                                            },
                                        },
                                        {
                                            {
                                                text = _("Already Own"),
                                                callback =
                                                    function()
                                                        Feedback:set(
                                                            selected,
                                                            "owned"
                                                        )
                                                        self:closeDiscoveryDialog()
                                                        self:discoverBooks()
                                                    end,
                                            },
                                            {
                                                text = _("Back"),
                                                callback =
                                                    function()
                                                        self:closeDiscoveryDialog()
                                                        self:discoverBooks()
                                                    end,
                                            },
                                        },
                                    },
                                }

                            UIManager:show(
                                self.discovery_dialog
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
                text = _("Refresh"),
                callback =
                    function()
                        self:closeDiscoveryDialog()
                        self:discoverBooks()
                    end,
            },
            {
                text = _("Close"),
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
            title_align = "center",
            buttons = buttons,
        }

    UIManager:show(self.discovery_dialog)
end

function ReadingBrain:withStatsContext(callback)
    if not modulesReady(
        "Stats & Patterns",
        {
            { file = "bookmory.lua", module = Bookmory },
            { file = "brain.lua", module = Brain },
            { file = "stats_patterns.lua", module = StatsPatterns },
        }
    ) then
        return
    end

    local books, err = self:loadBookmoryBooks()

    if not books then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Could not read Bookmory.\n\n"
                    .. tostring(err),
            }
        )
        return
    end

    local ok, result = pcall(callback, books)

    if not ok then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Could not build reading statistics.\n\n"
                    .. tostring(result),
            }
        )
    end
end

function ReadingBrain:showCardDialog(
    title,
    text,
    button_rows,
    subtitle,
    footer
)
    self:closeStatsDialog()

    self.stats_dialog =
        StatsDialog:new{
            title = title,
            subtitle = subtitle,
            body = text,
            footer = footer,
            owner = self,
            button_rows = button_rows,
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

function ReadingBrain:showReadingOverview()
    if not modulesReady(
        "Reading Overview",
        {
            { file = "brain.lua", module = Brain },
            { file = "bookmory.lua", module = Bookmory },
            { file = "stats_patterns.lua", module = StatsPatterns },
        }
    ) then
        return
    end

    local summary = Brain:getSummary()

    if not summary then
        self:showCardDialog(
            "READING OVERVIEW",
            "Reading Brain has not been synced yet.\n\n"
            .. "Choose Data & Sync → Sync Reading History."
        )
        return
    end

    self:withStatsContext(
        function(books)
            local body =
                "ALL TIME\n"
                .. string.format(
                    "Books .............. %d\n",
                    summary.books
                )
                .. string.format(
                    "Matched ............ %d\n",
                    summary.matched
                )
                .. string.format(
                    "Sessions ........... %d\n",
                    summary.sessions
                )
                .. string.format(
                    "Elapsed reading .... %s\n",
                    hours_minutes(summary.elapsed_seconds)
                )
                .. string.format(
                    "Source logs ........ %s",
                    hours_minutes(summary.seconds)
                )

            if (summary.overlap_seconds or 0) > 0 then
                body =
                    body
                    .. string.format(
                        "\nOverlap adjusted ... %s",
                        hours_minutes(summary.overlap_seconds)
                    )
            end

            body =
                body
                .. "\n\nFORMAT MIX\n"
                .. StatsPatterns:readingFormats(books)
                .. "\n\nTHIS YEAR\n"
                .. StatsPatterns:thisYear(books)

            self:showCardDialog(
                "READING OVERVIEW",
                body,
                nil,
                stats_provenance_text()
            )
        end
    )
end

function ReadingBrain:showStatsPage(page_index, books)
    local pages = {
        {
            title = "BY MONTH",
            build =
                function()
                    return
                        StatsPatterns:monthlyReading(books)
                end,
        },
        {
            title = "RATINGS & TASTE",
            build =
                function()
                    return
                        StatsPatterns:ratings(books)
                        .. "\n\n────────────────────\n\n"
                        .. StatsPatterns:authorsAndGenres(books)
                end,
        },
        {
            title = "READING HABITS",
            build =
                function()
                    return
                        StatsPatterns:readingHabits(books)
                end,
        },
        {
            title = "PATTERNS",
            build =
                function()
                    return
                        StatsPatterns:interestingPatterns(books)
                end,
        },
        {
            title = "RECORDS",
            build =
                function()
                    return
                        StatsPatterns:readingRecords(books)
                end,
        },
    }

    if page_index < 1 then
        page_index = #pages
    elseif page_index > #pages then
        page_index = 1
    end

    local page = pages[page_index]
    local ok, body = pcall(page.build)

    if not ok then
        UIManager:show(
            InfoMessage:new{
                text =
                    "Could not build reading statistics.\n\n"
                    .. tostring(body),
            }
        )
        return
    end

    local buttons = {
        {
            {
                text = _("Previous"),
                callback =
                    function()
                        self:showStatsPage(
                            page_index - 1,
                            books
                        )
                    end,
            },
            {
                text = _("Close"),
                callback =
                    function()
                        self:closeStatsDialog()
                    end,
            },
            {
                text = _("Next"),
                callback =
                    function()
                        self:showStatsPage(
                            page_index + 1,
                            books
                        )
                    end,
            },
        },
    }

    self:showCardDialog(
        page.title,
        body,
        buttons,
        stats_provenance_text(),
        tostring(page_index)
        .. " of "
        .. tostring(#pages)
        .. "  •  Reading Brain"
    )
end

function ReadingBrain:showStatsPager()
    self:withStatsContext(
        function(books)
            self:showStatsPage(1, books)
        end
    )
end

function ReadingBrain:showDataStatus()
    if not modulesReady(
        "Data Status",
        {
            { file = "bookmory.lua", module = Bookmory },
            { file = "library.lua", module = Library },
            { file = "brain.lua", module = Brain },
            { file = "backup_health.lua", module = BackupHealth },
        }
    ) then
        return
    end

    local backup, backup_time =
        Bookmory:findLatestBackup()

    local health =
        BackupHealth:getStatus(
            backup,
            backup_time
        )

    if not backup then
        self:showCardDialog(
            "DATA STATUS",
            "No .bookmory backup was found.\n\n"
            .. "Expected folder:\n"
            .. "/mnt/us/readingbrain/",
            nil,
            "MISSING"
        )
        return
    end

    local books, read_err = self:loadBookmoryBooks()

    if not books then
        self:showCardDialog(
            "DATA STATUS",
            tostring(read_err),
            nil,
            health.label
        )
        return
    end

    local bm = Bookmory:summarize(books)
    local kindle = self:getKindleBooks()
    local matches =
        Library:matchBookmory(
            books,
            kindle
        )

    local summary = Brain:getSummary()
    local sync = Brain:getSyncInfo()
    local synced_backup_time = tonumber(sync.backup_time) or 0

    if synced_backup_time <= 0
        and sync.backup then

        synced_backup_time =
            Bookmory:getBackupTimestamp(sync.backup)
            or 0
    end

    local sync_text = "\n\nUNIFIED CACHE\n"

    if summary then
        sync_text =
            sync_text
            .. string.format(
                "Books ............... %d\n",
                summary.books
            )
            .. string.format(
                "Sessions ............ %d\n",
                summary.sessions
            )
            .. string.format(
                "Elapsed time ........ %s\n",
                hours_minutes(summary.elapsed_seconds)
            )
            .. string.format(
                "Source logs ......... %s",
                hours_minutes(summary.seconds)
            )

        if (summary.overlap_seconds or 0) > 0 then
            sync_text =
                sync_text
                .. string.format(
                    "\nOverlap adjusted .... %s",
                    hours_minutes(summary.overlap_seconds)
                )
        end

        if synced_backup_time > 0 then
            sync_text =
                sync_text
                .. "\nHistory source ...... "
                .. os.date(
                    "%b %d, %Y",
                    synced_backup_time
                )
        end

        if (sync.last_sync or 0) > 0 then
            sync_text =
                sync_text
                .. "\nLast sync ........... "
                .. os.date(
                    "%b %d, %Y %I:%M %p",
                    sync.last_sync
                )
        end
    else
        sync_text = sync_text .. "Not synced yet."
    end

    local body =
        BackupHealth:formatBody(health)
        .. "\n\n"
        .. string.format(
            "Books ............... %d\n",
            bm.books
        )
        .. string.format(
            "Timed sessions ...... %d\n",
            bm.sessions
        )
        .. string.format(
            "Logged time ......... %s\n\n",
            hours_minutes(bm.seconds)
        )
        .. "KINDLE MATCHING\n"
        .. string.format(
            "EPUBs ............... %d\n",
            #kindle
        )
        .. string.format(
            "Matched ............. %d\n",
            matches.matched
        )
        .. string.format(
            "Needs review ........ %d\n",
            matches.ambiguous
        )
        .. string.format(
            "Not matched ......... %d",
            matches.unmatched
        )
        .. sync_text

    self:showCardDialog(
        "DATA STATUS",
        body,
        nil,
        health.label
    )
end

function ReadingBrain:showAbout()
    self:showCardDialog(
        "READING BRAIN",
        "Version "
        .. PLUGIN_VERSION
        .. "\n\n"
        .. "Unified reading history, discovery, statistics, and evidence-based reading-pattern analysis.\n\n"
        .. "Bookmory source folder:\n"
        .. "/mnt/us/readingbrain/\n\n"
        .. "Reading Brain writes only to its own cache and settings. KOReader statistics and Bookmory backups are read only.\n\n"
        .. "Updates are checked only when you choose Check for Updates.\n\n"
        .. moduleStatusText()
    )
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
                text = _("Reading Overview"),
                callback = function()
                    self:showReadingOverview()
                end,
            },

            {
                text = _("Stats & Patterns"),
                callback = function()
                    self:showStatsPager()
                end,
            },

            {
                text = _("Data & Sync"),
                sub_item_table = {
                    {
                        text = _("Sync Reading History"),
                        callback = function()
                            self:confirmRebuild()
                        end,
                    },
                    {
                        text = _("Data Status"),
                        callback = function()
                            self:showDataStatus()
                        end,
                    },
                },
            },

            {
                text = _("Settings & Updates"),
                sub_item_table = {
                    {
                        text = _("Check for Updates"),
                        callback = function()
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
                        text = _("Restore Previous Version"),
                        callback = function()
                            local Updater =
                                loadUpdater()

                            if Updater then
                                Updater:confirmRestore()
                            end
                        end,
                    },
                    {
                        text = _("About"),
                        callback = function()
                            self:showAbout()
                        end,
                    },
                },
            },
        },
    }
end

return ReadingBrain