-- Top tab bar for switching and closing open editor tabs
local tabbar = {
    height = 34,
    scrollX = 0,
    btnW = 24
}

local CLOSE_BTN_W = 22

-- Returns the tab's display name with an asterisk if it has unsaved changes
local function getTabLabel(tab)
    return tab.name .. (tab:isModified() and " *" or "")
end

-- Calculates the total pixel width of a single tab button including padding and close button
local function getTabWidth(font, tab)
    return font:getWidth(getTabLabel(tab)) + 28 + CLOSE_BTN_W
end

-- Calculates the total width of all open tabs combined
local function getTotalWidth(font, tabs)
    local total = 0
    for _, tab in ipairs(tabs) do
        total = total + getTabWidth(font, tab)
    end
    return total
end

-- Calculates scroll layout info (whether arrows are needed, visible area, max scroll)
local function getScrollMetrics(font, tabs)
    local w = love.graphics.getWidth()
    local totalW = getTotalWidth(font, tabs)
    local needScroll = totalW > w
    local viewX = needScroll and tabbar.btnW or 0
    local viewW = needScroll and (w - tabbar.btnW * 2) or w
    local maxScroll = math.max(0, totalW - viewW)
    tabbar.scrollX = math.max(0, math.min(tabbar.scrollX, maxScroll))
    return w, needScroll, viewX, viewW, maxScroll
end

-- Ensures the active tab is visible (optional: call when opening or switching tabs)
function tabbar.ensureVisible(font, tabs, activeIdx)
    local _, _, _, viewW, maxScroll = getScrollMetrics(font, tabs)
    local tabX = 0
    for i = 1, activeIdx - 1 do
        tabX = tabX + getTabWidth(font, tabs[i])
    end
    local tabW = tabs[activeIdx] and getTabWidth(font, tabs[activeIdx]) or 0

    if tabX < tabbar.scrollX then
        tabbar.scrollX = tabX
    elseif tabX + tabW > tabbar.scrollX + viewW then
        tabbar.scrollX = (tabX + tabW) - viewW
    end
    tabbar.scrollX = math.max(0, math.min(tabbar.scrollX, maxScroll))
end

-- Scrolls the tab bar horizontally when using the mouse wheel over it
function tabbar.wheelmoved(dx, dy, font, tabs)
    local _, my = love.mouse.getPosition()
    if my > tabbar.height then return false end
    local _, needScroll, _, _, maxScroll = getScrollMetrics(font, tabs)
    if not needScroll then return false end

    tabbar.scrollX = math.max(0, math.min(tabbar.scrollX - dy * 45, maxScroll))
    return true
end

-- Renders the top tab bar with active highlight, error indicators, close buttons, and scroll arrows
function tabbar.draw(font, tabs, activeIdx)
    local h = tabbar.height
    local w, needScroll, viewX, viewW, maxScroll = getScrollMetrics(font, tabs)

    -- Bar background and bottom border
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.18, 0.20, 0.25)
    love.graphics.rectangle("fill", 0, h - 2, w, 2)

    -- Clip tabs to the visible area
    love.graphics.setScissor(viewX, 0, viewW, h)
    local x = viewX - tabbar.scrollX
    for i, tab in ipairs(tabs) do
        local label = getTabLabel(tab)
        local tabW = getTabWidth(font, tab)
        local isActive = (i == activeIdx)

        -- Tab background and active top accent
        if isActive then
            love.graphics.setColor(0.12, 0.14, 0.18)
            love.graphics.rectangle("fill", x, 0, tabW, h)
            love.graphics.setColor(0.20, 0.80, 0.40)
            love.graphics.rectangle("fill", x, 0, tabW, 3)
        else
            love.graphics.setColor(0.07, 0.08, 0.10)
            love.graphics.rectangle("fill", x, 0, tabW, h - 2)
        end

        -- Vertical separator
        love.graphics.setColor(0.18, 0.20, 0.25)
        love.graphics.rectangle("fill", x + tabW - 1, 0, 1, h)

        -- Tab label color (red on syntax error, bright if active, muted otherwise)
        if tab.errorMsg then
            love.graphics.setColor(0.95, 0.35, 0.35)
        elseif isActive then
            love.graphics.setColor(0.95, 0.95, 0.98)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.print(label, x + 14, 7)

        -- Close button ("x")
        love.graphics.setColor(0.55, 0.58, 0.65)
        love.graphics.print("x", x + tabW - CLOSE_BTN_W + 4, 6)

        x = x + tabW
    end
    love.graphics.setScissor()

    -- Draw "<" and ">" scroll buttons only when tabs overflow
    if needScroll then
        love.graphics.setColor(0.10, 0.11, 0.14)
        love.graphics.rectangle("fill", 0, 0, tabbar.btnW, h - 2)
        love.graphics.rectangle("fill", w - tabbar.btnW, 0, tabbar.btnW, h - 2)

        love.graphics.setColor(0.18, 0.20, 0.25)
        love.graphics.rectangle("fill", tabbar.btnW - 1, 0, 1, h)
        love.graphics.rectangle("fill", w - tabbar.btnW, 0, 1, h)

        love.graphics.setColor(tabbar.scrollX > 0 and { 0.95, 0.95, 0.98 } or { 0.35, 0.38, 0.42 })
        love.graphics.printf("<", 0, 7, tabbar.btnW, "center")

        love.graphics.setColor(tabbar.scrollX < maxScroll and { 0.95, 0.95, 0.98 } or { 0.35, 0.38, 0.42 })
        love.graphics.printf(">", w - tabbar.btnW, 7, tabbar.btnW, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- Returns the clicked tab index and whether the click hit its close button
-- Also handles clicks on the "<" and ">" scroll buttons automatically
function tabbar.getClickedIndex(mx, my, font, tabs)
    if my > tabbar.height then return nil, false end

    local _, needScroll, viewX, viewW, maxScroll = getScrollMetrics(font, tabs)

    if needScroll then
        if mx < viewX then
            tabbar.scrollX = math.max(0, tabbar.scrollX - 120)
            return nil, false
        elseif mx > viewX + viewW then
            tabbar.scrollX = math.min(maxScroll, tabbar.scrollX + 120)
            return nil, false
        end
    end

    local x = viewX - tabbar.scrollX
    for i, tab in ipairs(tabs) do
        local tabW = getTabWidth(font, tab)
        if mx >= x and mx <= x + tabW then
            local clickedClose = mx >= (x + tabW - CLOSE_BTN_W - 4)
            return i, clickedClose
        end
        x = x + tabW
    end
    return nil, false
end

return tabbar

