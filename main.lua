-- =========================================================================
-- MAIN.LUA — Crash-Proof LÖVE2D IDE Orchestrator
-- =========================================================================
local tab_class         = require("tab")
local syntax            = require("syntax")
local help              = require("help")
local tabbar            = require("tabbar")
local abyss             = require("abyss")
local autocomplete      = require("autocomplete")
local dictionary        = require("dictionary")
local runner            = require("runner")
local search            = require("search")
local utf8              = require("utf8")
local Terminal          = require("terminal")

local tabs              = {}
local activeTabIdx      = 1
local splitScreen       = false
local activePane        = 1
local rightTabIdx       = 2
local codeFont          = nil
local isSelecting       = false
local pendingCloseIdx   = nil
local autosaveTimer     = 0
local AUTOSAVE_INTERVAL = 30
local swallowText       = false

-- -------------------------------------------------------------------------
-- DEFENSIVE UTILITIES (ANTI-NIL & CRASH SHIELDS)
-- -------------------------------------------------------------------------

local function safeSub(str, i, j)
    return string.sub(tostring(str or ""), i or 1, j)
end

local function safeOffset(str, n, i)
    local ok, res = pcall(utf8.offset, tostring(str or ""), n, i)
    return (ok and res) or nil
end

local function safeWidth(font, text)
    if not font then return 0 end
    local ok, w = pcall(font.getWidth, font, tostring(text or ""))
    return (ok and w) or 0
end

