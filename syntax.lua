local syntax = {}

-- Color palette for syntax highlighting
local palette = {
    normal  = { 0.8, 0.8, 0.8 },
    decl    = { 0.3, 0.7, 0.9 },
    func    = { 0.8, 0.3, 0.6 },
    flow    = { 0.9, 0.6, 0.2 },
    ret     = { 0.9, 0.2, 0.2 },
    bool    = { 0.4, 0.8, 0.9 },
    comment = { 0.4, 0.4, 0.45 }
}

-- Map of Lua keywords to their corresponding palette colors
local keywords = {
    ["and"]      = palette.decl,
    ["local"]    = palette.decl,
    ["require"]  = palette.decl,
    ["function"] = palette.func,
    ["if"]       = palette.flow,
    ["until"]    = palette.flow,
    ["in"]       = palette.flow,
    ["goto"]     = palette.flow,
    ["then"]     = palette.flow,
    ["else"]     = palette.flow,
    ["elseif"]   = palette.flow,
    ["end"]      = palette.flow,
    ["for"]      = palette.flow,
    ["or"]       = palette.flow,
    ["while"]    = palette.flow,
    ["do"]       = palette.flow,
    ["not"]      = palette.ret,
    ["return"]   = palette.ret,
    ["repeat"]   = palette.ret,
    ["break"]    = palette.ret,
    ["true"]     = palette.bool,
    ["false"]    = palette.bool,
    ["nil"]      = palette.bool
}

-- Finds the starting index of an inline Lua comment ("--") outside of quoted strings
local function findCommentStart(lineText)
    local inSingle = false
    local inDouble = false
    local escaped  = false

    for i = 1, #lineText do
        local c = string.sub(lineText, i, i)
        if escaped then
            escaped = false
        elseif c == "\\" and (inSingle or inDouble) then
            escaped = true
        elseif c == "'" and not inDouble then
            inSingle = not inSingle
        elseif c == '"' and not inSingle then
            inDouble = not inDouble
        elseif not inSingle and not inDouble and c == "-" and string.sub(lineText, i + 1, i + 1) == "-" then
            return i
        end
    end

    return nil
end

-- Converts a single line of Lua code into a LÖVE coloredText table, supporting full-line and inline comments
function syntax.highlightSyntax(lineText)
    local colored = {}
    local commentStart = findCommentStart(lineText)
    local codePart = commentStart and string.sub(lineText, 1, commentStart - 1) or lineText
    local commentPart = commentStart and string.sub(lineText, commentStart) or nil

    -- Highlight keywords and separators in the code portion
    if codePart ~= "" then
        local lastEnd = 1
        for s, e in string.gmatch(codePart, "()%W+()") do
            local word = string.sub(codePart, lastEnd, s - 1)
            local sep = string.sub(codePart, s, e - 1)
            if word ~= "" then
                table.insert(colored, keywords[word] or palette.normal)
                table.insert(colored, word)
            end
            if sep ~= "" then
                table.insert(colored, palette.normal)
                table.insert(colored, sep)
            end
            lastEnd = e
        end

        local rest = string.sub(codePart, lastEnd)
        if rest ~= "" then
            table.insert(colored, keywords[rest] or palette.normal)
            table.insert(colored, rest)
        end
    end

    -- Append inline or full-line comment in comment color
    if commentPart and commentPart ~= "" then
        table.insert(colored, palette.comment)
        table.insert(colored, commentPart)
    end

    return colored
end

return syntax