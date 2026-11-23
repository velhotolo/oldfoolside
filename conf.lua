function love.conf(t)
    t.identity = "oldfoolide"
    t.version = "11.5"
    t.window.title = "Old Fool's IDE"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 500
    t.window.minheight = 300
    t.window.icon = "icon.png"
    t.modules.physics = false
    t.modules.joystick = false
end
