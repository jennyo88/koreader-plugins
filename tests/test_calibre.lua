local calibre = dofile("minimalshelf.koplugin/calibre_pages.lua")
local entries = {
    {
        title = "A Tale",
        lpath = "Fantasy/A Tale.epub",
        series = "The Series",
        series_index = 2.5,
        user_metadata = { ["#pages"] = { ["#value#"] = 144 } },
    },
    {
        title = "Another",
        lpath = "Fantasy/Another.epub",
        user_metadata = { ["#pages"] = { ["#value#"] = nil },
                          ["#page_count"] = { ["#value#"] = 75 } },
    },
    {
        title = "No page count",
        lpath = "Fantasy/Blank.epub",
        user_metadata = { ["#pages"] = { ["#value#"] = "invalid" } },
    },
    {
        title = "Unsafe",
        lpath = "../../unrelated.epub",
        user_metadata = { ["#pages"] = { ["#value#"] = 80 } },
    },
}
assert(calibre.extractCount(entries[1]) == 144)
assert(calibre.extractCount(entries[2]) == 75)
assert(calibre.extractCount(entries[3]) == nil)
assert(calibre.extractCount({pages = 120}) == 120)
assert(calibre.extractCount({pages = "NaN"}) == nil)
assert(calibre.extractCount({pages = -2}) == nil)
assert(calibre.extractCount({pages = 1000000}) == nil)
local found = calibre.indexEntries("/mnt/us/documents", entries)
assert(found["/mnt/us/documents/Fantasy/A Tale.epub"].pages == 144)
assert(found["/mnt/us/documents/Fantasy/A Tale.epub"].series_index == 2.5)
assert(found["/mnt/us/documents/Fantasy/Another.epub"].pages == 75)
assert(found["/mnt/us/documents/Fantasy/Blank.epub"].pages == nil)
assert(found["/mnt/us/documents/../../unrelated.epub"] == nil)
assert(found["/mnt/us/documents/unrelated.epub"] == nil)
print("calibre tests passed")
