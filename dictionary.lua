-- dictionary.lua
local dictionary = {
    -- Standard Lua
    "and", "break", "do", "else", "elseif", "end", "false", "for", "goto", "if", "in",
    "nil", "not", "or", "repeat", "then", "true", "until", "while", "math.floor", "math.max", "string.sub",
    "string.match", "table.insert", "table.remove", "function", "local", "return",
    "_G", "_VERSION", "assert", "collectgarbage", "dofile", "error", "getfenv",
    "getmetatable", "ipairs", "load", "loadfile", "loadstring", "module", "next",
    "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "require", "select",
    "setfenv", "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
    "coroutine.create", "coroutine.isyieldable", "coroutine.resume",
    "coroutine.running", "coroutine.status", "coroutine.wrap", "coroutine.yield",
    "string.byte", "string.char", "string.dump", "string.find", "string.format",
    "string.gmatch", "string.gsub", "string.len", "string.lower", "string.rep",
    "string.reverse", "string.upper",
    "table.concat", "table.maxn", "table.move", "table.sort",
    "math.abs", "math.acos", "math.asin", "math.atan", "math.atan2", "math.ceil",
    "math.cos", "math.cosh", "math.deg", "math.exp", "math.fmod", "math.frexp",
    "math.huge", "math.ldexp", "math.log", "math.log10", "math.min", "math.modf",
    "math.pi", "math.pow", "math.rad", "math.random", "math.randomseed", "math.sin",
    "math.sinh", "math.sqrt", "math.tan", "math.tanh",
    "io.close", "io.flush", "io.input", "io.lines", "io.open", "io.output", "io.popen",
    "io.read", "io.stderr", "io.stdin", "io.stdout", "io.tmpfile", "io.type", "io.write",
    "os.clock", "os.date", "os.difftime", "os.execute", "os.exit", "os.getenv",
    "os.remove", "os.rename", "os.setlocale", "os.time", "os.tmpname",

    -- LÖVE 11.5 Callbacks e Modules 
    "love.graphics.print", "love.graphics.rectangle", "love.graphics.setColor", "love.graphics.clear",
    "love.graphics.draw", "love.graphics.newImage", "love.graphics.newFont", "love.graphics.setScissor",
    "love.window.setTitle", "love.window.setMode", "love.keyboard.isDown", "love.timer.getTime",

    -- Luau / Roblox Keywords e Ttypes
    "continue", "export", "typeof",
    "number", "string", "boolean", "any", "unknown", "never", "buffer",

    -- Luau Task Library
    "task.wait", "task.spawn", "task.delay", "task.defer", "task.cancel",

    -- Roblox Globals and Constructors
    "game", "workspace", "script", "Enum", "Instance.new",
    "Vector3.new", "Vector3.zero", "Vector3.one",
    "CFrame.new", "CFrame.Angles", "CFrame.lookAt",
    "Color3.new", "Color3.fromRGB", "Color3.fromHex",
    "UDim2.new", "UDim2.fromScale", "UDim2.fromOffset"
}

local macros = {
    -- Macros
    ["func"]         = { "local function name()", "    ", "end" },
    ["funcg"]        = { "function name()", "    ", "end" },
    ["funca"]        = { "function()", "    ", "end" },
    ["if"]           = { "if condition then", "    ", "end" },
    ["ifelse"]       = { "if condition then", "    ", "else", "    ", "end" },
    ["while"]        = { "while condition do", "    ", "end" },
    ["repeat"]       = { "repeat", "    ", "until condition" },
    ["for"]          = { "for i = 1, 10 do", "    ", "end" },
    ["forpairs"]     = { "for k, v in pairs(tbl) do", "    ", "end" },
    ["foripairs"]    = { "for i, v in ipairs(tbl) do", "    ", "end" },

    -- Specific Macros for Luau / Roblox
    ["luau_type"]    = { "type Props = {", "    ", "}" },
    ["luau_export"]  = { "export type Props = {", "    ", "}" },
    ["luau_spawn"]   = { "task.spawn(function()", "    ", "end)" },
    ["luau_delay"]   = { "task.delay(1, function()", "    ", "end)" },
    ["luau_service"] = { 'local Service = game:GetService("ServiceName")' },
    ["luau_class"]   = {
        "local Class = {}",
        "Class.__index = Class",
        "",
        "function Class.new()",
        "    local self = setmetatable({}, Class)",
        "    return self",
        "end",
        "",
        "return Class"
    }
}

return { dictionary = dictionary, macros = macros }

