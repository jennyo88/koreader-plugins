-- E Ink-first, paginated, fullscreen UI for KOReader.
-- No animations, networking, or file writes beyond Visual Library settings.
local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Button = require("ui/widget/button")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ImageWidget = require("ui/widget/imagewidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local VerticalSpan = require("ui/widget/verticalspan")
local CenterContainer = require("ui/widget/container/centercontainer")
local TopContainer = require("ui/widget/container/topcontainer")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local Screen = require("device").screen
local BookMoods = require("moods")
local Catalog = require("catalog")
local _ = require("gettext")

local WIDTH, HEIGHT = Screen:getWidth(), Screen:getHeight()
local function unit(n) return math.max(1, math.floor(n * math.min(WIDTH / 758, HEIGHT / 1024))) end
local GAP, MARGIN = unit(10), unit(18)
local W = WIDTH - MARGIN * 2
local WHITE = Blitbuffer.COLOR_WHITE
local GRAY = Blitbuffer.COLOR_LIGHT_GRAY
local BLACK = Blitbuffer.COLOR_BLACK

local function vspace(px) return VerticalSpan:new{width = px} end
local function hspace(px) return HorizontalSpan:new{width = px} end
local function row(widgets)
    local r = HorizontalGroup:new{ align = "center" }
    for _, w in ipairs(widgets) do r[#r+1] = w end
    return r
end
local function stack(widgets)
    local v = VerticalGroup:new{ align = "left" }
    for _, w in ipairs(widgets) do v[#v+1] = w end
    return v
end
local function txt(s, size, bold, width)
    return TextWidget:new{ text = s or "", face = Font:getFace("cfont", unit(size or 18)),
        bold = bold or false, max_width = width or W }
end
local function paragraph(s, width, size, height)
    return TextBoxWidget:new{ text = s or "", face = Font:getFace("cfont", unit(size or 17)),
        width = width or W, height = height, height_overflow_show_ellipsis = true, alignment = "left" }
end
local function btn(text, width, cb, opts)
    opts = opts or {}
    return Button:new{ text = text, width = math.floor(width), height = opts.height or unit(47),
        text_font_size = unit(opts.size or 19), text_font_bold = opts.bold ~= false,
        bordersize = opts.border == false and 0 or unit(1), padding = unit(5),
        callback = cb, enabled = opts.enabled ~= false, preselect = opts.selected or false }
end
local function two(a, b, aw, bw)
    aw = aw or math.floor((W - GAP)/2)
    bw = bw or W - GAP - aw
    return row{a(aw), hspace(GAP), b(bw)}
end
local function sectionTitle(t)
    return stack{vspace(unit(9)),txt(t,21,true),vspace(unit(8))}
end
local function getSetting(s, key)
    return s:readSetting(key) or {}
end
local function setSetting(s, key, value)
    s:saveSetting(key, value)
    s:flush()
end
local function contains(t, value)
    for i, v in ipairs(t) do if v == value then return i end end
    return nil
end
local function trunc(s,n)
    s = s or ""
    if #s <= n then return s end
    return s:sub(1,n-3) .. "..."
end

-- A true cover tile: shows a *previously cached* Cover Browser image where available.
-- Text-only placeholders are deliberate; we never open EPUBs to extract covers.
local CoverTile = InputContainer:extend{}
function CoverTile:init()
    local book, cover_w, cover_h = self.book, self.tile_width, self.cover_height
    local coverWidget
    local info
    if self.bookinfo then
        local ok, cached = pcall(function() return self.bookinfo:getBookInfo(book.path, true) end)
        if ok then info = cached end
    end
    if info and info.has_cover and info.cover_bb and not info.ignore_cover then
        coverWidget = ImageWidget:new{image = info.cover_bb, width = cover_w-unit(10),
            height = cover_h-unit(8), scale_factor = 0, image_disposable = true}
    else
        coverWidget = CenterContainer:new{dimen = Geom:new{w = cover_w-unit(10),h = cover_h-unit(8)},
            paragraph(trunc(book.title, 60), cover_w-unit(24), 17, cover_h-unit(20))}
    end
    local coverFrame = FrameContainer:new{
        bordersize = unit(2), padding = unit(3), background = WHITE,
        CenterContainer:new{dimen = Geom:new{w=cover_w-unit(10),h=cover_h-unit(8)}, coverWidget},
    }
    local caption = paragraph(trunc(book.title, 45),cover_w,16,unit(47))
    self[1] = stack{
        CenterContainer:new{dimen=Geom:new{w=cover_w,h=cover_h},coverFrame},
        vspace(unit(4)),
        caption,
    }
    self.dimen = Geom:new{w=cover_w,h=cover_h+unit(52)}
    self.ges_events = {
        TapCover = { GestureRange:new{ges="tap",range=self.dimen} },
        HoldCover = { GestureRange:new{ges="hold",range=self.dimen} },
    }
end
function CoverTile:onTapCover()
    if self.callback then self.callback() end
    return true
end
function CoverTile:onHoldCover()
    if self.callback then self.callback() end
    return true
end

-- Mark the library as a full-screen, opaque KOReader window so that the
-- compositor never skips/merges its repaint with the File Manager beneath it.
local VisualUI = InputContainer:extend{
    covers_fullscreen = true,
    modal = true,
}
function VisualUI:init()
    self.state = self.plugin._visual_state or {shelf="all",page_num=1,results_page=1,queue_page=1,
        selected=self.settings:readSetting("selected_moods") or {},mood_scope="all"}
    self.plugin._visual_state = self.state
    self.page = self.page or "home"
    self.dimen = Geom:new{x=0,y=0,w=WIDTH,h=HEIGHT}
    self:build()
    -- Back on devices that have a hardware back key.
    if require("device"):hasKeys() then
        self.key_events = self.key_events or {}
        self.key_events.VisualBack = {{ require("device").input.group.Back }}
    end
end
function VisualUI:onVisualBack()
    if self.page == "home" then self.plugin:closeVisual() else self:go("home") end
    return true
end
function VisualUI:go(page)
    self.plugin:showVisual(page)
end
function VisualUI:message(s)
    UIManager:show(require("ui/widget/infomessage"):new{text=s})
end
function VisualUI:details(book)
    self.state.book = book.path
    self:go("details")
end
function VisualUI:lookup(path)
    for _, b in ipairs(self.catalog) do if b.path == path then return b end end
    if Catalog.exists(path) then return {path=path,title=Catalog.fallback_title(path)} end
end
function VisualUI:header(text)
    return row{
        btn("Back",unit(112),function() if self.page=="home" then self.plugin:closeVisual() else self:go("home") end end,{size=16}),
        hspace(GAP),
        CenterContainer:new{dimen=Geom:new{w=W-unit(226)-2*GAP,h=unit(50)},txt(trunc(text,29),23,true)},
        hspace(GAP),
        btn("Close",unit(114),function() self.plugin:closeVisual() end,{size=16}),
    }
end
function VisualUI:footer()
    local labels = {{"Home","home"},{"Moods","moods"},{"Shelves","library"},{"Queue","queue"}}
    local widgets={}
    local width = math.floor((W-3*GAP)/4)
    for i, v in ipairs(labels) do
        if i>1 then widgets[#widgets+1]=hspace(GAP) end
        local nav = v[2]
        local w = i==4 and W-(3*width+3*GAP) or width
        widgets[#widgets+1]=btn(v[1],w,function() self.state.page_num=1;self:go(nav) end,
            {selected=self.page==nav,height=unit(54),size=17})
    end
    return row(widgets)
end
function VisualUI:cover(book, width, height)
    return CoverTile:new{book=book,bookinfo=self.bookinfo,tile_width=width,cover_height=height,
        callback=function() self:details(book) end}
end
function VisualUI:homeLayout()
    local content={sectionTitle("WHAT WOULD YOU LIKE TO READ?")}
    content[#content+1]=two(
        function(w) return btn("Find by mood",w,function() self:go("moods") end,{height=unit(80),size=22}) end,
        function(w) return btn("Surprise me",w,function() self:surprise() end,{height=unit(80),size=21}) end)
    content[#content+1]=vspace(unit(13))
    content[#content+1]=txt("CONTINUE READING",20,true)
    content[#content+1]=vspace(unit(7))
    local last = self:lookup(G_reader_settings:readSetting("lastfile"))
    if last then
        local hero_w=unit(139)
        content[#content+1]=row{
            self:cover(last,hero_w,unit(171)),hspace(unit(17)),
            stack{
                paragraph(last.title,W-hero_w-unit(24),21,unit(79)),
                btn("Continue book",W-hero_w-unit(24),function()self.plugin:openBook(last.path)end,
                    {height=unit(53),size=19}),
                vspace(unit(8)),
                btn("Book details",W-hero_w-unit(24),function()self:details(last)end,
                    {height=unit(45),size=16}),
            }
        }
    else
        content[#content+1]=paragraph("Your last opened EPUB will appear here.",W,18,unit(64))
    end
    content[#content+1]=sectionTitle("YOUR READING QUEUE")
    local queue = getSetting(self.settings,"queue")
    if #queue == 0 then
        content[#content+1]=paragraph("No books queued yet. Open any book in Shelves and select Add to queue.",W,18,unit(72))
    else
        for i=1,math.min(3,#queue) do
            local b=self:lookup(queue[i])
            if b then
                content[#content+1]=btn(i.."  "..trunc(b.title,52),W,function() self:details(b) end,{height=unit(50),size=18,bold=false})
                content[#content+1]=vspace(unit(5))
            end
        end
    end
    content[#content+1]=vspace(unit(10))
    content[#content+1]=two(
        function(w) return btn("Browse library",w,function() self.state.shelf="all";self:go("library") end,{height=unit(62),size=17}) end,
        function(w) return btn("Paused books",w,function() self.state.shelf="paused";self:go("library") end,{height=unit(62),size=17}) end)
    return stack(content)
end
function VisualUI:moodsLayout()
    local content={sectionTitle("WHAT ARE YOU IN THE MOOD FOR?"),
        paragraph("Select one or more feelings. Matches come from your book tags and existing EPUB keywords.",W,16,unit(66)),vspace(unit(8))}
    local chosen=self.state.selected or {}
    for i=1,#BookMoods.all,2 do
        local a,b=BookMoods.all[i],BookMoods.all[i+1]
        content[#content+1]=two(
            function(w) return btn((chosen[a.id] and "[x] " or "[ ] ")..a.text,w,function()
                chosen[a.id]=not chosen[a.id];self:go("moods") end,{height=unit(67),size=16,bold=chosen[a.id]}) end,
            function(w) return btn((chosen[b.id] and "[x] " or "[ ] ")..b.text,w,function()
                chosen[b.id]=not chosen[b.id];self:go("moods") end,{height=unit(67),size=16,bold=chosen[b.id]}) end)
        content[#content+1]=vspace(unit(8))
    end
    local cnt=0
    for _, m in ipairs(BookMoods.all) do if chosen[m.id] then cnt=cnt+1 end end
    content[#content+1]=vspace(unit(7))
    content[#content+1]=two(
        function(w) return btn("Clear selection",w,function() self.state.selected={};self:go("moods") end,{size=17}) end,
        function(w) return btn("Show matches ("..cnt..")",w,function()
            if cnt==0 then self:message("Choose at least one mood.");return end
            setSetting(self.settings,"selected_moods",chosen)
            self.state.results_page=1;self:go("results") end,{size=17,enabled=cnt>0}) end)
    return stack(content)
end
function VisualUI:filteredBooks()
    local shelf=self.state.shelf or "all"
    local catalog=self.catalog
    if shelf == "all" then
        if not self.state.search or self.state.search=="" then return catalog end
    end
    local out, bypath = {}, {}
    for _, b in ipairs(catalog) do bypath[b.path]=b end
    local function add(path)
        if bypath[path] and not contains(out,bypath[path]) then out[#out+1]=bypath[path] end
    end
    if shelf == "current" then
        add(G_reader_settings:readSetting("lastfile"))
    elseif shelf == "upnext" then
        for _, p in ipairs(getSetting(self.settings,"queue")) do add(p) end
    elseif shelf == "paused" or shelf == "quick" then
        local tags=getSetting(self.settings,shelf)
        for _, b in ipairs(catalog) do if tags[b.path] then out[#out+1]=b end end
    elseif shelf == "latest" then
        local ok, hist=pcall(require,"readhistory")
        if ok and hist then
            for _, it in ipairs(hist.hist or {}) do add(it.file) end
        end
    else
        for _, b in ipairs(catalog) do out[#out+1]=b end
    end
    if self.state.search and self.state.search~="" then
        local matched, q={}, self.state.search:lower()
        for _, b in ipairs(out) do
            if (b.title.." "..(b.author or "")):lower():find(q,1,true) then matched[#matched+1]=b end
        end
        return matched
    end
    return out
end
function VisualUI:pickShelf()
    local ButtonDialog=require("ui/widget/buttondialog")
    local dialog
    local rows={}
    local options={{"All books","all"},{"Current Reading","current"},
        {"Up Next","upnext"},{"Quick Read","quick"},{"Paused","paused"},{"Latest","latest"}}
    for i=1,#options,2 do
        local r={}
        for j=i,math.min(i+1,#options) do
            local v=options[j]
            r[#r+1]={text=(self.state.shelf==v[2] and "[x] " or "")..v[1],callback=function()
                UIManager:close(dialog);self.state.shelf=v[2];self.state.page_num=1;self:go("library") end}
        end
        rows[#rows+1]=r
    end
    dialog=ButtonDialog:new{title="Choose shelf",buttons=rows}
    UIManager:show(dialog)
end
function VisualUI:searchDialog()
    local InputDialog=require("ui/widget/inputdialog")
    local input
    input=InputDialog:new{title="Search library",input=self.state.search or "",input_hint="Title or author",
        buttons={{
            {text="Clear",callback=function() UIManager:close(input);self.state.search="";self.state.page_num=1;self:go("library") end},
            {text="Search",is_enter_default=true,callback=function()
                self.state.search=input:getInputText() or "";UIManager:close(input);self.state.page_num=1;self:go("library") end},
        }}}
    UIManager:show(input);input:onShowKeyboard()
end
function VisualUI:gallery(items, page_key, page_size)
    local content={}
    local page=self.state[page_key] or 1
    local pages=math.max(1,math.ceil(#items/page_size))
    if page>pages then page=pages;self.state[page_key]=page end
    local cols=3
    local tilew=math.floor((W-2*GAP)/3)
    local coverh=math.min(unit(219), math.floor(tilew*1.32))
    for i=1,page_size,3 do
        local tiles={}
        for j=0,2 do
            if j>0 then tiles[#tiles+1]=hspace(GAP) end
            local b=items[(page-1)*page_size+i+j]
            if b then tiles[#tiles+1]=self:cover(b, tilew, coverh)
            else tiles[#tiles+1]=hspace(tilew) end
        end
        content[#content+1]=row(tiles)
        content[#content+1]=vspace(unit(9))
    end
    content[#content+1]=two(
        function(w) return btn("< Previous",w,function() self.state[page_key]=math.max(1,page-1);self:go(self.page) end,{size=17,enabled=page>1}) end,
        function(w) return btn("Next >   "..page.."/"..pages,w,function()
            self.state[page_key]=math.min(pages,page+1);self:go(self.page) end,{size=17,enabled=page<pages}) end)
    return stack(content)
end
function VisualUI:libraryLayout()
    local items=self:filteredBooks()
    local labels={all="All books",current="Current Reading",upnext="Up Next",quick="Quick Read",paused="Paused",latest="Latest"}
    local content={sectionTitle((labels[self.state.shelf] or "All books").."  ("..#items..")")}
    content[#content+1]=two(
        function(w)return btn("Change shelf",w,function() self:pickShelf() end,{size=18}) end,
        function(w)return btn(self.state.search and self.state.search~="" and "Search: "..trunc(self.state.search,13) or "Search books",w,function()self:searchDialog()end,{size=17}) end)
    content[#content+1]=vspace(unit(15))
    if #items==0 then
        content[#content+1]=paragraph("There are no books on this shelf. Try All books or add books to this shelf from Book details.",W,18,unit(110))
    else
        content[#content+1]=self:gallery(items,"page_num",6)
    end
    return stack(content)
end
function VisualUI:resultsLayout()
    local ids={}
    for _, m in ipairs(BookMoods.all) do if self.state.selected[m.id] then ids[#ids+1]=m.id end end
    local tags=getSetting(self.settings,"mood_tags")
    local scope=self.state.mood_scope or "all"
    local eligible=self.catalog
    if scope=="unopened" then
        local seen={}
        local ok,hist=pcall(require,"readhistory")
        if ok and hist then for _,v in ipairs(hist.hist or {}) do seen[v.file]=true end end
        eligible={}
        for _,b in ipairs(self.catalog) do if not seen[b.path] then eligible[#eligible+1]=b end end
    end
    local matches=BookMoods.matches(eligible,ids,tags,
        scope=="paused" and getSetting(self.settings,"paused") or nil)
    local content={sectionTitle("MOOD MATCHES  ("..#matches..")")}
    local scopes={all="All books",unopened="Not opened here",paused="Paused only"}
    local next_scope={all="unopened",unopened="paused",paused="all"}
    content[#content+1]=two(
        function(w)return btn("Change moods",w,function()self:go("moods")end,{size=17}) end,
        function(w)return btn(scopes[scope],w,function()
            self.state.mood_scope=next_scope[scope];self.state.results_page=1;self:go("results") end,{size=17}) end)
    content[#content+1]=vspace(unit(9))
    if #matches==0 then
        content[#content+1]=paragraph("No matching books yet. Open a book in Shelves > Book details > Edit mood tags, or use existing EPUB keyword metadata.",W,18,unit(125))
    else
        content[#content+1]=paragraph("Ranked by how many selected moods each book matches. Open a cover to see why.",W,16,unit(58))
        local b={}
        for _, match in ipairs(matches) do b[#b+1]=match.book end
        content[#content+1]=self:gallery(b,"results_page",6)
    end
    return stack(content)
end
function VisualUI:queueLayout()
    local queue=getSetting(self.settings,"queue")
    local content={sectionTitle("READING QUEUE  ("..#queue..")"),
        paragraph("A flexible order. Use the arrow buttons to rearrange books.",W,16,unit(58))}
    if #queue==0 then
        content[#content+1]=paragraph("Your queue is empty. Browse Shelves, open a book, and tap Add to queue.",W,18,unit(105))
    else
        local start=(self.state.queue_page-1)*5+1
        for i=start,math.min(start+4,#queue) do
            local index,path=i,queue[i]
            local b=self:lookup(path) or {path=path,title="Missing book (remove)"}
            if b then
                local name_w=W-unit(200)
                content[#content+1]=row{
                    btn(i..". "..trunc(b.title,25),name_w,function() self:details(b) end,{height=unit(72),size=17}),hspace(unit(4)),
                    btn("^",unit(52),function()
                        if index>1 then queue[index],queue[index-1]=queue[index-1],queue[index];setSetting(self.settings,"queue",queue);self:go("queue") end
                    end,{height=unit(72),enabled=i>1}),hspace(unit(4)),
                    btn("v",unit(52),function()
                        if index<#queue then queue[index],queue[index+1]=queue[index+1],queue[index];setSetting(self.settings,"queue",queue);self:go("queue") end
                    end,{height=unit(72),enabled=i<#queue}),hspace(unit(4)),
                    btn("X",W-name_w-unit(116),function()
                        table.remove(queue,index);setSetting(self.settings,"queue",queue)
                        self.state.queue_page=math.max(1,math.min(self.state.queue_page,math.ceil(#queue/5)))
                        self:go("queue") end,{height=unit(72),size=17}),
                }
                content[#content+1]=vspace(unit(7))
            end
        end
        local pages=math.max(1,math.ceil(#queue/5))
        content[#content+1]=two(
            function(w)return btn("< Previous",w,function()self.state.queue_page=math.max(1,self.state.queue_page-1);self:go("queue")end,{enabled=self.state.queue_page>1})end,
            function(w)return btn("Next >  "..self.state.queue_page.."/"..pages,w,function()
                self.state.queue_page=math.min(pages,self.state.queue_page+1);self:go("queue") end,{enabled=self.state.queue_page<pages})end)
    end
    return stack(content)
end
function VisualUI:editMoodTags(book)
    local Dialog=require("ui/widget/buttondialog")
    local dialog
    local all=getSetting(self.settings,"mood_tags")
    local tags=all[book.path] or {}
    local rows={}
    for i=1,#BookMoods.all,2 do
        local r={}
        for j=i,i+1 do
            local m=BookMoods.all[j]
            r[#r+1]={text=(contains(tags,m.id) and "[x] " or "[ ] ")..m.text,
                callback=function()
                    local index=contains(tags,m.id)
                    if index then table.remove(tags,index) else tags[#tags+1]=m.id end
                    all[book.path]=tags
                    setSetting(self.settings,"mood_tags",all)
                    UIManager:close(dialog)
                    self:editMoodTags(book)
                end}
        end
        rows[#rows+1]=r
    end
    rows[#rows+1]={{text="Done",callback=function()UIManager:close(dialog);self:go("details")end}}
    dialog=Dialog:new{title="MOOD TAGS: "..trunc(book.title,31),buttons=rows}
    UIManager:show(dialog)
end
function VisualUI:detailsLayout()
    local b=self:lookup(self.state.book)
    if not b then return stack{sectionTitle("BOOK NOT FOUND"),
        btn("Return to library",W,function()self:go("library")end)} end
    local tags=BookMoods.tagsFor(b,getSetting(self.settings,"mood_tags"))
    local summaries={}
    for _, m in ipairs(BookMoods.all) do if tags[m.id] then summaries[#summaries+1]=m.text end end
    local moodText=#summaries>0 and table.concat(summaries,", ") or "No mood tags assigned yet"
    local queue=getSetting(self.settings,"queue")
    local paused=getSetting(self.settings,"paused")
    local quick=getSetting(self.settings,"quick")
    local content={sectionTitle("BOOK DETAILS")}
    local tile=self:cover(b,unit(158),unit(213))
    content[#content+1]=row{
        tile,hspace(unit(22)),
        stack{
            paragraph(b.title,W-unit(190),22,unit(96)),
            paragraph(trunc(b.author or "",50),W-unit(190),17,unit(54)),
            paragraph(trunc(b.series or "",50),W-unit(190),15,unit(51)),
        }
    }
    content[#content+1]=sectionTitle("MOOD PROFILE")
    content[#content+1]=paragraph(moodText,W,17,unit(73))
    content[#content+1]=vspace(unit(4))
    content[#content+1]=btn("Edit mood tags",W,function()self:editMoodTags(b)end,{size=19,height=unit(55)})
    content[#content+1]=vspace(unit(9))
    content[#content+1]=two(
        function(w)return btn(contains(queue,b.path) and "Remove from queue" or "Add to queue",w,function()
            local pos=contains(queue,b.path)
            if pos then table.remove(queue,pos) else queue[#queue+1]=b.path end
            setSetting(self.settings,"queue",queue);self:go("details") end,{size=16,height=unit(60)})end,
        function(w)return btn(paused[b.path] and "Resume (unpause)" or "Mark as paused",w,function()
            paused[b.path]=not paused[b.path] or nil;setSetting(self.settings,"paused",paused);self:go("details") end,{size=16,height=unit(60)})end)
    content[#content+1]=vspace(unit(8))
    content[#content+1]=two(
        function(w)return btn(quick[b.path] and "Remove Quick Read" or "Add Quick Read",w,function()
            quick[b.path]=not quick[b.path] or nil;setSetting(self.settings,"quick",quick);self:go("details")end,{size=16,height=unit(60)})end,
        function(w)return btn("Open this EPUB",w,function()self.plugin:openBook(b.path)end,{size=19,height=unit(60)})end)
    return stack(content)
end
function VisualUI:surprise()
    local ids={}
    for _, m in ipairs(BookMoods.all) do if self.state.selected[m.id] then ids[#ids+1]=m.id end end
    local matches=BookMoods.matches(self.catalog,ids,getSetting(self.settings,"mood_tags"))
    if #ids==0 or #matches==0 then
        self:go("moods")
        return
    end
    math.randomseed(os.time())
    local choice=matches[math.random(#matches)]
    self.state.book=choice.book.path
    self:go("details")
end
function VisualUI:build()
    local titles={home="VISUAL LIBRARY",moods="MOOD PICKER",library="YOUR BOOKSHELVES",
        results="YOUR MATCHES",queue="READING QUEUE",details="BOOK DETAILS"}
    local body
    if self.page=="home" then body=self:homeLayout()
    elseif self.page=="moods" then body=self:moodsLayout()
    elseif self.page=="library" then body=self:libraryLayout()
    elseif self.page=="results" then body=self:resultsLayout()
    elseif self.page=="queue" then body=self:queueLayout()
    elseif self.page=="details" then body=self:detailsLayout()
    else body=self:homeLayout() end
    local contents=stack{
        vspace(unit(12)),self:header(titles[self.page] or "VISUAL LIBRARY"),vspace(unit(12)),
        FrameContainer:new{bordersize=unit(1),padding=0,background=WHITE,body},
        vspace(unit(14)), self:footer(),
    }
    -- Outer white background fills the screen. The content is top-aligned.
    self[1]=FrameContainer:new{bordersize=0,padding=0,background=WHITE,
        TopContainer:new{dimen=Geom:new{w=WIDTH,h=HEIGHT},
            stack{hspace(0), -- empty horizontal span has zero height
                CenterContainer:new{dimen=Geom:new{w=WIDTH,h=contents:getSize().h},contents},
            }
        },
    }
end
return VisualUI
