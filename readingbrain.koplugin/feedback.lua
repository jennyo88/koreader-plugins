local Feedback = {}

function Feedback:get(book)
    return nil
end

function Feedback:set(book, value)
    return true
end

function Feedback:clear(book)
end

function Feedback:apply(candidates)
    return candidates or {}
end

function Feedback:label(book)
    return nil
end

return Feedback
