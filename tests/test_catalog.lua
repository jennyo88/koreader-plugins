local sidecars = {}
local DocSettings = {}
function DocSettings:hasSidecarFile(path) return sidecars[path] ~= nil end
function DocSettings:open(path)
    local entries = sidecars[path]
    return {readSetting = function(_, key) return entries[key] end}
end
package.preload["docsettings"] = function() return DocSettings end
package.preload["libs/libkoreader-lfs"] = function() return {} end
local catalog = dofile("minimalshelf.koplugin/catalog.lua")
local path = "/mnt/us/documents/Book.epub"
local reader = { get = function(_, _) return {pages = 130, series = "Story", series_index = 2} end }
local cache = { getDocProps = function(_, _) return {pages = 400, title = "Book"} end }
local a = catalog.infoFor(path, cache, reader)
assert(a.total_pages == 130 and a.page_source == "calibre")
assert(a.remaining == 130 and a.series_index == 2)
sidecars[path] = { doc_pages = 200, percent_finished = 0.4, summary = {status = "reading"} }
local b = catalog.infoFor(path, cache, reader)
assert(b.total_pages == 200 and b.page_source == "screen")
assert(b.remaining == 120 and b.status == "reading")
sidecars[path] = { percent_finished = 0.5, summary = {status = "reading"} }
local c = catalog.infoFor(path, cache, reader)
assert(c.total_pages == 130 and c.page_source == "calibre")
assert(c.remaining == 65)
sidecars[path] = { summary = {status = "complete"} }
assert(catalog.infoFor(path, cache, reader).remaining == 0)
local pdf = catalog.infoFor("/mnt/us/documents/Test.pdf",
    {getDocProps = function() return {pages = 25} end}, nil)
assert(pdf.total_pages == 25 and pdf.page_source == "document")
print("catalog fallback tests passed")
