-- Pure Lua UI-construction smoke test with KOReader widgets stubbed.
-- This does not emulate rendering on a Kindle.
local function newclass()
    local base = {}
    function base:extend(proto)
        proto = proto or {}
        return setmetatable(proto, {__index=self})
    end
    function base:new(opts)
        opts = opts or {}
        setmetatable(opts, {__index=self})
        if opts.init then opts:init() end
        return opts
    end
    function base:getSize()
        return { w = self.width or (self.dimen and self.dimen.w) or 200,
                 h = self.height or (self.dimen and self.dimen.h) or 300 }
    end
    return base
end
local modules = {
    ["ffi/blitbuffer"]={COLOR_WHITE=255},
    ["ui/geometry"]={new=function(_,x) return x end},
    ["ui/gesturerange"]={new=function(_,x) return x end},
    ["ui/font"]={getFace=function() return {} end},
    ["gettext"]=function(x)return x end,
    ["device"]={screen={getWidth=function()return 1072 end,
                           getHeight=function()return 1448 end,
                           scaleBySize=function(_,x)return x end}},
    ["ui/uimanager"]={show=function(self,w)self.last=w end,
                      close=function(self,w)self.closed=w end},
    ["bookinfomanager"]={getBookInfo=function(_,filepath,cover)
        if filepath == "book1.epub" then
            return {has_cover=true,cover_w=300,cover_h=400,cover_bb={free=function()end}}
        end
        return nil
    end},
}
for _,name in ipairs({
    "ui/widget/container/centercontainer", "ui/widget/container/framecontainer",
    "ui/widget/horizontalgroup", "ui/widget/horizontalspan",
    "ui/widget/imagewidget", "ui/widget/container/inputcontainer",
    "ui/widget/textboxwidget", "ui/widget/textwidget",
    "ui/widget/verticalgroup", "ui/widget/verticalspan", "ui/widget/button",
}) do modules[name]=newclass() end
for name,mod in pairs(modules) do
    package.preload[name] = function() return mod end
end
local gallery = dofile(arg[1])
local ui = require("ui/uimanager")
local books={}
for i=1,7 do
    books[i]={path="book"..i..".epub",title="Book "..i,remaining=100}
end
assert(gallery.show("Library", books, function(book)return "100 left" end,
    function(book)end, function()end))
assert(ui.last.page == 1)
assert(ui.last.total_pages == 2)
ui.last:gotoPage(1)
assert(ui.last.page == 2)
assert(ui.closed.page == 1)
ui.last:onClose()
assert(ui.closed.page == 2)
print("cover gallery construction and pagination passed")
