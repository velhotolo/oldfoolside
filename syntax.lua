-- syntax.lua
local syntax = {}

local palette = {
    normal      = { 0.85, 0.87, 0.92 }, -- Off-white text
    decl        = { 0.40, 0.75, 1.00 }, -- Sky blue: local, require, type
    func        = { 0.78, 0.45, 0.95 }, -- Purple/Magenta: function, defs
    flow        = { 0.95, 0.45, 0.35 }, -- Coral/Orange: if, then, while, for
    ret         = { 0.95, 0.30, 0.40 }, -- Crimson: return, break
    bool        = { 1.00, 0.60, 0.20 }, -- Warm Orange: true, false, nil
    types       = { 0.25, 0.85, 0.75 }, -- Cyan/Teal: number, string, boolean
    builtins    = { 0.90, 0.82, 0.35 }, -- Soft Gold: task, game, math, Vector3
    comment     = { 0.42, 0.46, 0.58 }, -- Muted Slate: -- comments
    str         = { 0.58, 0.88, 0.45 }, -- Emerald Green: strings "...", '...', `...`
    number      = { 1.00, 0.75, 0.40 }, -- Amber: numeric literals
    punct       = { 0.55, 0.60, 0.70 }, -- Punctuation & operators
}

local keywords = {
    ["local"]     = palette.decl,
    ["require"]   = palette.decl,
    ["type"]      = palette.decl,
    ["export"]    = palette.decl,

    ["function"]  = palette.func,
    ["typeof"]    = palette.func,

    ["if"]        = palette.flow,
    ["then"]      = palette.flow,
    ["elseif"]    = palette.flow,
    ["else"]      = palette.flow,
    ["end"]       = palette.flow,
    ["while"]     = palette.flow,
    ["do"]        = palette.flow,
    ["for"]       = palette.flow,
    ["in"]        = palette.flow,
    ["repeat"]    = palette.flow,
    ["until"]     = palette.flow,
    ["continue"]  = palette.flow,
    ["goto"]      = palette.flow,

    ["return"]    = palette.ret,
    ["break"]     = palette.ret,

    ["and"]       = palette.decl,
    ["or"]        = palette.decl,
    ["not"]       = palette.decl,

    ["true"]      = palette.bool,
    ["false"]     = palette.bool,
    ["nil"]       = palette.bool,

    ["number"]    = palette.types,
    ["string"]    = palette.types,
    ["boolean"]   = palette.types,
    ["any"]       = palette.types,
    ["unknown"]   = palette.types,
    ["never"]     = palette.types,
    ["thread"]    = palette.types,
    ["buffer"]    = palette.types,

    ["task"]      = palette.builtins,
    ["game"]      = palette.builtins,
    ["workspace"] = palette.builtins,
    ["script"]    = palette.builtins,
    ["math"]      = palette.builtins,
    ["table"]     = palette.builtins,
    ["string"]    = palette.builtins,
    ["Vector3"]   = palette.builtins,
    ["CFrame"]    = palette.builtins,
    ["Instance"]  = palette.builtins,
    ["Color3"]    = palette.builtins,
    ["UDim2"]     = palette.builtins,
    ["love"]      = palette.builtins
}

function syntax.highlightSyntax(line)
    line = tostring(line or "")
    if line == "" then return { palette.normal, "" } end

    local out = {}
    local len = #line
    local i = 1

    local function push(color, text)
        if text and #text > 0 then
            table.insert(out, color)
            table.insert(out, text)
        end
    end

    while i <= len do
        local c = line:sub(i, i)
        local c2 = line:sub(i, i + 1)

        -- 1. Comments
        if c2 == "--" then
            push(palette.comment, line:sub(i))
            break
        end

        -- 2. Strings ('...', "...", `...`)
        if c == '"' or c == "'" or c == "`" then
            local quote = c
            local start = i
            i = i + 1
            local escaped = false
            while i <= len do
                local cur = line:sub(i, i)
                if escaped then
                    escaped = false
                elseif cur == "\\" then
                    escaped = true
                elseif cur == quote then
                    i = i + 1
                    break
                end
                i = i + 1
            end
            push(palette.str, line:sub(start, i - 1))

        -- 3. Identifiers / Keywords
        elseif c:match("[%a_]") then
            local start = i
            while i <= len and line:sub(i, i):match("[%w_]") do
                i = i + 1
            end
            local word = line:sub(start, i - 1)
            push(keywords[word] or palette.normal, word)

        -- 4. Numbers (Hex, float, int)
        elseif c:match("%d") then
            local start = i
            while i <= len and line:sub(i, i):match("[%w%.]") do
                i = i + 1
            end
            push(palette.number, line:sub(start, i - 1))

        -- 5. Operators & Punctuation
        elseif c:match("[%p]") then
            push(palette.punct, c)
            i = i + 1

        -- 6. Whitespace
        else
            local start = i
            while i <= len and line:sub(i, i):match("%s") do
                i = i + 1
            end
            push(palette.normal, line:sub(start, i - 1))
        end
    end

    return out
end

return syntax