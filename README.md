# Old Fool's IDE

![Lua](https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![LÖVE](https://img.shields.io/badge/L%C3%96VE-11.5-EA316E?style=for-the-badge&logo=love&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-20CC66?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active%20Development-blue?style=for-the-badge)

A lightweight, fast, and self-contained **Lua & LÖVE2D code editor** built from scratch *inside* LÖVE 11.5.

**Old Fool's IDE** was born out of the desire to understand how code editors actually work under the hood—no Electron, no heavy frameworks, just pure Lua tables, custom rendering, and direct control over every keystroke and pixel.
I'm currently coding all my projects in it, and so far, so good. I just need to remember to commit more often :(

---

## Features

- **Multi-Tab Editing & Split-Screen (`F2`):** Work across multiple Lua files, rename tabs inline, drag-and-drop files onto the window, or split the viewport into two independent panes.
- **Live Syntax Checking & Highlighting:** Real-time Lua syntax validation using `load`/`loadstring` with instant error reporting in the bottom status bar (*The Abyss*) and keyword colorization.
- **Built-in Autocomplete:** Context-aware popup backed by a hand-curated dictionary of the Lua standard library and the full **LÖVE 11.5** API.
- **One-Key Project Runner (`F5`):** Bugged, gotta refactor this one. Better using terminal.
- **In-File Search (`Ctrl+F`):** Fast, case-insensitive search overlay with match counter and jump-to-line highlighting.
- **Full Text Editing Essentials:** UTF-8 safe cursor/deletion, auto-indentation, mouse & keyboard selection, clipboard support (`Ctrl+C/X/V`), line duplication (`Ctrl+D`), and a 124-step Undo/Redo history per tab.
- **Built-in Shortcuts Overlay (`F1`):** Clean two-column cheat sheet accessible anytime without leaving the editor.
- **Terminal Instance (`F3`):** Mini terminal to touch file.lua and all the good stuff. 
- **Drag'n'Drop works on all OS:** Linux users have one more option which is Crtl + O (see below):

## Requirements & Running

1. Install **[LÖVE 11.5](https://love2d.org/)**.
2. *(Linux optional)* Install `zenity` if you want to use the `Ctrl+O` native file picker (drag-and-drop works on all platforms).
3. Clone this repository and launch it with LÖVE:

```bash
git clone [https://github.com/YOUR_USERNAME/old-fools-ide.git](https://github.com/YOUR_USERNAME/old-fools-ide.git)
cd old-fools-ide
love .´´´ 

You can also open files directly from the command line:

love . path/to/file.lua

Roadmap
    
    [ ] Better Identation
    
    [X] Autosave
    
    [ ] Documentation
         
    [ ] Expand macro expansion directly from autocomplete (dictionary.lua macros)

    [ ] Cross-platform file dialog & runner support (Windows/macOS)

    [ ] Horizontal scrolling & line wrapping options

    [ ] Customizable color themes and font size zoom

License

This project is licensed under the MIT License — see the LICENSE file for details.

old-fools-ide/
├── conf.lua           # LÖVE 11.5 window and module configuration
├── main.lua           # Core loop, input routing, split-screen, and pane rendering
├── tab.lua            # Text buffer class (UTF-8 editing, selection, undo/redo, syntax check)
├── tabbar.lua         # Top tab bar rendering and click/close handling
├── syntax.lua         # Lua keyword and comment tokenizer
├── abyss.lua          # Bottom status and error bar
├── autocomplete.lua   # Live suggestion popup
├── dictionary.lua     # Lua stdlib, LÖVE 11.5 API symbols, and code macros
├── search.lua         # In-file search bar and match navigator
├── runner.lua         # Pre-flight syntax check, save-all, and LÖVE launcher
├── terminal.lua       # Terminal instance inside IDE
└── help.lua           # Keyboard shortcuts modal overlay
