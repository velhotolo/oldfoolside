-- tab.lua
local utf8 = require("utf8")
local compileChunk = loadstring or load

local tab = {}
tab.__index = tab

local INDENT_STR = "    "
local INDENT_SIZE = #INDENT_STR

local function cloneLines(lines)
    local copy = {}
    for i, line in ipairs(lines) do copy[i] = line end
    return copy
end

local function stripInlineComment(line)
    return line:gsub("%-%-.*$", "")
end

local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function tab:new(name, lines, filepath)
    local initialLines = lines and cloneLines(lines) or { "" }
    if #initialLines == 0 then initialLines = { "" } end

    local initialName = name or "untitled.lua"
    -- Auto detection by file suffix 
    local detectedMode = (initialName:match("%.luau$") or (filepath and filepath:match("%.luau$"))) and "luau" or "lua"

    local instance = setmetatable({
        name         = initialName,
        filepath     = filepath,
        lines        = initialLines,
        cx           = 1,
        cy           = 1,
        selStart     = nil,
        selEnd       = nil,
        errorLine    = nil,
        errorMsg     = nil,
        history      = {},
        histIdx      = 0,
        savedIdx     = 0,
        scrollY      = 0,
        renaming     = false,
        renameBuffer = "",
        mode         = detectedMode -- "lua" or "luau"
    }, self)

    instance:checkErrors()
    instance:saveHistory()
    instance.savedIdx = instance.histIdx
    return instance
end

function tab:toggleMode()
    self.mode = (self.mode == "lua") and "luau" or "lua"
    self:checkErrors()
    return self.mode
end

function tab:startRename()
    self.renaming = true
    self.renameBuffer = self.name
end

function tab:cancelRename()
    self.renaming = false
    self.renameBuffer = ""
end

function tab:renameInput(text)
    if not self.renaming then return end
    self.renameBuffer = self.renameBuffer .. text
end

function tab:renameBackspace()
    if not self.renaming then return end
    local byteoffset = utf8.offset(self.renameBuffer, -1)
    if byteoffset then
        self.renameBuffer = string.sub(self.renameBuffer, 1, byteoffset - 1)
    end
end

function tab:confirmRename(projectDir)
    if not self.renaming then return false end
    local newName = self.renameBuffer:match("^%s*(.-)%s*$")
    self.renaming = false
    self.renameBuffer = ""

    if newName == "" or newName == self.name then return false end

    if self.filepath then
        local dir = self.filepath:match("^(.*[/\\])") or ""
        local newPath = dir .. newName
        if fileExists(newPath) then return false end
        if os.rename(self.filepath, newPath) then self.filepath = newPath end
    end

    self.name = newName
    self.mode = newName:match("%.luau$") and "luau" or self.mode
    self:checkErrors()
    return true
end

-- Anti-crash verification: Luau Linux native validation support
function tab:checkErrors()
    local code = table.concat(self.lines, "\n")

    if self.mode == "lua" then
        local _, err = compileChunk(code)
        if err then
            self.errorLine = tonumber(string.match(err, ":(%d+):"))
            self.errorMsg = "[LUA SYNTAX ERROR] " .. err
        else
            self.errorLine = nil
            self.errorMsg = nil
        end
    elseif self.mode == "luau" then
        -- In case luau's native utils is installed in Linux, this is validated through it
        local handle = io.popen("command -v luau-analyze 2>/dev/null || command -v luau 2>/dev/null")
        local binPath = handle and handle:read("*l")
        if handle then handle:close() end

        if binPath and binPath ~= "" then
            local tmp = os.tmpname()
            local f = io.open(tmp, "w")
            if f then
                f:write(code)
                f:close()
                local check = io.popen(binPath .. " " .. tmp .. " 2>&1")
                local out = check and check:read("*a") or ""
                if check then check:close() end
                os.remove(tmp)

                local errLine = out:match(":(%d+):")
                if errLine then
                    self.errorLine = tonumber(errLine)
                    self.errorMsg = "[LUAU ERROR] Line " .. errLine .. ": " .. (out:match(":%d+:%s*(.-)\n") or out)
                else
                    self.errorLine = nil
                    self.errorMsg = nil
                end
            end
        else
            -- Don't hit false errors on Luau
            self.errorLine = nil
            self.errorMsg = nil
        end
    end
end

