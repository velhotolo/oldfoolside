local utf8 = require("utf8")
-- In-file text search bar and match navigator
local search = {
    visible = false,
    query = "",
    matches = {},
    currentIdx = 0
}

function search.backspace(tab)
if #search.query > 0 then
local lastChar = utf8.offset(search.query, -1)
search.query = string.sub(search.query, 1, lastChar - 1)
search.update(tab)
end
end

-- Opens the search bar and refreshes matches if a query already exists
function search.open(tab)
    search.visible = true
    if #search.query > 0 and tab then
        search.update(tab)
    end
end

-- Hides the search bar
function search.close()
    search.visible = false
end

-- Highlights the current match in the active tab and scrolls it into view
local function jumpToCurrent(tab)
    local match = search.matches[search.currentIdx]
    if not match or not tab then return end

    tab.selStart = { x = match.col, y = match.line }
    tab.selEnd   = { x = match.col + match.len, y = match.line }
    tab.cx       = match.col + match.len
    tab.cy       = match.line
    tab.scrollY  = math.max(0, match.line - 5)
end

-- Performs a case-insensitive plain-text search across all lines of the active tab
function search.update(tab)
    search.matches = {}
    search.currentIdx = 0

    if #search.query == 0 or not tab then
        if tab then
            tab:clearSelection()
        end
        return
    end

    local lowerQuery = string.lower(search.query)
    for lineIdx, line in ipairs(tab.lines) do
        local lowerLine = string.lower(line)
        local startPos = 1
        while true do
            -- Plain-text search (ignores Lua pattern magic characters)
            local s, e = string.find(lowerLine, lowerQuery, startPos, true)
            if not s then break end
            table.insert(search.matches, {
                line = lineIdx,
                col  = s,
                len  = e - s + 1
            })
            startPos = e + 1
        end
    end

    if #search.matches > 0 then
        search.currentIdx = 1
        jumpToCurrent(tab)
    else
        tab:clearSelection()
    end
end

-- Appends typed characters to the search query and refreshes results
function search.textinput(t, tab)
    search.query = search.query .. t
    search.update(tab)
end

-- Removes the last character from the search query and refreshes results
function search.backspace(tab)
    if #search.query > 0 then
        search.query = string.sub(search.query, 1, -2)
        search.update(tab)
    end
end

-- Jumps to the next search match, wrapping around to the first
function search.next(tab)
    if #search.matches == 0 then return end
    search.currentIdx = (search.currentIdx % #search.matches) + 1
    jumpToCurrent(tab)
end

-- Jumps to the previous search match, wrapping around to the last
function search.prev(tab)
    if #search.matches == 0 then return end
    search.currentIdx = ((search.currentIdx - 2) % #search.matches) + 1
    jumpToCurrent(tab)
end

-- Renders the floating search bar and match counter in the top-right corner
function search.draw(font)
    if not search.visible then return end

    local w = love.graphics.getWidth()
    local boxW = 340
    local boxH = 38
    local x = w - boxW - 15
    local y = 42 -- Positioned right below the tab bar

    -- Background and border
    love.graphics.setColor(0.11, 0.12, 0.16, 0.96)
    love.graphics.rectangle("fill", x, y, boxW, boxH, 5, 5)
    love.graphics.setColor(0.20, 0.80, 0.40)
    love.graphics.rectangle("line", x, y, boxW, boxH, 5, 5)

    -- Label and query text
    love.graphics.setColor(0.60, 0.65, 0.72)
    love.graphics.print("Find:", x + 10, y + 8)

    love.graphics.setColor(0.95, 0.95, 0.98)
    love.graphics.print(search.query, x + 65, y + 8)

    -- Match counter
    local countText = search.currentIdx .. "/" .. #search.matches
    if #search.query > 0 and #search.matches == 0 then
        love.graphics.setColor(0.95, 0.35, 0.35)
    else
        love.graphics.setColor(0.45, 0.85, 0.50)
    end
    love.graphics.print(countText, x + boxW - font:getWidth(countText) - 12, y + 8)
end

return search