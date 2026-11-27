-- =========================================================================
-- TERMINAL.LUA — Integrated Command Shell Overlay
-- =========================================================================
local utf8 = require("utf8")

local Terminal = {
    isOpen = false,
    input = "",
    history = { "Old Fool's Terminal — Type a command (e.g. ls -la) | [F3] Close" },
    maxLines = 12,
}

-- Main.lua backward compatibility aliases
Terminal.aberto = Terminal.isOpen
Terminal.historico = Terminal.history
Terminal.maxLinhas = Terminal.maxLines

-- Splits text by newline and pushes lines into the circular history buffer
local function addLine(text)
    text = tostring(text or "")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(Terminal.history, line)
    end
    while #Terminal.history > Terminal.maxLines do
        table.remove(Terminal.history, 1)
    end
end

-- Toggles terminal overlay visibility
function Terminal.toggle()
    Terminal.isOpen = not Terminal.isOpen
    Terminal.aberto = Terminal.isOpen
end

-- Executes shell commands defensively with captured output
function Terminal.execute(cmd)
    cmd = tostring(cmd or ""):match("^%s*(.-)%s*$")
    if cmd == "" then return end

    addLine("> " .. cmd)

    if cmd == "clear" or cmd == "cls" then
        Terminal.history = {}
        return
    end

    -- Run command and capture both stdout and stderr
    local ok, handle = pcall(io.popen, cmd .. " 2>&1")
    if ok and handle then
        local output = handle:read("*a")
        handle:close()
        if output and output ~= "" then
            addLine(output:gsub("%s+$", ""))
        else
            addLine("[OK]")
        end
    else
        addLine("[ERROR: Command execution failed]")
    end
end

Terminal.executar = Terminal.execute

-- Handles keyboard input safely
function Terminal.keypressed(key)
    if key == "f3" then
        Terminal.toggle()
        return true
    end
    if not Terminal.isOpen then return false end

    if key == "escape" then
        Terminal.isOpen = false
        Terminal.aberto = false
    elseif key == "return" or key == "kpenter" then
        Terminal.execute(Terminal.input)
        Terminal.input = ""
    elseif key == "backspace" then
        local offset = utf8.offset(Terminal.input, -1)
        if offset then
            Terminal.input = string.sub(Terminal.input, 1, offset - 1)
        else
            Terminal.input = ""
        end
    end
    return true
end

-- Captures character typing when terminal overlay is active
function Terminal.textinput(t)
    if not Terminal.isOpen then return false end
    Terminal.input = Terminal.input .. tostring(t or "")
    return true
end

-- Renders the terminal panel and command prompt
function Terminal.draw()
    if not Terminal.isOpen then return end

    local w, h = love.graphics.getDimensions()
    local tw, th = math.min(740, w - 40), 270
    local tx, ty = math.floor((w - tw) / 2), h - th - 24

    -- Background and perimeter frame
    love.graphics.setColor(0.06, 0.07, 0.10, 0.97)
    love.graphics.rectangle("fill", tx, ty, tw, th, 8, 8)
    love.graphics.setColor(0.20, 0.80, 0.45, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", tx, ty, tw, th, 8, 8)
    love.graphics.setLineWidth(1)

    -- Header bar
    love.graphics.setColor(0.20, 0.80, 0.45)
    love.graphics.print("TERMINAL [F3 to hide | 'clear' to wipe history]", tx + 14, ty + 10)

    -- Command output stream
    love.graphics.setColor(0.82, 0.88, 0.85)
    for i, line in ipairs(Terminal.history) do
        love.graphics.print(line, tx + 14, ty + 32 + (i - 1) * 16)
    end

    -- Prompt line with blinking cursor
    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "_" or ""
    love.graphics.setColor(1.0, 0.85, 0.35)
    love.graphics.print("$ " .. Terminal.input .. cursor, tx + 14, ty + th - 26)

    love.graphics.setColor(1, 1, 1, 1)
end

return Terminal