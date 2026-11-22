-- Integrated command-line terminal overlay toggled with F3
local Terminal = {
    aberto = false,
    input = "",
    historico = { "Old Fool's Terminal — Digite um comando (ex: touch bestiario.lua) | [F3] Fechar" },
    maxLinhas = 12,
}

-- Splits output text by newlines and appends it to the terminal history buffer
local function addLinha(texto)
    for linha in (texto .. "\n"):gmatch("(.-)\n") do
        table.insert(Terminal.historico, linha)
    end
    while #Terminal.historico > Terminal.maxLinhas do
        table.remove(Terminal.historico, 1)
    end
end

-- Toggles the terminal overlay open or closed
function Terminal.toggle()
    Terminal.aberto = not Terminal.aberto
end

-- Executes a shell command, captures stdout/stderr, and prints the result to the terminal
function Terminal.executar(cmd)
    cmd = cmd:match("^%s*(.-)%s*$") -- Trim leading and trailing whitespace
    if cmd == "" then return end

    addLinha("> " .. cmd)

    if cmd == "clear" or cmd == "cls" then
        Terminal.historico = {}
        return
    end

    -- Run command in the system shell and capture both stdout and stderr (2>&1)
    local handle = io.popen(cmd .. " 2>&1")
    if handle then
        local saida = handle:read("*a")
        handle:close()
        if saida and saida ~= "" then
            addLinha(saida:gsub("%s+$", ""))
        else
            addLinha("[OK]")
        end
    else
        addLinha("[ERRO ao executar comando]")
    end
end

-- Handles terminal key events; returns true when the key is consumed so the editor ignores it
function Terminal.keypressed(key)
    if key == "f3" then
        Terminal.toggle()
        return true
    end
    if not Terminal.aberto then return false end

    if key == "escape" then
        Terminal.aberto = false
    elseif key == "return" or key == "kpenter" then
        Terminal.executar(Terminal.input)
        Terminal.input = ""
    elseif key == "backspace" then
        -- Remove the last UTF-8 character from the input line
        local byteoffset = #Terminal.input
        while byteoffset > 0 do
            local b = string.byte(Terminal.input, byteoffset)
            byteoffset = byteoffset - 1
            if b < 128 or b >= 192 then break end
        end
        Terminal.input = string.sub(Terminal.input, 1, byteoffset)
    end
    return true
end

-- Appends typed characters to the terminal input buffer when the terminal is open
function Terminal.textinput(t)
    if not Terminal.aberto then return false end
    Terminal.input = Terminal.input .. t
    return true
end

-- Renders the terminal overlay, command history, and blinking prompt at the bottom of the screen
function Terminal.draw()
    if not Terminal.aberto then return end

    local w, h = love.graphics.getDimensions()
    local tw, th = math.min(720, w - 40), 270
    local tx, ty = (w - tw) / 2, h - th - 20

    -- Background and border (drawn on top of the editor)
    love.graphics.setColor(0.05, 0.06, 0.09, 0.96)
    love.graphics.rectangle("fill", tx, ty, tw, th, 8, 8)
    love.graphics.setColor(0.35, 0.90, 0.50)
    love.graphics.rectangle("line", tx, ty, tw, th, 8, 8)

    -- Title bar
    love.graphics.setColor(0.35, 0.90, 0.50)
    love.graphics.print("TERMINAL [F3 para ocultar | 'clear' para limpar]", tx + 14, ty + 10)

    -- Output history
    love.graphics.setColor(0.85, 0.90, 0.85)
    for i, linha in ipairs(Terminal.historico) do
        love.graphics.print(linha, tx + 14, ty + 32 + (i - 1) * 16)
    end

    -- Active command prompt with blinking cursor
    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "_" or ""
    love.graphics.setColor(1, 0.90, 0.35)
    love.graphics.print("$ " .. Terminal.input .. cursor, tx + 14, ty + th - 28)
end

return Terminal