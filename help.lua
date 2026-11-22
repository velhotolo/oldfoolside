local help = {
    visible = false
}

-- Shortcut sections displayed in the left column of the help overlay
local leftSections = {
    {
        title = "FILES & TABS",
        items = {
            { "Ctrl + O",          "Open file (or Drag & Drop)" },
            { "Ctrl + S",          "Save current tab" },
            { "Ctrl + T",          "New tab" },
            { "Ctrl + R",          "Rename current tab" },
            { "Ctrl + W",          "Close tab (or click 'x')" },
            { "Ctrl + Left/Right", "Switch tabs" },
            { "F2",                "Toggle split-screen" },
            { "F3",                "Toggle terminal" },
            { "F5",                "Run project" },
        }
    },
    {
        title = "SEARCH & AUTOCOMPLETE",
        items = {
            { "Ctrl + F",      "Find in file" },
            { "Enter",         "Next match" },
            { "Shift + Enter", "Previous match" },
            { "Up / Down",     "Navigate autocomplete" },
            { "Tab",           "Accept autocomplete" },
        }
    }
}

-- Shortcut sections displayed in the right column of the help overlay
local rightSections = {
    {
        title = "EDITING & SELECTION",
        items = {
            { "Tab / Shift+Tab", "Indent / Unindent" },
            { "Ctrl + Z",        "Undo" },
            { "Ctrl + Y",        "Redo" },
            { "Ctrl + C",        "Copy selection" },
            { "Ctrl + X",        "Cut selection" },
            { "Ctrl + V",        "Paste" },
            { "Ctrl + A",        "Select all" },
            { "Ctrl + D",        "Duplicate line" },
            { "Home / End",      "Start / end of line" },
            { "Delete",          "Delete forward" },
            { "Shift + Arrows",  "Select text" },
            { "Mouse Drag",      "Select text" },
        }
    },
    {
        title = "GENERAL",
        items = {
            { "F1",  "Toggle this help" },
            { "Esc", "Close overlay / Quit IDE" },
        }
    }
}

-- Toggles the visibility of the keyboard shortcuts overlay
function help.toggle()
    help.visible = not help.visible
end

-- Calculates the total vertical pixel height required to render a column of sections
local function measureColumn(sections, lineH, sectionGap)
    local h = 0
    for i, sec in ipairs(sections) do
        if i > 1 then
            h = h + sectionGap
        end
        h = h + lineH + 6
        h = h + (#sec.items * lineH)
    end
    return h
end

-- Renders a column of shortcut sections at the specified position
local function drawColumn(sections, x, y, keyColW, lineH, sectionGap)
    local cy = y
    for i, sec in ipairs(sections) do
        if i > 1 then
            cy = cy + sectionGap
        end

        love.graphics.setColor(0.20, 0.80, 0.40)
        love.graphics.print(sec.title, x, cy)
        cy = cy + lineH + 6

        for _, item in ipairs(sec.items) do
            love.graphics.setColor(0.95, 0.95, 0.97)
            love.graphics.print(item[1], x, cy)
            love.graphics.setColor(0.65, 0.70, 0.78)
            love.graphics.print(item[2], x + keyColW, cy)
            cy = cy + lineH
        end
    end
end

-- Draws the centered help modal overlay when visible
function help.draw(codeFont)
    if not help.visible then return end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    love.graphics.setFont(codeFont)
    local lineH = codeFont:getHeight() + 6
    local padX = 32
    local padTop = 22
    local headerH = lineH + 18
    local sectionGap = 16
    local footerH = lineH + 18

    local leftH = measureColumn(leftSections, lineH, sectionGap)
    local rightH = measureColumn(rightSections, lineH, sectionGap)
    local contentH = math.max(leftH, rightH)

    local boxW = math.min(w - 40, 1020)
    local boxH = padTop + headerH + contentH + footerH + 10
    local boxX = math.floor((w - boxW) / 2)
    local boxY = math.max(16, math.floor((h - boxH) / 2) - 16)

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.08, 0.09, 0.12, 0.97)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 8, 8)

    love.graphics.setColor(0.25, 0.28, 0.34)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 8, 8)

    love.graphics.setColor(0.20, 0.80, 0.40)
    love.graphics.rectangle("fill", boxX, boxY, boxW, 3)

    love.graphics.setColor(0.95, 0.95, 0.97)
    love.graphics.print("Old Fool's IDE - Keyboard Shortcuts", boxX + padX, boxY + padTop)

    local dividerY = boxY + padTop + lineH + 6
    love.graphics.setColor(0.22, 0.25, 0.30)
    love.graphics.line(boxX + padX, dividerY, boxX + boxW - padX, dividerY)

    local colGap = 36
    local colW = math.floor((boxW - padX * 2 - colGap) / 2)
    local keyColW = 190
    local contentY = dividerY + 14

    drawColumn(leftSections, boxX + padX, contentY, keyColW, lineH, sectionGap)
    drawColumn(rightSections, boxX + padX + colW + colGap, contentY, keyColW, lineH, sectionGap)

    local footerY = boxY + boxH - lineH - 10
    love.graphics.setColor(0.55, 0.60, 0.68)
    love.graphics.printf("Press F1 or Esc to close", boxX, footerY, boxW, "center")
end

return help