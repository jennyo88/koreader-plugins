-- Threadlight 1.0: an offline, spoiler-aware memory trail for EPUBs.
-- All story content is entered by the reader; the plugin never scans book text.

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local TextViewer = require("ui/widget/textviewer")
local Menu = require("ui/widget/menu")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Event = require("ui/event")
local Dispatcher = require("dispatcher")
local _ = require("gettext")

local Threadlight = WidgetContainer:extend {
    name = "threadlight",
    is_doc_only = true,
}

local STORE_KEY = "threadlight_v1"
local PROMPT_KEY = "threadlight_return_prompt"

local function trim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shortened(s, length)
    s = (s or ""):gsub("[%c%s]+", " ")
    if #s > length then return s:sub(1, length - 3) .. "..." end
    return s
end

local function day(ts)
    if type(ts) ~= "number" then return "" end
    return os.date("%Y-%m-%d", ts)
end

local function labelAt(note)
    local p = math.floor(((tonumber(note.percent) or 0) * 100) + 0.5)
    return string.format("%d%% · %s", p, day(note.at))
end

function Threadlight:init()
    local saved = self.ui.doc_settings:readSetting(STORE_KEY)
    if type(saved) ~= "table" or saved.version ~= 1 then
        saved = { version = 1, checkpoints = {}, threads = {}, next_id = 1 }
    end
    saved.checkpoints = type(saved.checkpoints) == "table" and saved.checkpoints or {}
    saved.threads = type(saved.threads) == "table" and saved.threads or {}
    saved.next_id = tonumber(saved.next_id) or 1
    self.data = saved
    self.ui.menu:registerToMainMenu(self)
    Dispatcher:registerAction("threadlight_resume", {
        category = "none", event = "ThreadlightResume",
        title = _("Threadlight: recall the story"), reader = true,
    })
    Dispatcher:registerAction("threadlight_checkpoint", {
        category = "none", event = "ThreadlightCheckpoint",
        title = _("Threadlight: save a checkpoint"), reader = true,
    })
    Dispatcher:registerAction("threadlight_threads", {
        category = "none", event = "ThreadlightThreads",
        title = _("Threadlight: view story threads"), reader = true,
    })
end

function Threadlight:saveNow()
    self.ui.doc_settings:saveSetting(STORE_KEY, self.data)
    self.ui.doc_settings:flush()
end

function Threadlight:onSaveSettings()
    self.ui.doc_settings:saveSetting(STORE_KEY, self.data)
end

