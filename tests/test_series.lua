local series = dofile("minimalshelf.koplugin/series.lua")
local books = {
    {title="First",series="Example",series_index=1,status="complete",total_pages=80,remaining=0},
    {title="Third",series="Example",series_index=3,status="unread",total_pages=90,remaining=90},
    {title="Second",series="Example",series_index=2,status="complete",total_pages=150,remaining=0},
    {title="Other",status="unread",total_pages=55,remaining=55},
}
local groups = series.group(books)
assert(#groups == 1)
assert(groups[1].books[2].title == "Second")
local nextbook = series.next(books)
assert(#nextbook == 1 and nextbook[1].book.title == "Third")
local short = series.short(books, 100, false)
assert(#short == 2)
assert(series.badge(books[2]):find("#3", 1, true))
assert(series.badge({title="Calibre", total_pages=100, remaining=45, page_source="calibre"}) == "~45 left (Calibre)")
assert(series.badge({title="Rendered", total_pages=100, remaining=45, page_source="screen"}) == "45 left")
print("series tests passed")
