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

local projectDir        = "project"
local tabs              = {}
local activeTabIdx      = 1
local splitScreen       = false
local activePane        = 1
local rightTabIdx       = 2
local codeFont
local isSelecting       = false
local pendingCloseIdx   = nil
local autosaveTimer     = 0
local AUTOSAVE_INTERVAL = 30 -- Auto-save interval in seconds

-- Returns the currently focused tab (respecting split-screen mode)
local function getActiveTab()
    if splitScreen and activePane == 2 then
        return tabs[rightTabIdx]
    end
    return tabs[activeTabIdx]
end

-- Saves all modified tabs to disk and updates the status bar
local function autosaveAll()
    local saved = 0
    for _, tab in ipairs(tabs) do
        if tab:isModified() then
            local ok = tab:save(projectDir)
            if ok then
                saved = saved + 1
            end
        end
    end
    if saved > 0 then
        abyss.set("Auto-saved " .. saved .. " file(s)")
    end
end

-- Clamps a byte index to a valid UTF-8 character boundary within a line
local function snapUtf8(line, pos)
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

-- Adjusts vertical scroll so the cursor line remains visible in the viewport
local function ensureCursorVisible(tab)
    local lineH = codeFont:getHeight() + 4
    local topY = 45
    local bottomBarH = 34
    local visibleLines = math.max(1, math.floor((love.graphics.getHeight() - topY - bottomBarH) / lineH))

    if tab.cy - 1 < tab.scrollY then
        tab.scrollY = tab.cy - 1
    elseif tab.cy > tab.scrollY + visibleLines then
        tab.scrollY = tab.cy - visibleLines
    end

    tab.scrollY = math.max(0, tab.scrollY)
end

-- Splits a raw file string into an array of lines (normalizing CRLF to LF)
local function splitLines(content)
    local lines = {}
    content = content:gsub("\r\n", "\n")
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    if #lines == 0 then
        lines = { "" }
    end
    return lines
end

-- Opens a file from disk into a new tab (or switches to it if already open)
local function openFile(filepath)
    if not filepath or filepath == "" then return end

    for i, tab in ipairs(tabs) do
        if tab.filepath == filepath then
            if splitScreen and activePane == 2 then
                rightTabIdx = i
            else
                activeTabIdx = i
            end
            abyss.set("Already open: " .. tab.name)
            return
        end
    end

    local file, err = io.open(filepath, "r")
    if not file then
        abyss.set("Failed to open: " .. tostring(err), true)
        return
    end

    local content = file:read("*a")
    file:close()

    local name = filepath:match("([^/\\]+)$") or filepath
    local newTab = tab_class:new(name, splitLines(content), filepath)

    table.insert(tabs, newTab)
    if splitScreen and activePane == 2 then
        rightTabIdx = #tabs
    else
        activeTabIdx = #tabs
    end

    autocomplete.close()
    abyss.set("Opened: " .. name)
end

-- Handles files dragged and dropped onto the IDE window
function love.filedropped(file)
    openFile(file:getFilename())
end

