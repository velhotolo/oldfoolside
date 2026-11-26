-- syntax.lua
local syntax = {}

local palette = {
    normal   = { 0.85, 0.85, 0.85 },
    decl     = { 0.30, 0.70, 0.90 }, -- local, require, type, export
    func     = { 0.85, 0.35, 0.65 }, -- function, typeof
    flow     = { 0.95, 0.60, 0.20 }, -- if, then, continue, while
    ret      = { 0.90, 0.25, 0.25 }, -- return, break
    bool     = { 0.40, 0.80, 0.90 }, -- true, false, nil
    types    = { 0.35, 0.85, 0.75 }, -- number, string, boolean, any, buffer
    builtins = { 0.90, 0.80, 0.40 }, -- task, game, workspace, Vector3
    comment  = { 0.40, 0.42, 0.48 },
    str      = { 0.55, 0.85, 0.45 } -- Strings e crases
}

local keywords = {
    -- Lua padrão
    ["and"]       = palette.decl,
    ["local"]     = palette.decl,
    ["require"]   = palette.decl,
    ["function"]  = palette.func,
    ["if"]        = palette.flow,
    ["until"]     = palette.flow,
    ["in"]        = palette.flow,
    ["goto"]      = palette.flow,
    ["then"]      = palette.flow,
    ["else"]      = palette.flow,
    ["elseif"]    = palette.flow,
    ["end"]       = palette.flow,
    ["for"]       = palette.flow,
    ["or"]        = palette.flow,
    ["while"]     = palette.flow,
    ["do"]        = palette.flow,
    ["not"]       = palette.decl,
    ["return"]    = palette.ret,
    ["repeat"]    = palette.flow,
    ["break"]     = palette.ret,
    ["true"]      = palette.bool,
    ["false"]     = palette.bool,
    ["nil"]       = palette.bool,

    -- Extensões Luau
    ["continue"]  = palette.flow,
    ["type"]      = palette.decl,
    ["export"]    = palette.decl,
    ["typeof"]    = palette.func,

    -- Tipos primitivos do Luau
    ["number"]    = palette.types,
    ["string"]    = palette.types,
    ["boolean"]   = palette.types,
    ["any"]       = palette.types,
    ["unknown"]   = palette.types,
    ["never"]     = palette.types,
    ["thread"]    = palette.types,
    ["buffer"]    = palette.types,

    -- Globais frequentes de Luau / Roblox
    ["task"]      = palette.builtins,
    ["game"]      = palette.builtins,
    ["workspace"] = palette.builtins,
    ["script"]    = palette.builtins,
    ["Vector3"]   = palette.builtins,
    ["CFrame"]    = palette.builtins,
    ["Instance"]  = palette.builtins,
    ["Color3"]    = palette.builtins,
    ["UDim2"]     = palette.builtins
}

-- Detects Luau stuff
local function findCommentStart(lineText)
    local inSingle   = false
    local inDouble   = false
    local inBacktick = false
    local escaped    = false

    for i = 1, #lineText do
        local c = string.sub(lineText, i, i)
        if escaped then
            escaped = false
        elseif c == "\\" and (inSingle or inDouble or inBacktick) then
            escaped = true
        elseif c == "'" and not inDouble and not inBacktick then
            inSingle = not inSingle
        elseif c == '"' and not inSingle and not inBacktick then
            inDouble = not inDouble
        elseif c == '`' and not inSingle and not inDouble then
            inBacktick = not inBacktick
        elseif not inSingle and not inDouble and not inBacktick and c == "-" and string.sub(lineText, i + 1, i + 1) == "-" then
            return i
        end
    end

    return nil
end

function syntax.highlightSyntax(lineText)
    local colored = {}
    local commentStart = findCommentStart(lineText)
    local codePart = commentStart and string.sub(lineText, 1, commentStart - 1) or lineText
    local commentPart = commentStart and string.sub(lineText, commentStart) or nil

    if codePart ~= "" then
        local lastEnd = 1
        -- Capture alphanumeric tokens isolating punctuation
        for s, e in string.gmatch(codePart, "()[%w_]+()") do
            local sep = string.sub(codePart, lastEnd, s - 1)
            local word = string.sub(codePart, s, e - 1)

            if sep ~= "" then
                -- Highlight string
                if sep:find("`") or sep:find('"') or sep:find("'") then
                    table.insert(colored, palette.str)
                else
                    table.insert(colored, palette.normal)
                end
                table.insert(colored, sep)
            end

            if word ~= "" then
                table.insert(colored, keywords[word] or palette.normal)
                table.insert(colored, word)
            end
            lastEnd = e
        end

        local rest = string.sub(codePart, lastEnd)
        if rest ~= "" then
            if rest:find("`") or rest:find('"') or rest:find("'") then
                table.insert(colored, palette.str)
            else
                table.insert(colored, keywords[rest] or palette.normal)
            end
            table.insert(colored, rest)
        end
    end

    if commentPart and commentPart ~= "" then
        table.insert(colored, palette.comment)
        table.insert(colored, commentPart)
    end

    return colored
end

return syntax

