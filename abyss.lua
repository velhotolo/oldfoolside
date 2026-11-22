-- Bottom status bar ("The Abyss") that displays messages, syntax errors, and launch status
local abyss = {
    message = "Old Fool's IDE ready | Press F1 for shortcuts",
    isError = false
}

-- Updates the status bar message and sets whether it should be styled as an error
function abyss.set(msg, isError)
    abyss.message = msg
    abyss.isError = isError or false
end

-- Renders the bottom status bar, prioritizing the active tab's syntax error if one exists
function abyss.draw(font, tab)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local barH = 34
    local y = h - barH

    -- Background and top border
    love.graphics.setColor(0.05, 0.05, 0.07)
    love.graphics.rectangle("fill", 0, y, w, barH)

    love.graphics.setColor(0.18, 0.20, 0.25)
    love.graphics.rectangle("fill", 0, y, w, 2)

    -- Status or syntax error message
    if tab and tab.errorMsg then
        love.graphics.setColor(0.95, 0.30, 0.30)
        love.graphics.print(tab.errorMsg, 15, y + 7)
    else
        if abyss.isError then
            love.graphics.setColor(0.95, 0.30, 0.30)
        else
            love.graphics.setColor(0.45, 0.85, 0.50)
        end
        love.graphics.print(abyss.message, 15, y + 7)
    end

    -- Right-aligned help hint
    local hint = "F1: Help"
    love.graphics.setColor(0.45, 0.48, 0.55)
    love.graphics.print(hint, w - font:getWidth(hint) - 15, y + 7)
end

return abyss