-- Closes a tab by index, prompting to save if it has unsaved changes
local function closeTab(idxToClose, force)
    if #tabs <= 1 then
        abyss.set("Cannot close the last tab!", true)
        return
    end

    local targetTab = tabs[idxToClose]
    if not force and targetTab:isModified() then
        pendingCloseIdx = idxToClose
        abyss.set("Save changes to " .. targetTab.name .. "? (Y)es / (N)o / (Esc) Cancel", true)
        return
    end

    local closedName = targetTab.name
    table.remove(tabs, idxToClose)

    activeTabIdx = math.min(activeTabIdx, #tabs)
    rightTabIdx  = math.min(rightTabIdx, #tabs)

    if #tabs < 2 then
        splitScreen = false
        activePane = 1
    end

    autocomplete.close()
    abyss.set("Closed tab: " .. closedName)
end

-- Converts screen pixel coordinates (mx, my) into buffer (col, row) cursor coordinates
local function screenToCursor(mx, my, tab, offsetX)
    offsetX = offsetX or 0
    local lineH = codeFont:getHeight() + 4
    local topY = 45

    local row = math.floor((my - topY) / lineH) + 1 + tab.scrollY
    row = math.max(1, math.min(#tab.lines, row))

    local line = tab.lines[row]
    local col = #line + 1

    local pos = 1
    while pos <= #line do
        local nextPos = utf8.offset(line, 2, pos) or (#line + 1)
        local ok, w = pcall(codeFont.getWidth, codeFont, string.sub(line, 1, nextPos - 1))
        if ok and offsetX + 60 + w > mx then
            col = pos
            break
        end
        pos = nextPos
    end
    return col, row
end

-- Initializes the IDE window, font, default tabs, and command-line file arguments
function love.load(args)
    os.execute("mkdir -p " .. projectDir)
    love.window.setMode(1280, 720, { resizable = true })
    love.window.setTitle("Old Fool's IDE")

    love.keyboard.setKeyRepeat(true)
    codeFont = love.graphics.newFont(18)
    love.graphics.setFont(codeFont)

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

    if args and #args > 0 then
        for i = 1, #args do
            openFile(args[i])
        end
    end
end

-- Updates the periodic auto-save timer
function love.update(dt)
    autosaveTimer = autosaveTimer + dt
    if autosaveTimer >= AUTOSAVE_INTERVAL then
        autosaveTimer = 0
        autosaveAll()
    end
end

-- Triggers an automatic save whenever the IDE window loses focus
function love.focus(focused)
    if not focused then
        autosaveAll()
    end
end

-- Handles vertical mouse wheel scrolling in the active tab
function love.wheelmoved(x, y)
    if help.visible or pendingCloseIdx then return end
    getActiveTab():scroll(-y * 3)
end

if tabbar.wheelmoved(dx, dy, font, tabs) then return end

-- Handles mouse clicks on the tab bar and editor panes (focus, cursor, selection start)
function love.mousepressed(mx, my, button)
    if help.visible or pendingCloseIdx then return end
    local activeTab = getActiveTab()
    if activeTab.renaming then
        activeTab:cancelRename()
        abyss.set("Rename cancelled")
    end

    if button == 1 then
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
            autocomplete.close()
            abyss.set("Switched to: " .. tabs[clicked].name)
            return
        end

        if my > tabbar.height and my < love.graphics.getHeight() - 34 then
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
            autocomplete.close()
        end
    end
end

-- Updates text selection while dragging the mouse
function love.mousemoved(mx, my)
    if not isSelecting then return end
    local offsetX = (splitScreen and activePane == 2) and math.floor(love.graphics.getWidth() / 2) or 0
    local tab = getActiveTab()
    local cx, cy = screenToCursor(mx, my, tab, offsetX)
    tab.cx, tab.cy = cx, cy
    tab.selEnd = { x = cx, y = cy }
end

-- Ends mouse drag selection when the left button is released
function love.mousereleased(mx, my, button)
    if button == 1 then
        isSelecting = false
    end
end

-- Routes typed text to the terminal, rename bar, search box, or active editor tab
function love.textinput(t)
    if Terminal.textinput(t) then return end
    if help.visible or pendingCloseIdx then return end
    local tab = getActiveTab()

    if tab.renaming then
        tab:renameInput(t)
        abyss.set("Rename tab: " .. tab.renameBuffer .. "|")
        return
    end
    if search.visible then
        search.textinput(t, tab)
        return
    end

    tab:insertText(t)
    autocomplete.update(tab, dictionary)
end

-- Handles keyboard shortcuts, navigation, indentation, and overlay controls
function love.keypressed(key)
    if Terminal.keypressed(key) then return end

    if pendingCloseIdx then
        local idx = pendingCloseIdx
        if key == "y" then
            local ok, path = tabs[idx]:save(projectDir)
            pendingCloseIdx = nil
            if ok then
                closeTab(idx, true)
            else
                abyss.set("Failed to save: " .. path, true)
            end
        elseif key == "n" then
            pendingCloseIdx = nil
            closeTab(idx, true)
        elseif key == "escape" then
            pendingCloseIdx = nil
            abyss.set("Close cancelled")
        end
        return
    end

    local tab = getActiveTab()

    if tab.renaming then
        if key == "return" or key == "kpenter" then
            if tab:confirmRename(projectDir) then
                abyss.set("Renamed to: " .. tab.name)
            else
                abyss.set("Rename cancelled")
            end
        elseif key == "escape" then
            tab:cancelRename()
            abyss.set("Rename cancelled")
        elseif key == "backspace" then
            tab:renameBackspace()
            abyss.set("Rename tab: " .. tab.renameBuffer .. "|")
        end
        return
    end

    if key == "f1" then
        help.toggle()
        return
    end

    if key == "f5" then
        local ok, msg = runner.run(tabs, projectDir)
        abyss.set(msg, not ok)
        return
    end

    if key == "f2" then
        if #tabs < 2 then
            abyss.set("Open at least 2 tabs (Ctrl+T) for split-screen", true)
            return
        end
        splitScreen = not splitScreen
        if splitScreen then
            rightTabIdx = (activeTabIdx % #tabs) + 1
            activePane = 1
            abyss.set("Split-screen ON (click a pane to focus)")
        else
            activePane = 1
            abyss.set("Split-screen OFF")
        end
        autocomplete.close()
        return
    end

    if help.visible then
        if key == "escape" then
            help.toggle()
        end
        return
    end

    if search.visible then
        local shift = love.keyboard.isDown("lshift", "rshift")
        if key == "escape" then
            search.close()
        elseif key == "backspace" then
            search.backspace(tab)
        elseif key == "return" or key == "kpenter" then
            if shift then
                search.prev(tab)
            else
                search.next(tab)
            end
        end
        return
    end

    if autocomplete.isOpen() then
        if key == "down" then
            autocomplete.move(1)
            return
        elseif key == "up" then
            autocomplete.move(-1)
            return
        elseif key == "tab" then
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

    if key == "tab" then
        if shift then
            tab:unindent()
        else
            tab:indent()
        end
        autocomplete.close()
        return
    end

    if ctrl then
        if key == "o" then
            local handle = io.popen('zenity --file-selection --title="Open file" 2>/dev/null')
            if handle then
                local filepath = handle:read("*l")
                handle:close()
                openFile(filepath)
            end
        elseif key == "r" then
            tab:startRename()
            autocomplete.close()
            abyss.set("Rename tab: " .. tab.renameBuffer .. "|")
        elseif key == "z" then
            tab:undo()
            abyss.set("Undo")
        elseif key == "y" then
            tab:redo()
            abyss.set("Redo")
        elseif key == "s" then
            local ok, path = tab:save(projectDir)
            abyss.set(ok and ("Saved: " .. path) or ("Failed to save: " .. path), not ok)
        elseif key == "t" then
            local newName = "module_" .. (#tabs + 1) .. ".lua"
            table.insert(tabs, tab_class:new(newName))
            activeTabIdx = #tabs
            abyss.set("Created tab: " .. newName)
        elseif key == "w" then
            local idxToClose = (splitScreen and activePane == 2) and rightTabIdx or activeTabIdx
            closeTab(idxToClose)
        elseif key == "f" then
            search.open(tab)
            autocomplete.close()
        elseif key == "c" then
            local text = tab:getSelectedText()
            if text then
                love.system.setClipboardText(text)
                abyss.set("Copied to clipboard")
            end
        elseif key == "x" then
            local text = tab:cut()
            if text then
                love.system.setClipboardText(text)
                abyss.set("Cut to clipboard")
            end
        elseif key == "v" then
            local text = love.system.getClipboardText()
            if text and #text > 0 then
                tab:paste(text)
                autocomplete.close()
                abyss.set("Pasted from clipboard")
            end
        elseif key == "d" then
            tab:duplicateLine()
            autocomplete.close()
            abyss.set("Duplicated line " .. tab.cy)
        elseif key == "a" then
            tab:selectAll()
            autocomplete.close()
            abyss.set("Selected all")
        elseif key == "right" then
            activeTabIdx = (activeTabIdx % #tabs) + 1
            autocomplete.close()
        elseif key == "left" then
            activeTabIdx = ((activeTabIdx - 2) % #tabs) + 1
            autocomplete.close()
        end
        return
    end

    if key == "backspace" then
        tab:backspace()
        autocomplete.update(tab, dictionary)
    elseif key == "delete" then
        tab:delete()
        autocomplete.update(tab, dictionary)
    elseif key == "return" or key == "kpenter" then
        tab:newLine()
        autocomplete.close()
    elseif key == "left" or key == "right" or key == "up" or key == "down" or key == "home" or key == "end" then
        if shift then
            if not tab.selStart then
                tab.selStart = { x = tab.cx, y = tab.cy }
            end
        else
            tab:clearSelection()
        end

        local line = tab.lines[tab.cy]

        if key == "left" then
            if tab.cx > 1 then
                tab.cx = utf8.offset(line, -1, tab.cx) or 1
            elseif tab.cy > 1 then
                tab.cy = tab.cy - 1
                tab.cx = #tab.lines[tab.cy] + 1
            end
        elseif key == "right" then
            if tab.cx <= #line then
                tab.cx = utf8.offset(line, 2, tab.cx) or (#line + 1)
            elseif tab.cy < #tab.lines then
                tab.cy = tab.cy + 1
                tab.cx = 1
            end
        elseif key == "up" then
            if tab.cy > 1 then
                tab.cy = tab.cy - 1
                tab.cx = snapUtf8(tab.lines[tab.cy], math.min(tab.cx, #tab.lines[tab.cy] + 1))
            end
        elseif key == "down" then
            if tab.cy < #tab.lines then
                tab.cy = tab.cy + 1
                tab.cx = snapUtf8(tab.lines[tab.cy], math.min(tab.cx, #tab.lines[tab.cy] + 1))
            end
        elseif key == "home" then
            tab.cx = 1
        elseif key == "end" then
            tab.cx = #line + 1
        end

        if shift then
            tab.selEnd = { x = tab.cx, y = tab.cy }
        end

        ensureCursorVisible(tab)
    end
end

-- Renders a single editor pane (selection, line numbers, highlighted code, and blinking cursor)
local function drawPane(tab, offsetX, paneW, isFocused)
    local h = love.graphics.getHeight()
    local lineH = codeFont:getHeight() + 4
    local topY = 45
    local selStart, selEnd = tab:getSelectionRange()

    love.graphics.setScissor(offsetX, tabbar.height, paneW, h - tabbar.height - 34)

    for i, line in ipairs(tab.lines) do
        local y = topY + (i - 1 - tab.scrollY) * lineH

        if y + lineH >= tabbar.height and y <= h - 34 then
            if selStart and i >= selStart.y and i <= selEnd.y then
                local c1 = (i == selStart.y) and selStart.x or 1
                local c2 = (i == selEnd.y) and selEnd.x or (#line + 1)
                local x1 = offsetX + 60 + codeFont:getWidth(string.sub(line, 1, c1 - 1))
                local x2 = offsetX + 60 + codeFont:getWidth(string.sub(line, 1, c2 - 1))

                love.graphics.setColor(0.20, 0.45, 0.70, 0.55)
                love.graphics.rectangle("fill", x1, y, math.max(8, x2 - x1), lineH)
            end

            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.print(tostring(i), offsetX + 10, y)

            love.graphics.setColor(1, 1, 1)
            love.graphics.print(syntax.highlightSyntax(line), offsetX + 60, y)
        end
    end

    if isFocused and math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local before = string.sub(tab.lines[tab.cy], 1, tab.cx - 1)
        local cursorY = topY + (tab.cy - 1 - tab.scrollY) * lineH
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.rectangle("fill", offsetX + 60 + codeFont:getWidth(before), cursorY, 2, lineH - 2)
    end

    love.graphics.setScissor()
end

-- Main LÖVE draw callback: renders editor panes and all UI overlays
function love.draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local activeTab = getActiveTab()
    love.graphics.clear(0.08, 0.09, 0.11)

    if splitScreen then
        local halfW = math.floor(w / 2)
        drawPane(tabs[activeTabIdx], 0, halfW, activePane == 1)
        drawPane(tabs[rightTabIdx], halfW, w - halfW, activePane == 2)

        love.graphics.setColor(0.20, 0.80, 0.40, 0.6)
        love.graphics.rectangle("fill", halfW - 1, tabbar.height, 2, h - tabbar.height - 34)
    else
        drawPane(tabs[activeTabIdx], 0, w, true)
    end

    local currentIdx = (splitScreen and activePane == 2) and rightTabIdx or activeTabIdx
    search.draw(codeFont)
    autocomplete.draw(codeFont, activeTab)
    tabbar.draw(codeFont, tabs, currentIdx)
    abyss.draw(codeFont, activeTab)
    help.draw(codeFont)
    Terminal.draw()
end