function tab:delete()
    if self:getSelectionRange() then
        self:deleteSelection()
        self:checkErrors()
        self:saveHistory()
        return
    end

    local line = self.lines[self.cy]
    if self.cx <= #line then
        local nextCx = utf8.offset(line, 2, self.cx) or (#line + 1)
        self.lines[self.cy] = string.sub(line, 1, self.cx - 1) .. string.sub(line, nextCx)
    elseif self.cy < #self.lines then
        self.lines[self.cy] = line .. self.lines[self.cy + 1]
        table.remove(self.lines, self.cy + 1)
    end
    self:checkErrors()
    self:saveHistory()
end

function tab:saveHistory()
    if self.savedIdx > self.histIdx then self.savedIdx = -1 end
    for i = #self.history, self.histIdx + 1, -1 do table.remove(self.history, i) end
    table.insert(self.history, { lines = cloneLines(self.lines), cx = self.cx, cy = self.cy })
    if #self.history > 64 then
        table.remove(self.history, 1)
        self.savedIdx = self.savedIdx - 1
    end
    self.histIdx = #self.history
end

function tab:undo()
    if self.histIdx <= 1 then return end
    self.histIdx = self.histIdx - 1
    local state = self.history[self.histIdx]
    self.lines = cloneLines(state.lines)
    self.cx, self.cy = state.cx, state.cy
    self:clearSelection()
    self:checkErrors()
end

function tab:redo()
    if self.histIdx >= #self.history then return end
    self.histIdx = self.histIdx + 1
    local state = self.history[self.histIdx]
    self.lines = cloneLines(state.lines)
    self.cx, self.cy = state.cx, state.cy
    self:clearSelection()
    self:checkErrors()
end

function tab:isModified()
    return self.histIdx ~= self.savedIdx
end

function tab:clearSelection()
    self.selStart = nil
    self.selEnd = nil
end

function tab:insertText(text)
    self:deleteSelection()
    local before                 = string.sub(self.lines[self.cy], 1, self.cx - 1)
    local after                  = string.sub(self.lines[self.cy], self.cx)
    local newLine                = before .. text .. after
    self.lines[self.cy]          = newLine
    self.cx                      = self.cx + #text

    local leadingSpaces, keyword = newLine:match("^( +)(%S+)$")
    if leadingSpaces and #leadingSpaces >= INDENT_SIZE then
        if keyword == "end" or keyword == "else" or keyword == "until" or keyword == "}" then
            self.lines[self.cy] = string.sub(newLine, INDENT_SIZE + 1)
            self.cx = math.max(1, self.cx - INDENT_SIZE)
        end
    end

    self:checkErrors()
    self:saveHistory()
end

function tab:backspace()
    if self:deleteSelection() then
        self:checkErrors()
        self:saveHistory()
        return
    end

    if self.cx > 1 then
        local line          = self.lines[self.cy]
        local prevCx        = utf8.offset(line, -1, self.cx) or 1
        self.lines[self.cy] = string.sub(line, 1, prevCx - 1) .. string.sub(line, self.cx)
        self.cx             = prevCx
    elseif self.cy > 1 then
        local rest = self.lines[self.cy]
        table.remove(self.lines, self.cy)
        self.cy = self.cy - 1
        self.cx = #self.lines[self.cy] + 1
        self.lines[self.cy] = self.lines[self.cy] .. rest
    end

    self:checkErrors()
    self:saveHistory()
end

function tab:newLine()
    self:deleteSelection()
    local before      = string.sub(self.lines[self.cy], 1, self.cx - 1)
    local after       = string.sub(self.lines[self.cy], self.cx)
    local indent      = string.match(before, "^%s*") or ""
    local cleanBefore = stripInlineComment(before)

    local opensBlock  =
        string.match(cleanBefore, "%f[%w_]then%s*$") or
        string.match(cleanBefore, "%f[%w_]do%s*$") or
        string.match(cleanBefore, "%f[%w_]else%s*$") or
        string.match(cleanBefore, "%f[%w_]repeat%s*$") or
        string.match(cleanBefore, "function%s*[%w_%.%:]*%s*%b()%s*$") or
        string.match(cleanBefore, "{%s*$")

    if opensBlock then indent = indent .. INDENT_STR end

    self.lines[self.cy] = before
    table.insert(self.lines, self.cy + 1, indent .. after)
    self.cy = self.cy + 1
    self.cx = #indent + 1
    self:checkErrors()
    self:saveHistory()
end

function tab:indent()
    local s, e = self:getSelectionRange()
    if s then
        for i = s.y, e.y do self.lines[i] = INDENT_STR .. self.lines[i] end
        self.selStart.x = self.selStart.x + INDENT_SIZE
        self.selEnd.x   = self.selEnd.x + INDENT_SIZE
        self.cx         = self.cx + INDENT_SIZE
    else
        local before        = string.sub(self.lines[self.cy], 1, self.cx - 1)
        local after         = string.sub(self.lines[self.cy], self.cx)
        self.lines[self.cy] = before .. INDENT_STR .. after
        self.cx             = self.cx + INDENT_SIZE
    end
    self:checkErrors()
    self:saveHistory()
end

function tab:unindent()
    local s, e      = self:getSelectionRange()
    local startLine = s and s.y or self.cy
    local endLine   = e and e.y or self.cy

    for i = startLine, endLine do
        local line = self.lines[i]
        local spaces = line:match("^ +")
        local removed = 0

        if spaces then
            removed = math.min(#spaces, INDENT_SIZE)
            self.lines[i] = string.sub(line, removed + 1)
        elseif string.sub(line, 1, 1) == "\t" then
            removed = 1
            self.lines[i] = string.sub(line, 2)
        end

        if removed > 0 then
            if s and i == self.selStart.y then self.selStart.x = math.max(1, self.selStart.x - removed) end
            if e and i == self.selEnd.y then self.selEnd.x = math.max(1, self.selEnd.x - removed) end
            if i == self.cy then self.cx = math.max(1, self.cx - removed) end
        end
    end
    self:checkErrors()
    self:saveHistory()
end

function tab:save(projectDir)
    local path = self.filepath or ((projectDir or ".") .. "/" .. self.name)
    local file = io.open(path, "w")
    if file then
        file:write(table.concat(self.lines, "\n"))
        file:close()
        self.filepath = path
        self.savedIdx = self.histIdx
        return true, path
    end
    return false, path
end

function tab:scroll(delta)
    local maxScroll = math.max(0, #self.lines - 1)
    self.scrollY = math.max(0, math.min(maxScroll, self.scrollY + delta))
end

function tab:hasSelection()
    return self.selStart ~= nil and self.selEnd ~= nil
        and (self.selStart.x ~= self.selEnd.x or self.selStart.y ~= self.selEnd.y)
end

function tab:getSelectionRange()
    if not self:hasSelection() then return nil, nil end
    local a, b = self.selStart, self.selEnd
    if a.y > b.y or (a.y == b.y and a.x > b.x) then return b, a end
    return a, b
end

function tab:deleteSelection()
    local s, e = self:getSelectionRange()
    if not s then return false end

    local before = string.sub(self.lines[s.y], 1, s.x - 1)
    local after  = string.sub(self.lines[e.y], e.x)

    for i = e.y, s.y + 1, -1 do table.remove(self.lines, i) end

    self.lines[s.y] = before .. after
    self.cx, self.cy = s.x, s.y
    self:clearSelection()
    return true
end

function tab:getSelectedText()
    local s, e = self:getSelectionRange()
    if not s then return nil end
    if s.y == e.y then return string.sub(self.lines[s.y], s.x, e.x - 1) end

    local result = { string.sub(self.lines[s.y], s.x) }
    for i = s.y + 1, e.y - 1 do table.insert(result, self.lines[i]) end
    table.insert(result, string.sub(self.lines[e.y], 1, e.x - 1))
    return table.concat(result, "\n")
end

function tab:cut()
    local text = self:getSelectedText()
    if not text then return nil end
    self:deleteSelection()
    self:checkErrors()
    self:saveHistory()
    return text
end

function tab:paste(text)
    if not text or #text == 0 then return end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    self:deleteSelection()

    local pastedLines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do table.insert(pastedLines, line) end

    local before = string.sub(self.lines[self.cy], 1, self.cx - 1)
    local after  = string.sub(self.lines[self.cy], self.cx)

    if #pastedLines == 1 then
        self.lines[self.cy] = before .. pastedLines[1] .. after
        self.cx = self.cx + #pastedLines[1]
    else
        self.lines[self.cy] = before .. pastedLines[1]
        for i = 2, #pastedLines - 1 do table.insert(self.lines, self.cy + i - 1, pastedLines[i]) end
        local lastLine = pastedLines[#pastedLines]
        table.insert(self.lines, self.cy + #pastedLines - 1, lastLine .. after)
        self.cy = self.cy + #pastedLines - 1
        self.cx = #lastLine + 1
    end

    self:checkErrors()
    self:saveHistory()
end

function tab:duplicateLine()
    local currentLine = self.lines[self.cy]
    table.insert(self.lines, self.cy + 1, currentLine)
    self.cy = self.cy + 1
    self:clearSelection()
    self:checkErrors()
    self:saveHistory()
end

function tab:selectAll()
    local lastLine   = #self.lines
    local lastCol    = #self.lines[lastLine] + 1
    self.selStart    = { x = 1, y = 1 }
    self.selEnd      = { x = lastCol, y = lastLine }
    self.cx, self.cy = lastCol, lastLine
end

return tab

