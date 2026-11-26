# Old Fool's IDE — User Manual & Reference Guide

**Old Fool's IDE** is a lightweight, keyboard-driven code editor engineered
specifically for **Lua** and **Luau** development. Built natively on the LÖVE
11.5 framework, it combines low-latency text editing with a crash-resilient
runtime architecture, dual-pane splitting, an integrated command shell, live
syntax linting, smart autocomplete, and automated project execution.

---

## Table of Contents

1. [System Requirements & Installation](#1-system-requirements--installation)
2. [Interface & Layout Architecture](#2-interface--layout-architecture)
   - [The Top Tab Bar](#the-top-tab-bar-tabbarlua)
   - [The Dual-Pane Editor](#the-dual-pane-editor-tablua--mainlua)
   - [The Integrated Terminal](#the-integrated-terminal-terminallua)
   - [The Abyss Status Bar](#the-abyss-status-bar-abysslua)
   - [Search & Autocomplete](#search--autocomplete)
3. [Dual-Engine Workflow: Lua vs. Luau](#3-dual-engine-workflow-lua-vs-luau)
4. [Master Keyboard Shortcuts (Cheat Sheet)](#4-master-keyboard-shortcuts-cheat-sheet)
5. [Macro & Snippet Catalog](#5-macro--snippet-catalog)
6. [Integrated Runner & Execution Pipeline](#6-integrated-runner--execution-pipeline)
7. [Crash Shield & Data Safety Mechanisms](#7-crash-shield--data-safety-mechanisms)
8. [Configuration & Customization](#8-configuration--customization)

---

## 1. System Requirements & Installation

### Prerequisites

- **Runtime:** [LÖVE (Love2D)](https://love2d.org/) version **11.5** or newer.
- **Operating System:** Linux (Ubuntu, Debian, Arch, Fedora, openSUSE), macOS,
  or Windows.
- **Fonts (Recommended):** _DejaVu Sans Mono for Powerline_, _DejaVu Sans Mono_,
  or _DejaVuSansMono.ttf_. If installed system-wide or located inside a `fonts/`
  directory, the IDE loads it automatically.
- **Optional System Tools:**
  - `zenity`: Used by `Ctrl + O` to summon native GUI file selection dialogs on
    Linux.
  - `luau-analyze` or `luau`: If present in your `$PATH`, the IDE uses it for
    native background static type analysis in Luau mode.

### Running the IDE

#### Option A: Run directly via LÖVE CLI

From the directory containing your IDE files:

```bash
love .
```

#### Option B: Open specific files on launch

You can launch the IDE with one or multiple files preloaded into tabs:

```bash
love . main.lua data/classes.lua scripts/network.luau
```

#### Option C: Drag & Drop

Drag any text or code file from your desktop file manager directly into the open
editor window to mount it into a new tab immediately.

---

## 2. Interface & Layout Architecture

```
+---------------------------------------------------------------------------------+
| [<] [main.lua *]  [network.luau]  [data/classes.lua]                      [x] [>] | <- Tab Bar (34px)
+---------------------------------------+-----------------------------------------+
| 01  local player = {                  | 01  -- Split Pane (F2)                  |
| 02      name = "Hunter",              | 02  local Network = {}                  |
| 03      hp = 100                      | 03  function Network.send() end         |
| 04  }                                 | 04  return Network                      |
|                                       |                                         |
+---------------------------------------+-----------------------------------------+
| [TERMINAL] $ touch enemies.lua                                                  | <- Terminal (F3)
+---------------------------------------------------------------------------------+
| Old Fool's IDE ready | Press F1 for shortcuts                           F1: Help| <- The Abyss (34px)
+---------------------------------------------------------------------------------+
```

### The Top Tab Bar

The top bar handles file navigation, buffer switching, and status tracking:

- **Dirty Buffer Flag (`*`):** Any file with unsaved modifications displays an
  asterisk next to its filename.
- **Error Highlighting:** Tabs containing syntax errors immediately render their
  labels in **crimson red**, warning you before you run or save.
- **Overflow & Horizontal Scrolling:** If you open more tabs than your window
  width can display, navigation buttons (`<` and `>`) appear at the ends. You
  can scroll horizontally through tabs using the **Mouse Wheel** anywhere over
  the tab bar or by clicking the overflow arrows.
- **Closing Tabs:** Click the `x` on any tab (or press `Ctrl + W`). If the file
  has unsaved edits, a confirmation dialog locks safely in the status bar to
  prevent accidental data loss.

### The Dual-Pane Editor

- **Line Numbering:** Clean gutter numbering with visual highlighting for active
  error lines.
- **Split-Screen (`F2`):** Divides the workspace into two independent,
  side-by-side editors. Click either pane to transfer focus. Each pane maintains
  its own cursor, scroll position, and active tab.
- **Text Selection:** Click and drag with the mouse or hold `Shift` while
  pressing arrow keys, `Home`, or `End`. Block selections render with soft blue
  background highlights.
- **Smart Auto-Dedent:** When typing closing blocks (`end`, `else`, `until`,
  `}`), the editor automatically shifts the indentation back 4 spaces.

### The Integrated Terminal

Press **`F3`** at any time to open or hide the floating console overlay at the
bottom of the screen:

- **Command Execution:** Run real shell commands (e.g., `ls -la`,
  `touch item.lua`, `git status`, `mkdir maps`). Commands execute natively via
  `io.popen` capturing both `stdout` and `stderr`.
- **Integrated History:** Retains the last 12 output lines in a retro green
  phosphor styling.
- **Screen Clearing:** Type `clear` or `cls` to wipe the console history buffer.
- **Non-Interfering:** When the terminal is open, typing inputs directly into
  the shell prompt rather than into your code buffers. Pressing `F3` or `Esc`
  closes it instantly.

### The Abyss Status Bar

The dark 34-pixel bar at the bottom provides immediate system telemetry:

- **Syntax Alerts:** Displays the active error line and compiler diagnostics in
  bright red.
- **Action Receipts:** Confirms saves, undo/redo states, tab renames, and
  automatic backup counts in green.
- **Help Shortcut:** Always displays the `F1: Help` reminder on the right edge.

### Search & Autocomplete

- **Search Bar (`Ctrl + F` / `search.lua`):** A floating top-right search box
  with real-time match counts (e.g., `2 / 9`). Press `Enter` to jump to the next
  match or `Shift + Enter` to navigate backwards.
- **Smart Autocomplete (`autocomplete.lua`):** Typing any token of 2 or more
  characters queries the 200+ word dictionary. Navigate choices with `Up`/`Down`
  and commit with `Tab` or `Enter`.

---

## 3. Dual-Engine Workflow: Lua vs. Luau

Old Fool's IDE features a specialized dual engine that lets you write standard
Lua game code and modern Roblox Luau scripts side by side without configuration
conflicts.

```
     [ File: script.lua ]                    [ File: player.luau ]
               │                                       │
               ▼                                       ▼
     ┌───────────────────┐                   ┌───────────────────┐
     │     LUA MODE      │                   │     LUAU MODE     │
     └───────────────────┘                   └───────────────────┘
       │               │                       │               │
       ▼               ▼                       ▼               ▼
 Standard Lua     Lua 5.1/JIT             Extended Type     External
 Highlighting      Compiler                Highlighting     Validator
(keywords,        (immediate              (types, task.*,  (luau-analyze
 strings, etc.)    syntax check)           backticks ` `)   passthrough)
```

### Switching Language Modes

1. **By Extension:** Files ending in `.luau` open in Luau mode automatically;
   files ending in `.lua` default to Lua mode.
2. **Manual Toggle (`F4`):** Press `F4` to flip the active tab between `LUA` and
   `LUAU` on the fly. The Abyss confirms the active engine.

### Differences Between Engines

| Feature                  | Standard Lua Mode                       | Luau Mode                                   |
| :----------------------- | :-------------------------------------- | :------------------------------------------ |
| **Primary Target**       | LÖVE2D, OpenResty, Defold, Standard Lua | Roblox Studio, Luau CLI scripts             |
| **Type Annotations**     | Flags `: type` as a syntax error        | Fully supported (`local x: number = 10`)    |
| **String Interpolation** | Standard quotes only (`"..."`, `'...'`) | Supports backticks (`` `Value: {x}` ``)     |
| **Extended Keywords**    | Standard Lua 5.1 keywords               | Adds `continue`, `type`, `export`, `typeof` |
| **Runtime Syntax Check** | In-memory compilation via `loadstring`  | Safe pass-through (or `luau-analyze` CLI)   |
| **Global Autocomplete**  | Lua globals, `table.*`, `love.*`        | `task.*`, `Vector3`, `CFrame`, `Instance`   |

---

## 4. Master Keyboard Shortcuts (Cheat Sheet)

Press **`F1`** inside the IDE at any time to display the built-in visual cheat
sheet.

### File & Workspace Management

| Shortcut              | Action                                                       |
| :-------------------- | :----------------------------------------------------------- |
| `Ctrl + O`            | Open file via file chooser dialog (or Drag & Drop)           |
| `Ctrl + S`            | Save current tab to disk                                     |
| `Ctrl + T`            | Create a new untitled tab (`module_N.lua`)                   |
| `Ctrl + R`            | Rename current tab and its underlying file on disk           |
| `Ctrl + W`            | Close the active tab (warns if unsaved)                      |
| `Ctrl + Left / Right` | Switch to the previous / next tab                            |
| `F2`                  | Toggle split-screen dual pane editing                        |
| `F3`                  | Toggle integrated terminal console                           |
| `F4`                  | Toggle active language mode (`LUA` $\leftrightarrow$ `LUAU`) |
| `F5`                  | Verify syntax, save all tabs, and run LÖVE project           |
| `Esc`                 | Close active modal, search box, terminal, or quit IDE        |

### Editing & Code Manipulation

| Shortcut         | Action                                                 |
| :--------------- | :----------------------------------------------------- |
| `Tab`            | Indent line / selection OR expand macro snippet        |
| `Shift + Tab`    | Unindent current line or selected block by 4 spaces    |
| `Ctrl + Z`       | Undo last change (up to 64 history states)             |
| `Ctrl + Y`       | Redo undone change                                     |
| `Ctrl + C`       | Copy selected text to system clipboard                 |
| `Ctrl + X`       | Cut selected text to system clipboard                  |
| `Ctrl + V`       | Paste text from system clipboard                       |
| `Ctrl + A`       | Select all text in the active buffer                   |
| `Ctrl + D`       | Duplicate current line directly below                  |
| `Home` / `End`   | Jump cursor to the start / end of current line         |
| `Delete`         | Delete character forward                               |
| `Backspace`      | Delete character backward (or delete entire selection) |
| `Shift + Arrows` | Create or adjust text selection                        |

### Search & Autocomplete

| Shortcut            | Action                                     |
| :------------------ | :----------------------------------------- |
| `Ctrl + F`          | Open in-buffer search box                  |
| `Enter` (in search) | Jump to next match                         |
| `Shift + Enter`     | Jump to previous match                     |
| `Up` / `Down`       | Navigate autocomplete suggestions list     |
| `Tab` / `Enter`     | Accept highlighted autocomplete suggestion |

---

## 5. Macro & Snippet Catalog

Type any keyword below and press **`Tab`** (with no active selection) to expand
it instantly into formatted code with automatic indentation:

### Standard Lua Macros

| Trigger     | Expanded Template                                                                              |
| :---------- | :--------------------------------------------------------------------------------------------- |
| `func`      | `local function name()`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                   |
| `funcg`     | `function name()`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                         |
| `funca`     | `function()`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                              |
| `if`        | `if condition then`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                       |
| `ifelse`    | `if condition then`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`else`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end` |
| `while`     | `while condition do`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                      |
| `repeat`    | `repeat`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`until condition`                                      |
| `for`       | `for i = 1, 10 do`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                                        |
| `forpairs`  | `for k, v in pairs(tbl) do`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                               |
| `foripairs` | `for i, v in ipairs(tbl) do`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end`                              |

### Luau & Roblox Macros

| Trigger        | Expanded Template                                                          |
| :------------- | :------------------------------------------------------------------------- |
| `luau_type`    | `type Props = {`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`}`                        |
| `luau_export`  | `export type Props = {`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`}`                 |
| `luau_spawn`   | `task.spawn(function()`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end)`              |
| `luau_delay`   | `task.delay(1, function()`<br>&nbsp;&nbsp;&nbsp;&nbsp;<br>`end)`           |
| `luau_service` | `local Service = game:GetService("ServiceName")`                           |
| `luau_class`   | Complete OOP boilerplate with `__index`, constructor, and metatable return |

---

## 6. Integrated Runner & Execution Pipeline

This feature is disable for the time being. Due to how file execution works in
LÖVE, the standard procedure of creating a folder including the main.lua and
hitting F5 wasn't working. This will probably be adressed in the near future.

---

## 7. Crash Shield & Data Safety Mechanisms

Old Fool's IDE is built with a defensive programming architecture designed to
make work loss nearly impossible:

- **Crash Shield (`love.errorhandler`):** If an unhandled exception or runtime
  bug occurs within the IDE itself, the application does not abruptly vanish. It
  replaces the screen with a clean recovery dashboard, displays the full
  traceback, and copies the crash log to your system clipboard automatically.
  Pressing **`R`** reloads the IDE instantly, while **`Esc`** closes it cleanly.
- **Dual Autosave Loop:**
  - **Time-Based:** Every 30 seconds, all modified buffers are automatically
    saved to disk in the background.
  - **Focus-Based:** Switching away from the IDE window (e.g., clicking onto a
    browser or terminal) triggers an immediate auto-save across all modified
    tabs.
- **Protected Close Dialogs:** Attempting to close a modified tab with
  `Ctrl + W` or the tab's `x` button prompts a confirmation prompt in The Abyss
  (`Save changes? Y/N/Esc`), preventing accidental closure.

---

## 8. Configuration & Customization

### Window & Engine Settings (`conf.lua`)

Window dimensions, title, and framework modules can be adjusted in `conf.lua`:

```lua
function love.conf(t)
    t.identity = "oldfoolide"
    t.version = "11.5"
    t.window.title = "Old Fool's IDE"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 500
    t.window.minheight = 300
    t.modules.physics = false   -- Disabled for minimal memory footprint
    t.modules.joystick = false  -- Disabled for minimal memory footprint
end
```

### Extending Snippets & Dictionaries (`dictionary.lua`)

You can add your own functions, game engine APIs, or custom macro templates by
adding strings to the tables in `dictionary.lua`:

```lua
-- Adding custom functions to autocomplete:
table.insert(dictionary, "MyCustomFunction")

-- Adding a custom snippet:
macros["my_macro"] = {
    "local function init()",
    "    print('Initialized!')",
    "end"
}

## License & Credits

Developed with the **LÖVE2D** framework, by Lucas Barbosa, an stubborn, persistent old fool. You can reach me via
https://substack.com/@oldfoolcoding and lucasbezerra@gmail.com. Designed for game developers, modders, and
 programmers who value lightweight, transparent, and keyboard-centric development environments.
```
