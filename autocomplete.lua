-- Autocomplete popup powered by Lua and LÖVE reserved words, dictionaries, and macros
local autocomplete = {
    suggestions = {},
    selectedIdx = 1,
    prefix = ""
}

-- Returns true if the autocomplete dropdown currently has suggestions to display
function autocomplete.isOpen()
    return #autocomplete.suggestions > 0
end

-- Clears all suggestions and resets the autocomplete state
function autocomplete.close()
    autocomplete.suggestions = {}
    autocomplete.selectedIdx = 1
    autocomplete.prefix = ""
end

-- Scans the word before the cursor and populates up to 8 matching dictionary suggestions
function autocomplete.update(tab, dict)
    autocomplete.close()

    local line = tab.lines[tab.cy] or ""
    local before = string.sub(line, 1, tab.cx - 1)
    local prefix = string.match(before, "[%w_%.]+$")

    if not prefix or #prefix < 2 then return end

    local wordList = dict.dictionary or dict.words or dict
    local lowerPrefix = string.lower(prefix)

    for _, word in ipairs(wordList) do
        if type(word) == "string" and word ~= prefix then
            if string.sub(string.lower(word), 1, #lowerPrefix) == lowerPrefix then
                table.insert(autocomplete.suggestions, word)
                if #autocomplete.suggestions >= 8 then break end
            end
        end
    end

    if #autocomplete.suggestions > 0 then
        autocomplete.prefix = prefix
        autocomplete.selectedIdx = 1
    end
end

-- Moves the highlighted suggestion index up or down, wrapping around the list
function autocomplete.move(dir)
    if not autocomplete.isOpen() then return end
    autocomplete.selectedIdx = ((autocomplete.selectedIdx - 1 + dir) % #autocomplete.suggestions) + 1
end

-- Replaces the current word prefix with the selected suggestion and updates tab history
function autocomplete.accept(tab)
    if not autocomplete.isOpen() then return false end

    local choice   = autocomplete.suggestions[autocomplete.selectedIdx]
    local line     = tab.lines[tab.cy]
    local startCol = tab.cx - #autocomplete.prefix

    local before = string.sub(line, 1, startCol - 1)
    local after  = string.sub(line, tab.cx)

    tab.lines[tab.cy] = before .. choice .. after
    tab.cx            = startCol + #choice
    tab:checkErrors()
    tab:saveHistory()

    autocomplete.close()
    return true
end

-- Renders the autocomplete suggestion box anchored below the cursor
        function autocomplete.draw(font, tab, offsetX)
    if not autocomplete.isOpen() then return end

    local lineH  = font:getHeight() + 4
    local before = string.sub(tab.lines[tab.cy], 1, tab.cx - 1)
  local boxX = (offsetX or 0) + 60 + font:getWidth(before)
    local boxY   = 45 + (tab.cy - tab.scrollY) * lineH

    -- Calculate box dimensions based on the longest suggestion
    local boxW = 180
    for _, word in ipairs(autocomplete.suggestions) do
        boxW = math.max(boxW, font:getWidth(word) + 24)
    end
    local boxH = #autocomplete.suggestions * lineH + 8

    -- Background and border
    love.graphics.setColor(0.11, 0.12, 0.16, 0.96)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4, 4)
    love.graphics.setColor(0.20, 0.80, 0.40)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4, 4)

    -- Suggestion items
    for i, word in ipairs(autocomplete.suggestions) do
        local itemY = boxY + 4 + (i - 1) * lineH
        if i == autocomplete.selectedIdx then
            love.graphics.setColor(0.20, 0.45, 0.30)
            love.graphics.rectangle("fill", boxX + 2, itemY, boxW - 4, lineH)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.75, 0.78, 0.85)
        end
        love.graphics.print(word, boxX + 10, itemY + 2)
    end
end

return autocomplete