-- Read-only bridge to KOReader's live EPUB annotations.
-- A checkpoint owns highlights after the preceding checkpoint through its own anchor.
local M = {}

local function compare(doc, a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or not doc or not doc.compareXPointers then return nil end
    local ok, result = pcall(doc.compareXPointers, doc, a, b)
    if not ok or type(result) ~= 'number' then return nil end
    -- KOReader returns positive when b follows a.
    return result
end

function M.forCheckpoint(doc, annotations, checkpoints, target)
    if not target or not target.xpointer or not doc or not doc.compareXPointers then
        return nil, 'This checkpoint has no comparable EPUB position.'
    end
    if compare(doc, target.xpointer, target.xpointer) == nil then
        return nil, 'This checkpoint position is no longer valid.'
    end
    local lower
    for _, checkpoint in ipairs(checkpoints or {}) do
        if checkpoint ~= target and checkpoint.xpointer then
            local before_target = compare(doc, checkpoint.xpointer, target.xpointer)
            if before_target and before_target > 0 then
                if not lower or (compare(doc, lower, checkpoint.xpointer) or 0) > 0 then
                    lower = checkpoint.xpointer
                end
            end
        end
    end
    local results = {}
    for _, item in ipairs(annotations or {}) do
        -- A saved highlight has a drawer and text. Bookmarks and image selections do not qualify.
        if type(item) == 'table' and item.drawer and type(item.text) == 'string'
           and item.text:match('%S') and type(item.pos0) == 'string' then
            local within_upper = compare(doc, item.pos0, target.xpointer)
            local after_lower = not lower or compare(doc, lower, item.pos0)
            if within_upper and within_upper >= 0 and after_lower and (not lower or after_lower > 0) then
                table.insert(results, item)
            end
        end
    end
    table.sort(results, function(a, b)
        return (compare(doc, a.pos0, b.pos0) or 0) > 0
    end)
    return results, nil, lower
end
return M
