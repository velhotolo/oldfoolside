local runner = {}

-- Validates all tabs for syntax errors, saves them to disk, and launches the LÖVE project
function runner.run(tabs, projectDir)
    -- 1. Abort if any tab contains a syntax error
    for _, tab in ipairs(tabs) do
        tab:checkErrors()
        if tab.errorMsg then
            return false, "Cannot run! Syntax error in " .. tab.name
        end
    end

    -- 2. Save all open tabs before execution
    for _, tab in ipairs(tabs) do
        local ok, path = tab:save(projectDir)
        if not ok then
            return false, "Failed to save: " .. path
        end
    end

    -- 3. Launch the project in a background LÖVE process
    os.execute("love " .. projectDir .. " &")
    return true, "Running project (" .. projectDir .. ")..."
end

return runner