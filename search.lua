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

-- Backward compatibility alias for main.lua
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

function Search.open(tab)
    Search.visible  = true
    Search.active   = true
    Search.ativo    = true
    Search.query    = ""
    Search.matches  = {}
    Search.matchIdx = 1

    if tab and tab.hasSelection and tab:hasSelection() then
        local txt = tab:getSelectedText()
        if txt and not txt:find("\n") then
            Search.query = txt
            Search.updateTabMatches(tab)
        end
    end
end

function Search.close()
    Search.visible = false
    Search.active  = false
    Search.ativo   = false
end

function Search.toggle(tab)
    if Search.visible then Search.close() else Search.open(tab) end
end

function Search.updateTabMatches(tab)
    Search.matches = {}
    Search.matchIdx = 1
    if not tab or not tab.lines or Search.query == "" then return end

    local qLower = Search.query:lower()
    for row, line in ipairs(tab.lines) do
        local lLower = tostring(line or ""):lower()
        local s = 1
        while true do
            local startPos, endPos = string.find(lLower, qLower, s, true)
            if not startPos then break end
            table.insert(Search.matches, { row = row, col = startPos, len = (endPos - startPos + 1) })
            s = endPos + 1
        end
    end

    if #Search.matches > 0 then
        Search.jumpToCurrentMatch(tab)
    end
end

function Search.jumpToCurrentMatch(tab)
    if not tab or #Search.matches == 0 then return end
    local m = Search.matches[Search.matchIdx]
    if m then
        tab.cy = m.row
        tab.cx = m.col
        tab.selStart = { x = m.col, y = m.row }
        tab.selEnd = { x = m.col + m.len, y = m.row }
    end
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
    end
end

function Search.draw(font)
    if not Search.visible then return end

    local w = love.graphics.getWidth()
    local boxW = math.min(500, w - 40)
    local boxH = 36
    local boxX = w - boxW - 20
    local boxY = 46

    love.graphics.setColor(0.12, 0.14, 0.18, 0.96)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setColor(0.35, 0.55, 0.85)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.60, 0.80, 1.0)
    love.graphics.print("Find:", boxX + 12, boxY + 8)

    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or ""
    local safeText = truncateUTF8(cleanUTF8(Search.query), 30)

    love.graphics.setColor(1, 1, 1)
    pcall(function()
        love.graphics.print(safeText .. cursor, boxX + 60, boxY + 8)
    end)

    local countText = (#Search.matches > 0)
        and string.format("%d / %d", Search.matchIdx, #Search.matches)
        or (Search.query ~= "" and "0/0" or "")

    love.graphics.setColor(0.70, 0.75, 0.85)
    love.graphics.printf(countText, boxX, boxY + 8, boxW - 14, "right")
    love.graphics.setColor(1, 1, 1, 1)
end

return Search
