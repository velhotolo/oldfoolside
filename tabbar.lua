-- Top tab bar for switching and closing open editor tabs
local tabbar = {
    height = 34
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

-- Renders the top tab bar with active highlight, error indicators, and close buttons
function tabbar.draw(font, tabs, activeIdx)
    local w = love.graphics.getWidth()
    local h = tabbar.height

    -- Bar background and bottom border
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setColor(0.18, 0.20, 0.25)
    love.graphics.rectangle("fill", 0, h - 2, w, 2)

    local x = 0
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
end

-- Returns the clicked tab index and whether the click hit its close button
function tabbar.getClickedIndex(mx, my, font, tabs)
    if my > tabbar.height then return nil, false end

    local x = 0
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