local function sanitizeTab(tab)
    if not tab then return end
    if not tab.lines or type(tab.lines) ~= "table" or #tab.lines == 0 then
        tab.lines = { "" }
    end
    tab.cy = math.max(1, math.min(tab.cy or 1, #tab.lines))
    tab.lines[tab.cy] = tab.lines[tab.cy] or ""
    tab.cx = math.max(1, math.min(tab.cx or 1, #tab.lines[tab.cy] + 1))
    tab.scrollY = math.max(0, tab.scrollY or 0)
end

-- Loads DejaVu Sans Mono for Powerline with safe fallback cascade
local function loadCodeFont(size)
    size = size or 16
    local candidatePaths = {
        "DejaVu Sans Mono for Powerline.ttf",
        "fonts/DejaVu Sans Mono for Powerline.ttf",
        "DejaVuSansMono.ttf",
        "fonts/DejaVuSansMono.ttf",
        "dejavu.ttf"
    }

    for _, path in ipairs(candidatePaths) do
        local exists = false
        if love.filesystem.getInfo then
            exists = love.filesystem.getInfo(path) ~= nil
        elseif love.filesystem.exists then
            exists = love.filesystem.exists(path)
        end

        if exists then
            local ok, font = pcall(love.graphics.newFont, path, size)
            if ok and font then return font end
        end
    end

    return love.graphics.newFont(size)
end

-- -------------------------------------------------------------------------
-- TAB MANAGEMENT & BUFFER HELPERS
-- -------------------------------------------------------------------------

local function getActiveTab()
    if #tabs == 0 then
        table.insert(tabs, tab_class:new("untitled.lua", { "" }))
        activeTabIdx = 1
        rightTabIdx = 1
    end

    activeTabIdx = math.max(1, math.min(activeTabIdx or 1, #tabs))
    rightTabIdx  = math.max(1, math.min(rightTabIdx or 1, #tabs))

    local tab    = (splitScreen and activePane == 2) and tabs[rightTabIdx] or tabs[activeTabIdx]
    tab          = tab or tabs[1]
    sanitizeTab(tab)
    return tab
end

local function autosaveAll()
    local saved = 0
    for _, tab in ipairs(tabs) do
        if tab and tab.isModified and tab:isModified() then
            local ok = tab:save()
            if ok then saved = saved + 1 end
        end
    end
    if saved > 0 and abyss and abyss.set then
        abyss.set("Auto-saved " .. saved .. " file(s)")
    end
end

local function snapUtf8(line, pos)
    line = tostring(line or "")
    pos = pos or 1
    if pos > #line then return #line + 1 end
    if pos < 1 then return 1 end

    while pos > 1 do
        local b = string.byte(line, pos)
        if b and b >= 128 and b < 192 then
            pos = pos - 1
        else
            break
        end
    end
    return pos
end

local function ensureCursorVisible(tab)
    if not tab then return end
    sanitizeTab(tab)

    local lineH = (codeFont and codeFont:getHeight() or 16) + 4
    local topY = 45
    local bottomBarH = 34
    local winH = love.graphics.getHeight()
    local visibleLines = math.max(1, math.floor((winH - topY - bottomBarH) / lineH))

    if (tab.cy - 1) < tab.scrollY then
        tab.scrollY = tab.cy - 1
    elseif tab.cy > tab.scrollY + visibleLines then
        tab.scrollY = tab.cy - visibleLines
    end

    tab.scrollY = math.max(0, tab.scrollY or 0)
end

local function splitLines(content)
    local lines = {}
    content = tostring(content or ""):gsub("\r\n", "\n")
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    if #lines == 0 then lines = { "" } end
    return lines
end

local function openFile(filepath)
    if not filepath or filepath == "" then return end

    for i, tab in ipairs(tabs) do
        if tab.filepath == filepath then
            if splitScreen and activePane == 2 then
                rightTabIdx = i
            else
                activeTabIdx = i
            end
            if abyss and abyss.set then abyss.set("Already open: " .. tab.name) end
            return
        end
    end

    local file, err = io.open(filepath, "r")
    if not file then
        if abyss and abyss.set then abyss.set("Failed to open: " .. tostring(err), true) end
        return
    end

    local content = file:read("*a")
    file:close()
    if not utf8.len(content) then
        if abyss and abyss.set then abyss.set("Not a UTF-8 file: " .. filepath, true) end
        return
    end

    local name = filepath:match("([^/\\]+)$") or filepath
    local newTab = tab_class:new(name, splitLines(content), filepath)

    table.insert(tabs, newTab)
    if splitScreen and activePane == 2 then
        rightTabIdx = #tabs
    else
        activeTabIdx = #tabs
    end

    if autocomplete and autocomplete.close then autocomplete.close() end
    if abyss and abyss.set then abyss.set("Opened: " .. name) end
end

function love.filedropped(file)
    if file and file.getFilename then
        openFile(file:getFilename())
    end
end

local function closeTab(idxToClose, force)
    if #tabs <= 1 then
        if abyss and abyss.set then abyss.set("Cannot close the last tab!", true) end
        return
    end

    local targetTab = tabs[idxToClose]
    if not targetTab then return end

    if not force and targetTab.isModified and targetTab:isModified() then
        pendingCloseIdx = idxToClose
        if abyss and abyss.set then
            abyss.set("Save changes to " .. targetTab.name .. "? (Y)es / (N)o / (Esc) Cancel", true)
        end
        return
    end

    local closedName = targetTab.name or "tab"
    table.remove(tabs, idxToClose)
    if idxToClose < activeTabIdx then activeTabIdx = activeTabIdx - 1 end
    if idxToClose < rightTabIdx then rightTabIdx = rightTabIdx - 1 end
    activeTabIdx = math.max(1, math.min(activeTabIdx, #tabs))
    rightTabIdx  = math.max(1, math.min(rightTabIdx, #tabs))

    if #tabs < 2 then
        splitScreen = false
        activePane = 1
    end

    if autocomplete and autocomplete.close then autocomplete.close() end
    if abyss and abyss.set then abyss.set("Closed tab: " .. closedName) end
end

local function screenToCursor(mx, my, tab, offsetX)
    if not tab then return 1, 1 end
    sanitizeTab(tab)
    offsetX = offsetX or 0
    local lineH = (codeFont and codeFont:getHeight() or 16) + 4
    local topY = 45

    local row = math.floor((my - topY) / lineH) + 1 + (tab.scrollY or 0)
    row = math.max(1, math.min(#tab.lines, row))

    local line = tab.lines[row] or ""
    local col = #line + 1

    local pos = 1
    while pos <= #line do
        local nextPos = safeOffset(line, 2, pos) or (#line + 1)
        local w = safeWidth(codeFont, safeSub(line, 1, nextPos - 1))
        if offsetX + 60 + w > mx then
            col = pos
            break
        end
        pos = nextPos
    end
    return col, row
end

-- -------------------------------------------------------------------------
-- LÖVE2D APPLICATION LIFECYCLE
-- -------------------------------------------------------------------------

function love.load(args)
    love.window.setTitle("Old Fool's IDE")
    love.keyboard.setKeyRepeat(true)

    codeFont = loadCodeFont(16)
    love.graphics.setFont(codeFont)

    local mainPath = "main.lua"
    local f = io.open(mainPath, "r")
    if f then
        f:close()
        openFile(mainPath)
    else
        tabs = {
            tab_class:new("main.lua", {
                "function love.draw()",
                "    love.graphics.print('Welcome!', 100, 100)",
                "end"
            }),
            tab_class:new("module_2.lua", {
                "-- Second tab",
                "local x = 10",
                "return x"
            })
        }
    end

    if args and #args > 0 then
        for i = 1, #args do openFile(args[i]) end
    end
end

function love.update(dt)
    swallowText = false
    if (help and help.visible) or pendingCloseIdx then return end

    autosaveTimer = autosaveTimer + dt
    if autosaveTimer >= AUTOSAVE_INTERVAL then
        autosaveTimer = 0
        autosaveAll()
    end
end

function love.focus(focused)
    if not focused then autosaveAll() end
end

function love.wheelmoved(x, y)
    if tabbar and tabbar.wheelmoved and tabbar.wheelmoved(x, y, codeFont, tabs) then
        return
    end

    local tab = getActiveTab()
    if tab and tab.scroll then
        tab:scroll(-y * 3)
    end
end

function love.mousepressed(mx, my, button)
    if (help and help.visible) or pendingCloseIdx then return end
    local activeTab = getActiveTab()
    if not activeTab then return end

    if activeTab.renaming and activeTab.cancelRename then
        activeTab:cancelRename()
        if abyss and abyss.set then abyss.set("Rename cancelled") end
    end

    if button == 1 then
        if tabbar and tabbar.getClickedIndex then
            local clicked, clickedClose = tabbar.getClickedIndex(mx, my, codeFont, tabs)
            if clicked then
                if clickedClose then
                    closeTab(clicked)
                    return
                end
                if splitScreen and activePane == 2 then
                    rightTabIdx = clicked
                else
                    activeTabIdx = clicked
                end
                if autocomplete and autocomplete.close then autocomplete.close() end
                if abyss and abyss.set and tabs[clicked] then
                    abyss.set("Switched to: " .. tabs[clicked].name)
                end
                return
            end
        end

        local barH = (tabbar and tabbar.height) or 32
        if my > barH and my < love.graphics.getHeight() - 34 then
            local offsetX = 0
            if splitScreen then
                local halfW = math.floor(love.graphics.getWidth() / 2)
                if mx >= halfW then
                    activePane = 2
                    offsetX = halfW
                else
                    activePane = 1
                end
            end

            local tab = getActiveTab()
            local cx, cy = screenToCursor(mx, my, tab, offsetX)
            tab.cx, tab.cy = cx, cy
            tab.selStart = { x = cx, y = cy }
            tab.selEnd = nil
            isSelecting = true
            if autocomplete and autocomplete.close then autocomplete.close() end
        end
    end
end

function love.mousemoved(mx, my)
    if not isSelecting then return end
    local offsetX = (splitScreen and activePane == 2) and math.floor(love.graphics.getWidth() / 2) or 0
    local tab = getActiveTab()
    local cx, cy = screenToCursor(mx, my, tab, offsetX)
    tab.cx, tab.cy = cx, cy
    tab.selEnd = { x = cx, y = cy }
end

function love.mousereleased(mx, my, button)
    if button == 1 then isSelecting = false end
end

function love.textinput(t)
    if swallowText then
        swallowText = false
        return
    end

    if Terminal and Terminal.textinput and Terminal.textinput(t) then
        return
    end

    local tab = getActiveTab()
    if not tab then return end
    sanitizeTab(tab)

    if tab.renaming then
        if tab.renameInput then tab:renameInput(t) end
        if abyss and abyss.set then abyss.set("Rename tab: " .. tostring(tab.renameBuffer or "") .. "|") end
        return
    end

    if search and (search.visible or search.ativo) then
        if search.textinput then search.textinput(t, tab) end
        return
    end

    if tab.insertText then tab:insertText(t) end
    if autocomplete and autocomplete.update then autocomplete.update(tab, dictionary) end
end

function love.keypressed(key)
    if Terminal and Terminal.keypressed and Terminal.keypressed(key) then return end


    -- Modal confirmation prompt for closing modified tabs
    if pendingCloseIdx then
        local idx = pendingCloseIdx
        local targetTab = tabs[idx]

        if key == "y" then
            swallowText = true
            pendingCloseIdx = nil
            if targetTab and targetTab.save then
                local ok, path = targetTab:save()
                if ok then
                    closeTab(idx, true)
                elseif abyss and abyss.set then
                    abyss.set("Failed to save: " .. tostring(path), true)
                end
            end
        elseif key == "n" then
            swallowText = true
            pendingCloseIdx = nil
            closeTab(idx, true)
        elseif key == "escape" then
            pendingCloseIdx = nil
            if abyss and abyss.set then abyss.set("Close cancelled") end
        end
        return
    end

    local tab = getActiveTab()
    if not tab then return end
    sanitizeTab(tab)

    -- Tab renaming mode input handling
    if tab.renaming then
        if key == "return" or key == "kpenter" then
            if tab.confirmRename and tab:confirmRename() then
                if abyss and abyss.set then abyss.set("Renamed tab to: " .. tab.name) end
            else
                if abyss and abyss.set then abyss.set("Rename cancelled or invalid") end
            end
        elseif key == "escape" then
            if tab.cancelRename then tab:cancelRename() end
            if abyss and abyss.set then abyss.set("Rename cancelled") end
        elseif key == "backspace" then
            if tab.renameBackspace then tab:renameBackspace() end
            if abyss and abyss.set then abyss.set("Rename tab: " .. tostring(tab.renameBuffer or "") .. "|") end
        end
        return
    end

    -- Help overlay input handling
    if help and help.visible then
        if key == "escape" or key == "f1" then
            help.toggle()
        end
        return
    end

    -- Search bar input handling
    if search and (search.visible or search.ativo) then
        local shift = love.keyboard.isDown("lshift", "rshift")
        if key == "escape" then
            if search.close then search.close() end
        elseif key == "backspace" then
            if search.backspace then search.backspace(tab) end
        elseif key == "return" or key == "kpenter" then
            if shift then
                if search.prev then search.prev(tab) end
            else
                if search.next then search.next(tab) end
            end
        end
        return
    end

    -- Function keys (F1 - F5)
    if key == "f1" then
        if help and help.toggle then help.toggle() end
        return
    elseif key == "f2" then
        if #tabs < 2 then
            if abyss and abyss.set then abyss.set("Open at least 2 tabs (Ctrl+T) for split-screen", true) end
            return
        end
        splitScreen = not splitScreen
        if splitScreen then
            rightTabIdx = (activeTabIdx % #tabs) + 1
            activePane = 1
            if abyss and abyss.set then abyss.set("Split-screen ON") end
        else
            activePane = 1
            if abyss and abyss.set then abyss.set("Split-screen OFF") end
        end
        if autocomplete and autocomplete.close then autocomplete.close() end
        return
    elseif key == "f3" then
        if Terminal and Terminal.toggle then Terminal.toggle() end
        return
    elseif key == "f5" then
        if runner and runner.run then
            local ok, msg = runner.run(tabs, ".")
            if abyss and abyss.set then abyss.set(msg, not ok) end
        end
        return
    end
    -- For Luau
    if key == "f4" then
        local tab = getActiveTab()
        if tab and tab.toggleMode then
            local novoModo = tab:toggleMode()
            if abyss and abyss.set then
                abyss.set("Modo de Linguagem alterado para: " .. novoModo:upper())
            end
        end
        return
    end

    -- Autocomplete navigation
    if autocomplete and autocomplete.isOpen and autocomplete.isOpen() then
        if key == "down" then
            autocomplete.move(1)
            return
        elseif key == "up" then
            autocomplete.move(-1)
            return
        elseif key == "tab" or key == "return" or key == "kpenter" then
            autocomplete.accept(tab)
            return
        elseif key == "escape" then
            autocomplete.close()
            return
        end
    end

    local ctrl  = love.keyboard.isDown("lctrl", "rctrl")
    local shift = love.keyboard.isDown("lshift", "rshift")

    if key == "escape" then
        love.event.quit()
        return
    end

    -- Tab key: Indentation, dedentation, and macro expansion
    if key == "tab" then
        local hasSel = tab.hasSelection and tab:hasSelection()
        if not shift and not hasSel then
            local line   = tab.lines[tab.cy] or ""
            local before = safeSub(line, 1, (tab.cx or 1) - 1)
            local word   = string.match(before, "([%w_]+)$")
            local macro  = word and dictionary and dictionary.macros and dictionary.macros[word]

            if macro then
                local indent = string.match(line, "^%s*") or ""
                tab.lines[tab.cy] = safeSub(before, 1, #before - #word) .. safeSub(line, tab.cx)
                tab.cx = math.max(1, tab.cx - #word)

                local body = {}
                for i, l in ipairs(macro) do
                    body[i] = (i == 1) and l or (indent .. l)
                end
                local startY = tab.cy
                if tab.paste then tab:paste(table.concat(body, "\n")) end

                sanitizeTab(tab)
                tab.cy = math.min(#tab.lines, startY + 1)
                tab.cx = #(tab.lines[tab.cy] or "") + 1
                if autocomplete and autocomplete.close then autocomplete.close() end
                return
            end
        end

        if shift then
            if tab.unindent then tab:unindent() end
        else
            if tab.indent then tab:indent() end
        end
        if autocomplete and autocomplete.close then autocomplete.close() end
        return
    end

    -- Control shortcuts
    if ctrl then
        if key == "s" then
            local ok, path = tab:save()
            if ok then
                if abyss and abyss.set then abyss.set("Saved: " .. tab.name) end
            else
                if abyss and abyss.set then abyss.set("Failed to save: " .. tostring(path), true) end
            end
        elseif key == "o" then
            local handle = io.popen('zenity --file-selection --title="Open file" 2>/dev/null')
            if handle then
                local filepath = handle:read("*l")
                handle:close()
                openFile(filepath)
            end
        elseif key == "r" then
            if tab.startRename then tab:startRename() end
            if autocomplete and autocomplete.close then autocomplete.close() end
            if abyss and abyss.set then abyss.set("Rename tab: " .. tostring(tab.renameBuffer or "") .. "|") end
        elseif key == "z" then
            if tab.undo then tab:undo() end
            if abyss and abyss.set then abyss.set("Undo") end
        elseif key == "y" then
            if tab.redo then tab:redo() end
            if abyss and abyss.set then abyss.set("Redo") end
        elseif key == "t" then
            local n = #tabs + 1
            local function taken(name)
                for _, t in ipairs(tabs) do if t.name == name then return true end end
                return false
            end
            while taken("module_" .. n .. ".lua") do n = n + 1 end
            local newName = "module_" .. n .. ".lua"
            table.insert(tabs, tab_class:new(newName))
            activeTabIdx = #tabs
            if abyss and abyss.set then abyss.set("Created tab: " .. newName) end
        elseif key == "w" then
            local idxToClose = (splitScreen and activePane == 2) and rightTabIdx or activeTabIdx
            closeTab(idxToClose)
        elseif key == "f" then
            if search and search.open then search.open(tab) end
            if autocomplete and autocomplete.close then autocomplete.close() end
        elseif key == "c" then
            if tab.getSelectedText then
                local text = tab:getSelectedText()
                if text then
                    love.system.setClipboardText(text)
                    if abyss and abyss.set then abyss.set("Copied to clipboard") end
                end
            end
        elseif key == "x" then
            if tab.cut then
                local text = tab:cut()
                if text then
                    love.system.setClipboardText(text)
                    if abyss and abyss.set then abyss.set("Cut to clipboard") end
                end
            end
        elseif key == "v" then
            local text = love.system.getClipboardText()
            if text and #text > 0 and tab.paste then
                tab:paste(text)
                if autocomplete and autocomplete.close then autocomplete.close() end
                if abyss and abyss.set then abyss.set("Pasted from clipboard") end
            end
        elseif key == "d" then
            if tab.duplicateLine then tab:duplicateLine() end
            if autocomplete and autocomplete.close then autocomplete.close() end
            if abyss and abyss.set then abyss.set("Duplicated line " .. tab.cy) end
        elseif key == "a" then
            if tab.selectAll then tab:selectAll() end
            if autocomplete and autocomplete.close then autocomplete.close() end
            if abyss and abyss.set then abyss.set("Selected all") end
        elseif key == "right" then
            activeTabIdx = (activeTabIdx % #tabs) + 1
            if autocomplete and autocomplete.close then autocomplete.close() end
        elseif key == "left" then
            activeTabIdx = ((activeTabIdx - 2) % #tabs) + 1
            if autocomplete and autocomplete.close then autocomplete.close() end
        end
        return
    end

    -- Text editing keys
    if key == "backspace" then
        if tab.backspace then tab:backspace() end
        sanitizeTab(tab)
        if autocomplete and autocomplete.update then autocomplete.update(tab, dictionary) end
    elseif key == "delete" then
        if tab.delete then tab:delete() end
        sanitizeTab(tab)
        if autocomplete and autocomplete.update then autocomplete.update(tab, dictionary) end
    elseif key == "return" or key == "kpenter" then
        if tab.newLine then tab:newLine() end
        sanitizeTab(tab)
        if autocomplete and autocomplete.close then autocomplete.close() end
    elseif key == "left" or key == "right" or key == "up" or key == "down" or key == "home" or key == "end" then
        if shift then
            if not tab.selStart then tab.selStart = { x = tab.cx, y = tab.cy } end
        else
            if tab.clearSelection then tab:clearSelection() end
        end

        local line = tab.lines[tab.cy] or ""

        if key == "left" then
            if tab.cx > 1 then
                tab.cx = safeOffset(line, -1, tab.cx) or 1
            elseif tab.cy > 1 then
                tab.cy = tab.cy - 1
                sanitizeTab(tab)
                tab.cx = #(tab.lines[tab.cy] or "") + 1
            end
        elseif key == "right" then
            if tab.cx <= #line then
                tab.cx = safeOffset(line, 2, tab.cx) or (#line + 1)
            elseif tab.cy < #tab.lines then
                tab.cy = tab.cy + 1
                sanitizeTab(tab)
                tab.cx = 1
            end
        elseif key == "up" then
            if tab.cy > 1 then
                tab.cy = tab.cy - 1
                sanitizeTab(tab)
                tab.cx = snapUtf8(tab.lines[tab.cy], math.min(tab.cx, #(tab.lines[tab.cy] or "") + 1))
            end
        elseif key == "down" then
            if tab.cy < #tab.lines then
                tab.cy = tab.cy + 1
                sanitizeTab(tab)
                tab.cx = snapUtf8(tab.lines[tab.cy], math.min(tab.cx, #(tab.lines[tab.cy] or "") + 1))
            end
        elseif key == "home" then
            tab.cx = 1
        elseif key == "end" then
            tab.cx = #line + 1
        end

        if shift then tab.selEnd = { x = tab.cx, y = tab.cy } end
        ensureCursorVisible(tab)
    end
end

-- -------------------------------------------------------------------------
-- DEFENSIVE PANE RENDERING
-- -------------------------------------------------------------------------

local function drawPane(tab, offsetX, paneW, isFocused)
    if not tab then return end
    sanitizeTab(tab)

    local h = love.graphics.getHeight()
    local lineH = (codeFont and codeFont:getHeight() or 16) + 4
    local topY = 45
    local barH = (tabbar and tabbar.height) or 32

    local selStart, selEnd = nil, nil
    if tab.getSelectionRange then
        local ok, s1, s2 = pcall(tab.getSelectionRange, tab)
        if ok then selStart, selEnd = s1, s2 end
    end

    love.graphics.setScissor(offsetX, barH, paneW, h - barH - 34)

    for i, line in ipairs(tab.lines) do
        line = tostring(line or "")
        local y = topY + (i - 1 - (tab.scrollY or 0)) * lineH

        if y + lineH >= barH and y <= h - 34 then
            if tab.errorLine == i then
                love.graphics.setColor(0.55, 0.12, 0.12, 0.35)
                love.graphics.rectangle("fill", offsetX, y, paneW, lineH)
            end

            -- Selection highlight
            if selStart and selEnd and i >= (selStart.y or 1) and i <= (selEnd.y or 1) then
                local c1 = (i == selStart.y) and (selStart.x or 1) or 1
                local c2 = (i == selEnd.y) and (selEnd.x or (#line + 1)) or (#line + 1)
                local x1 = offsetX + 60 + safeWidth(codeFont, safeSub(line, 1, c1 - 1))
                local x2 = offsetX + 60 + safeWidth(codeFont, safeSub(line, 1, c2 - 1))

                love.graphics.setColor(0.20, 0.45, 0.70, 0.55)
                love.graphics.rectangle("fill", x1, y, math.max(8, x2 - x1), lineH)
            end

            -- Line number
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.print(tostring(i), offsetX + 10, y)

            -- Syntax-highlighted text
            love.graphics.setColor(1, 1, 1)
            local hl = line
            if syntax and syntax.highlightSyntax then
                local ok, res = pcall(syntax.highlightSyntax, line)
                if ok and res then hl = res end
            end
            love.graphics.print(hl, offsetX + 60, y)
        end
    end

    -- Defensive cursor rendering
    if isFocused and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local line = tab.lines[tab.cy] or ""
        local cx = tab.cx or 1
        local before = safeSub(line, 1, math.max(0, cx - 1))
        local cy = tab.cy or 1
        local scrollY = tab.scrollY or 0
        local cursorY = topY + (cy - 1 - scrollY) * lineH

        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.rectangle("fill", offsetX + 60 + safeWidth(codeFont, before), cursorY, 2, lineH - 2)
    end

    love.graphics.setScissor()
end

function love.draw()
    local ok, err = pcall(function()
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        local activeTab = getActiveTab()
        local barH = (tabbar and tabbar.height) or 32

        love.graphics.clear(0.08, 0.09, 0.11)

        if splitScreen then
            local halfW = math.floor(w / 2)
            drawPane(tabs[activeTabIdx], 0, halfW, activePane == 1)
            drawPane(tabs[rightTabIdx], halfW, w - halfW, activePane == 2)

            love.graphics.setColor(0.20, 0.80, 0.40, 0.6)
            love.graphics.rectangle("fill", halfW - 1, barH, 2, h - barH - 34)
        else
            drawPane(tabs[activeTabIdx], 0, w, true)
        end

        local currentIdx = (splitScreen and activePane == 2) and rightTabIdx or activeTabIdx
        local acX = (splitScreen and activePane == 2) and math.floor(w / 2) or 0

        if search and search.draw then search.draw(codeFont) end
        if autocomplete and autocomplete.draw then autocomplete.draw(codeFont, activeTab, acX) end
        if tabbar and tabbar.draw then tabbar.draw(codeFont, tabs, currentIdx) end
        if abyss and abyss.draw then abyss.draw(codeFont, activeTab) end
        if help and help.draw then help.draw(codeFont) end
        if Terminal and Terminal.draw then Terminal.draw() end
    end)

    if not ok then
        love.graphics.setScissor()
        love.graphics.setColor(0.85, 0.15, 0.15, 0.95)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 28, love.graphics.getWidth(), 28)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("[RENDER ERROR]: " .. tostring(err), 12, love.graphics.getHeight() - 22)
    end
end

-- -------------------------------------------------------------------------
-- GLOBAL ERROR HANDLER (CRASH SHIELD / BLUE SCREEN REPLACEMENT)
-- -------------------------------------------------------------------------

function love.errorhandler(msg)
    local errString = tostring(msg or "Unknown error")
    local traceback = debug.traceback("Captured Error: " .. errString, 2)

    if love.system and love.system.setClipboardText then
        pcall(love.system.setClipboardText, traceback)
    end

    return function()
        love.event.pump()
        for e, a in love.event.poll() do
            if e == "quit" or (e == "keypressed" and a == "escape") then
                return 1
            elseif e == "keypressed" and a == "r" then
                if love.load then pcall(love.load) end
                return
            end
        end

        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()

        love.graphics.setScissor()
        love.graphics.clear(0.10, 0.11, 0.14)

        love.graphics.setColor(0.9, 0.25, 0.25)
        love.graphics.printf("CRITICAL ERROR RECOVERY", 30, 30, w - 60, "left")

        love.graphics.setColor(0.85, 0.85, 0.85)
        love.graphics.printf(traceback, 30, 65, w - 60, "left")

        love.graphics.setColor(0.35, 0.85, 0.45)
        love.graphics.printf("[R] Reload IDE     [ESC] Quit (Traceback copied to clipboard)", 30, h - 45, w - 60,
            "center")

        love.graphics.present()
    end
end
