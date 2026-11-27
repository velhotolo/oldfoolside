-- search.lua
local utf8 = require("utf8")

local Search = {
    visible    = false,
    active     = false,
    query      = "",
    matches    = {},
    matchIdx   = 1,
    results    = {},
    selected   = 1,
    scroll     = 0,
    lineHeight = 24,
    maxVisible = 14
}

Search.ativo = Search.active

local function truncateUTF8(str, maxChars)
    if not str then return "" end
    local count = 0
    for p, _ in utf8.codes(str) do
        count = count + 1
        if count > maxChars then
            return str:sub(1, p - 1) .. "..."
        end
    end
    return str
end

local function cleanUTF8(str)
    if not str then return "" end
    if pcall(utf8.len, str) then return str end

    local parts = {}
    local i = 1
    local len = #str
    while i <= len do
        local nextPos = utf8.offset(str, 2, i)
        if nextPos then
            local char = str:sub(i, nextPos - 1)
            if pcall(utf8.len, char) then table.insert(parts, char) end
            i = nextPos
        else
            local rest = str:sub(i)
            if pcall(utf8.len, rest) then table.insert(parts, rest) end
            break
        end
    end
    return table.concat(parts)
end

local function sincronizarViewportTab(tab, row)
    if not tab then return end
    tab.cy = row
    local winH = love.graphics.getHeight()
    local lineH = 20
    local visibleLines = math.max(1, math.floor((winH - 45 - 34) / lineH))
    local margin = math.floor(visibleLines / 2)
    tab.scrollY = math.max(0, row - margin)
end

function Search.jumpToCurrentMatch(tab)
    if not tab or #Search.matches == 0 then return end
    local m = Search.matches[Search.matchIdx]
    if not m then return end

    tab.cy = m.row
    tab.cx = m.col + m.len
    tab.selStart = { x = m.col, y = m.row }
    tab.selEnd   = { x = m.col + m.len, y = m.row }

    sincronizarViewportTab(tab, m.row)
end

function Search.updateTabMatches(tab)
    Search.matches = {}
    Search.matchIdx = 1
    if not tab or not tab.lines or Search.query == "" then return end

    local qLower = Search.query:lower()
    local curY = tab.cy or 1
    local curX = tab.cx or 1
    local melhorIndice = 1
    local encontrouProximo = false

    for row, line in ipairs(tab.lines) do
        local lLower = tostring(line or ""):lower()
        local s = 1
        while true do
            local startPos, endPos = string.find(lLower, qLower, s, true)
            if not startPos then break end

            local match = { row = row, col = startPos, len = (endPos - startPos + 1) }
            table.insert(Search.matches, match)

            if not encontrouProximo and (row > curY or (row == curY and startPos >= curX)) then
                melhorIndice = #Search.matches
                encontrouProximo = true
            end

            s = endPos + 1
        end
    end

    if #Search.matches > 0 then
        Search.matchIdx = melhorIndice
        Search.jumpToCurrentMatch(tab)
    end
end

function Search.open(tab)
    Search.visible = true
    Search.active  = true
    Search.ativo   = true

    if tab and tab.hasSelection and tab:hasSelection() then
        local txt = tab:getSelectedText()
        if txt and not txt:find("\n") then
            Search.query = txt
            Search.updateTabMatches(tab)
            return
        end
    end

    if Search.query ~= "" then
        Search.updateTabMatches(tab)
    end
end

function Search.close()
    Search.visible = false
    Search.active  = false
    Search.ativo   = false
end

function Search.next(tab)
    if #Search.matches == 0 then return end
    Search.matchIdx = (Search.matchIdx % #Search.matches) + 1
    Search.jumpToCurrentMatch(tab)
end

function Search.prev(tab)
    if #Search.matches == 0 then return end
    Search.matchIdx = Search.matchIdx - 1
    if Search.matchIdx < 1 then Search.matchIdx = #Search.matches end
    Search.jumpToCurrentMatch(tab)
end

function Search.textinput(t, tab)
    if not Search.visible then return end
    Search.query = Search.query .. tostring(t or "")
    Search.updateTabMatches(tab)
end

function Search.backspace(tab)
    if not Search.visible then return end
    local offset = utf8.offset(Search.query, -1)
    if offset then
        Search.query = string.sub(Search.query, 1, offset - 1)
        Search.updateTabMatches(tab)
    else
        Search.query = ""
        Search.matches = {}
        Search.matchIdx = 1
    end
end

function Search.mousepressed(mx, my, button, tab)
    if not Search.visible or button ~= 1 then return false end

    local w = love.graphics.getWidth()
    local boxW = math.min(520, w - 40)
    local boxH = 38
    local boxX = w - boxW - 20
    local boxY = 46

    if mx < boxX or mx > boxX + boxW or my < boxY or my > boxY + boxH then
        return false
    end

    -- Close [X]
    if mx >= boxX + boxW - 30 and mx <= boxX + boxW - 6 then
        Search.close()
        return true
    end

    -- Next [v]
    if mx >= boxX + boxW - 60 and mx <= boxX + boxW - 34 then
        Search.next(tab)
        return true
    end

    -- Previous [^]
    if mx >= boxX + boxW - 90 and mx <= boxX + boxW - 64 then
        Search.prev(tab)
        return true
    end

    return true
end

function Search.draw(font)
    if not Search.visible then return end

    local w = love.graphics.getWidth()
    local boxW = math.min(520, w - 40)
    local boxH = 38
    local boxX = w - boxW - 20
    local boxY = 46

    -- Container Panel
    love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setColor(0.35, 0.45, 0.65, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setLineWidth(1)

    -- Label
    love.graphics.setColor(0.40, 0.75, 1.0)
    love.graphics.print("Find:", boxX + 12, boxY + 10)

    -- Query
    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or ""
    local safeText = truncateUTF8(cleanUTF8(Search.query), 24)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print(safeText .. cursor, boxX + 58, boxY + 10)

    -- Counter
    local countText = (#Search.matches > 0)
        and string.format("%d/%d", Search.matchIdx, #Search.matches)
        or (Search.query ~= "" and "0/0" or "")
    love.graphics.setColor(0.60, 0.65, 0.75)
    love.graphics.printf(countText, boxX + 180, boxY + 10, boxW - 280, "right")

    -- Navigation Buttons
    local btnY = boxY + 7
    -- Previous
    love.graphics.setColor(0.20, 0.24, 0.32, 0.95)
    love.graphics.rectangle("fill", boxX + boxW - 90, btnY, 24, 24, 4, 4)
    love.graphics.setColor(0.80, 0.85, 0.95)
    love.graphics.printf("^", boxX + boxW - 90, btnY + 4, 24, "center")

    -- Next
    love.graphics.setColor(0.20, 0.24, 0.32, 0.95)
    love.graphics.rectangle("fill", boxX + boxW - 60, btnY, 24, 24, 4, 4)
    love.graphics.setColor(0.80, 0.85, 0.95)
    love.graphics.printf("v", boxX + boxW - 60, btnY + 4, 24, "center")

    -- Close
    love.graphics.setColor(0.60, 0.20, 0.25, 0.95)
    love.graphics.rectangle("fill", boxX + boxW - 30, btnY, 24, 24, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("x", boxX + boxW - 30, btnY + 3, 24, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return Search