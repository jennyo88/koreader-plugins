-- Moods are emotional signals, not genre categories. Tags are explicitly editable.
local Moods = {}
Moods.all = {
    { id = "yearning", text = "Yearning" },
    { id = "comfort", text = "Comforting" },
    { id = "atmosphere", text = "Atmospheric" },
    { id = "heartbreak", text = "Heart-wrenching" },
    { id = "immersive", text = "Immersive" },
    { id = "suspense", text = "Suspenseful" },
    { id = "thoughtful", text = "Thought-provoking" },
    { id = "light", text = "Light & fun" },
}
local patterns = {
    yearning = {"yearning", "longing", "slow burn"},
    comfort = {"cozy", "cosy", "comfort", "gentle"},
    atmosphere = {"gothic", "atmospheric", "dark academia"},
    heartbreak = {"heartbreaking", "heart-wrenching", "tearjerker"},
    immersive = {"epic fantasy", "immersive", "sweeping"},
    suspense = {"suspense", "thriller", "mystery", "horror"},
    thoughtful = {"philosophical", "literary fiction", "existential"},
    light = {"humor", "humour", "romcom", "feel-good", "comedy"},
}
function Moods.display(id)
    for _, mood in ipairs(Moods.all) do
        if mood.id == id then return mood.text end
    end
    return id
end
function Moods.tagsFor(book, manual)
    local tags = {}
    local assigned = manual[book.path] or {}
    for _, id in ipairs(assigned) do tags[id] = "your tag" end
    local keywords = type(book.keywords) == "string" and book.keywords:lower() or ""
    for id, hints in pairs(patterns) do
        if not tags[id] then
            for _, hint in ipairs(hints) do
                -- Only metadata keywords, not guesses from book titles or authors.
                if keywords:find(hint, 1, true) then tags[id] = "Calibre/EPUB keywords"; break end
            end
        end
    end
    return tags
end
function Moods.matches(catalog, selected, manual, paused_only)
    local out = {}
    for _, book in ipairs(catalog) do
        if not paused_only or paused_only[book.path] then
            local tags = Moods.tagsFor(book, manual)
            local score, why = 0, {}
            for _, id in ipairs(selected) do
                if tags[id] then
                    score = score + 1
                    why[#why + 1] = Moods.display(id)
                end
            end
            if score > 0 then
                out[#out + 1] = { book = book, score = score, reason = table.concat(why, " + ") }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.score == b.score then return a.book.title:lower() < b.book.title:lower() end
        return a.score > b.score
    end)
    return out
end
return Moods