function Threadlight:onReaderReady()
    local old = tonumber(self.data.last_visit)
    self.days_away = old and math.max(0, math.floor((os.time() - old) / 86400)) or 0
    self.data.last_visit = os.time()
    self:saveNow()

    if G_reader_settings:isTrue(PROMPT_KEY) and self.days_away >= 7
        and (#self.data.checkpoints > 0 or #self.data.threads > 0) then
        UIManager:nextTick(function()
            if not self.ui.document then return end
            UIManager:show(ConfirmBox:new {
                text = string.format(_("Welcome back! You last opened this book %d days ago. Review your story notes?"), self.days_away),
                ok_text = _("Recall"),
                ok_callback = function() self:showResume() end,
            })
        end)
    end
end

function Threadlight:currentPosition()
    local doc = self.ui.document
    local xp
    if doc and doc.getXPointer then
        local ok, result = pcall(doc.getXPointer, doc)
        if ok and type(result) == "string" then xp = result end
    end
    local percent
    if self.ui.rolling and self.ui.rolling.getLastPercent then
        local ok, result = pcall(self.ui.rolling.getLastPercent, self.ui.rolling)
        if ok and type(result) == "number" then percent = result end
    end
    if type(percent) ~= "number" and self.view and self.view.footer then
        percent = self.view.footer.percent_finished
    end
    percent = math.max(0, math.min(1, tonumber(percent) or 0))
    return xp, percent
end

function Threadlight:newAnchor()
    local xp, percent = self:currentPosition()
    return { at = os.time(), xpointer = xp, percent = percent }
end

-- Compare native EPUB XPointers first. Percentage is a fallback only.
-- compareXPointers(a,b) returns 1 when b is after a.
function Threadlight:isVisible(note)
    local current_xp, current_percent = self:currentPosition()
    local doc = self.ui.document
    if note.xpointer and current_xp and doc and doc.compareXPointers then
        local ok, ordering = pcall(doc.compareXPointers, doc, note.xpointer, current_xp)
        if ok and type(ordering) == "number" then
            return ordering >= 0
        end
    end
    return (tonumber(note.percent) or 0) <= current_percent + 0.002
end

function Threadlight:nextId()
    local id = self.data.next_id
    self.data.next_id = id + 1
    return id
end

function Threadlight:message(text)
    UIManager:show(InfoMessage:new { text = text })
end

function Threadlight:showText(title, text)
    UIManager:show(TextViewer:new {
        title = title, text = text, text_type = "general",
    })
end

-- Paged, e-ink-friendly list (unlike a huge button dialog).
function Threadlight:showList(title, items, callback)
    if #items == 0 then
        self:message(_("Nothing here yet."))
        return
    end
    local menu = Menu:new {
        title = title,
        item_table = items,
        covers_fullscreen = true,
        is_borderless = true,
        onMenuSelect = function(menu_self, item)
            UIManager:close(menu_self)
            callback(item)
        end,
    }
    UIManager:show(menu)
end

function Threadlight:askOne(title, hint, initial, onSaved)
    local dialog
    dialog = InputDialog:new {
        title = title,
        input = initial or "",
        hint = hint,
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                local value = trim(dialog:getInputText())
                if value == "" then
                    self:message(_("Please enter a note first."))
                    return
                end
                UIManager:close(dialog)
                onSaved(value)
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Threadlight:askTwo(title, first, second, values, onSaved)
    local dialog
    dialog = MultiInputDialog:new {
        title = title,
        fields = {
            { description = first, hint = first, text = values and values[1] or "" },
            { description = second, hint = second, text = values and values[2] or "" },
        },
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), callback = function()
                local raw = dialog:getFields()
                local a, b = trim(raw[1]), trim(raw[2])
                if a == "" then
                    self:message(_("The first field is required."))
                    return
                end
                UIManager:close(dialog)
                onSaved(a, b)
            end },
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Threadlight:addCheckpoint()
    self:askTwo(_("Save a story checkpoint"), _("What just happened?"),
        _("What should I remember next time?"), nil, function(what, remember)
        local card = self:newAnchor()
        card.id = self:nextId()
        card.what, card.remember = what, remember
        table.insert(self.data.checkpoints, card)
        self:saveNow()
        self:message(_("Checkpoint saved at your current place."))
    end)
end

function Threadlight:visibleCheckpoints()
    local found = {}
    for _, card in ipairs(self.data.checkpoints) do
        if self:isVisible(card) then table.insert(found, card) end
    end
    -- Creation order preserves "most recent memory" when re-reading.
    return found
end

function Threadlight:showResume()
    local checkpoints = self:visibleCheckpoints()
    local chunks = {}
    if self.days_away and self.days_away >= 1 then
        table.insert(chunks, string.format(_("Days since previous visit: %d"), self.days_away))
    end
    table.insert(chunks, _("YOUR LAST CHECKPOINTS"))
    if #checkpoints == 0 then
        table.insert(chunks, _("No checkpoints behind your current position."))
    else
        for i = #checkpoints, math.max(1, #checkpoints - 2), -1 do
            local c = checkpoints[i]
            table.insert(chunks, "\n" .. labelAt(c) .. "\n" .. c.what)
            if c.remember ~= "" then table.insert(chunks, _("Remember: ") .. c.remember) end
        end
    end
    table.insert(chunks, "\n" .. _("STILL-OPEN STORY THREADS"))
    local count = 0
    for _, thread in ipairs(self.data.threads) do
        local visible = self:visibleEntries(thread)
        if #visible > 0 and self:threadIsOpen(visible) then
            count = count + 1
            if count <= 10 then
                local recent = visible[#visible]
                local latest_note = ""
                for i = #visible, 1, -1 do
                    if visible[i].text ~= "" then
                        latest_note = visible[i].text
                        break
                    end
                end
                table.insert(chunks, "\n" .. thread.name .. " (" .. labelAt(recent) .. ")")
                if latest_note ~= "" then table.insert(chunks, latest_note) end
            end
        end
    end
    if count == 0 then table.insert(chunks, _("No open threads behind your current position.")) end
    if count > 10 then table.insert(chunks, string.format(_("...plus %d more (see Story threads)."), count - 10)) end
    table.insert(chunks, "\n" .. _("Only notes from this point or earlier are shown. Nothing is summarized automatically."))
    self:showText(_("Threadlight · Previously"), table.concat(chunks, "\n"))
end

function Threadlight:jumpTo(note)
    if not note.xpointer or not self.ui.rolling then
        self:message(_("This note has no EPUB location anchor."))
        return
    end
    local doc = self.ui.document
    if doc and doc.compareXPointers then
        local ok, valid = pcall(doc.compareXPointers, doc, note.xpointer, note.xpointer)
        if not ok or valid == nil then
            self:message(_("The saved location is no longer valid for this EPUB."))
            return
        end
    end
    if self.ui.link and self.ui.link.addCurrentLocationToStack then
        self.ui.link:addCurrentLocationToStack()
    end
    self.ui:handleEvent(Event:new("GotoXPointer", note.xpointer))
end

function Threadlight:showCheckpoint(card)
    local choices = {
        { text = _("Read checkpoint"), action = function()
            local msg = labelAt(card) .. "\n\n" .. card.what
            if card.remember ~= "" then msg = msg .. "\n\n" .. _("Remember: ") .. card.remember end
            self:showText(_("Story checkpoint"), msg)
        end },
        { text = _("Jump to saved position"), action = function() self:jumpTo(card) end },
        { text = _("Edit checkpoint"), action = function()
            self:askTwo(_("Edit checkpoint"), _("What happened?"), _("Remember"),
                { card.what, card.remember }, function(a, b)
                card.what, card.remember = a, b
                self:saveNow()
                self:message(_("Checkpoint updated."))
            end)
        end },
        { text = _("Delete checkpoint"), action = function()
            UIManager:show(ConfirmBox:new {
                text = _("Delete this checkpoint permanently?"),
                ok_text = _("Delete"), ok_callback = function()
                    for i, value in ipairs(self.data.checkpoints) do
                        if value.id == card.id then table.remove(self.data.checkpoints, i) break end
                    end
                    self:saveNow()
                end,
            })
        end },
    }
    self:showList(_("Checkpoint actions"), choices, function(item) item.action() end)
end

function Threadlight:showCheckpoints()
    local visible = self:visibleCheckpoints()
    local items = {}
    for i = #visible, 1, -1 do
        local card = visible[i]
        table.insert(items, {
            text = string.format("%s  %s", labelAt(card), shortened(card.what, 45)),
            card = card,
        })
    end
    self:showList(_("Story checkpoints"), items, function(item) self:showCheckpoint(item.card) end)
end

function Threadlight:visibleEntries(thread)
    local found = {}
    for _, entry in ipairs(thread.entries or {}) do
        if self:isVisible(entry) then table.insert(found, entry) end
    end
    return found
end

function Threadlight:threadIsOpen(visible)
    local open = false
    for _, entry in ipairs(visible) do
        if entry.kind == "start" or entry.kind == "reopened" then open = true end
        if entry.kind == "resolved" then open = false end
    end
    return open
end

function Threadlight:appendThreadEntry(thread, kind, text)
    local entry = self:newAnchor()
    entry.kind, entry.text = kind, text or ""
    table.insert(thread.entries, entry)
    self:saveNow()
end

function Threadlight:addThread()
    self:askTwo(_("Start a story thread"), _("Thread name or question"),
        _("What do I know so far?"), nil, function(name, note)
        local t = { id = self:nextId(), name = name, entries = {} }
        table.insert(self.data.threads, t)
        self:appendThreadEntry(t, "start", note)
        self:message(_("Story thread started."))
    end)
end

function Threadlight:readThread(thread)
    local entries = self:visibleEntries(thread)
    local parts = { thread.name, "" }
    for _, e in ipairs(entries) do
        local status = ""
        if e.kind == "start" then status = _("Started")
        elseif e.kind == "resolved" then status = _("Resolved")
        elseif e.kind == "reopened" then status = _("Reopened")
        else status = _("Update") end
        table.insert(parts, string.format("%s · %s", status, labelAt(e)))
        if e.text ~= "" then table.insert(parts, e.text) end
        table.insert(parts, "")
    end
    self:showText(_("Story thread"), table.concat(parts, "\n"))
end

function Threadlight:showThread(thread)
    local entries = self:visibleEntries(thread)
    local active = self:threadIsOpen(entries)
    local items = {
        { text = _("Read thread history"), action = function() self:readThread(thread) end },
        { text = _("Add an update"), action = function()
            self:askOne(_("Update: ") .. shortened(thread.name, 35),
                _("What changed?"), "", function(note)
                self:appendThreadEntry(thread, "note", note)
                self:message(_("Thread updated."))
            end)
        end },
        { text = active and _("Mark thread resolved") or _("Reopen thread"), action = function()
            self:appendThreadEntry(thread, active and "resolved" or "reopened", "")
            self:message(active and _("Thread resolved at this position.")
                or _("Thread reopened at this position."))
        end },
        { text = _("Jump to last entry"), action = function()
            if entries[#entries] then self:jumpTo(entries[#entries]) end
        end },
        { text = _("Rename thread"), action = function()
            self:askOne(_("Rename story thread"), _("Name"), thread.name, function(name)
                thread.name = name
                self:saveNow()
            end)
        end },
        { text = _("Delete thread"), action = function()
            UIManager:show(ConfirmBox:new {
                text = _("Delete this thread and all its notes permanently?"),
                ok_text = _("Delete"), ok_callback = function()
                    for i, item in ipairs(self.data.threads) do
                        if item.id == thread.id then table.remove(self.data.threads, i) break end
                    end
                    self:saveNow()
                end,
            })
        end },
    }
    self:showList(shortened(thread.name, 52), items, function(item) item.action() end)
end

function Threadlight:showThreads()
    local open, closed = {}, {}
    for _, t in ipairs(self.data.threads) do
        local visible = self:visibleEntries(t)
        if #visible > 0 then
            local item = { text = shortened(t.name, 58), thread = t,
                mandatory = self:threadIsOpen(visible) and _("Open") or _("Resolved") }
            table.insert(self:threadIsOpen(visible) and open or closed, item)
        end
    end
    for _, entry in ipairs(closed) do table.insert(open, entry) end
    self:showList(_("Story threads"), open, function(item) self:showThread(item.thread) end)
end

function Threadlight:showHelp()
    self:showText(_("About Threadlight"), _([[Threadlight is a personal, offline memory trail for readers who move between books.

CHECKPOINTS: In two short lines, record what happened and what you want your future self to remember.

THREADS: Track a mystery, character, relationship, or theory over several scenes. Update it as you read and resolve it when the question is answered.

SPOILER CURTAIN: When you move backward through an EPUB, notes saved farther ahead are hidden from your lists and recap. Revisit that place to reveal them again. This uses EPUB text-position anchors where possible, then an approximate reading percentage.

RESUME: 'Previously' gathers your latest visible checkpoints and open threads. It does not invent a recap or send text anywhere.

STORAGE: Notes live in this EPUB's KOReader sidecar settings. Back up your .sdr folders before moving or replacing book files. Removing the plugin does not intentionally delete notes.

GESTURES: The gesture manager exposes three Threadlight actions: Recall the story, Save a checkpoint, and Story threads.

COMPATIBILITY: Intended for reflowable EPUBs on KOReader. No Internet, images, external binaries, or background indexing needed.]]))
end

function Threadlight:addToMainMenu(menu_items)
    menu_items.threadlight = {
        text = _("Threadlight"),
        enabled_func = function() return self.ui.rolling ~= nil end,
        sub_item_table = {
            { text = _("Previously..."), callback = function() self:showResume() end },
            { text = _("Save a checkpoint"), callback = function() self:addCheckpoint() end },
            { text = _("Story checkpoints"), callback = function() self:showCheckpoints() end },
            { text = _("Start a story thread"), separator = true,
                callback = function() self:addThread() end },
            { text = _("Story threads"), callback = function() self:showThreads() end },
            { text = _("Remind me after 7 days away"), separator = true,
                checked_func = function() return G_reader_settings:isTrue(PROMPT_KEY) end,
                callback = function()
                    G_reader_settings:saveSetting(PROMPT_KEY, not G_reader_settings:isTrue(PROMPT_KEY))
                end },
            { text = _("How it works / backups"), callback = function() self:showHelp() end },
        },
    }
end

function Threadlight:onThreadlightResume() self:showResume() return true end
function Threadlight:onThreadlightCheckpoint() self:addCheckpoint() return true end
function Threadlight:onThreadlightThreads() self:showThreads() return true end

return Threadlight
