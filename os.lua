--[[
  AdvancedDesktop OS for ComputerCraft Advanced Computer
  - Desktop with icons
  - Taskbar with clock + window buttons
  - Start menu with app list
  - Window manager: move, close, minimize, maximize
  - Example apps: Shell, File Browser, Viewer

  Save as: /startup or /os.lua and run from startup
]]

-- CONFIG -------------------------------------------------

local DESKTOP_BG   = colors.blue
local TASKBAR_BG   = colors.gray
local TASKBAR_FG   = colors.white
local TITLEBAR_BG  = colors.lightGray
local TITLEBAR_FG  = colors.black
local WINDOW_BG    = colors.black
local ACTIVE_BORDER = colors.yellow
local INACTIVE_BORDER = colors.gray

-- STATE --------------------------------------------------

local w, h = term.getSize()

---@class Window
-- id, x, y, w, h, title, appDraw, handle, dragging, dragOffX, dragOffY
-- minimized, maximized, prevX, prevY, prevW, prevH
local windows = {}
local nextWinId = 1
local focusedWinId = nil

local desktopIcons = {
  { name = "Shell",   app = "shell" },
  { name = "Files",   app = "files" },
  { name = "Viewer",  app = "viewer" },
}

-- UTILS --------------------------------------------------

local function centerText(y, text, fg, bg)
  term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.clearLine()
  term.write(text)
end

local function drawDesktop()
  term.setBackgroundColor(DESKTOP_BG)
  term.setTextColor(colors.white)
  term.clear()

  centerText(2, "AdvancedDesktop OS", colors.white, DESKTOP_BG)
  centerText(3, "Advanced Computer", colors.yellow, DESKTOP_BG)

  local cols = 4
  local iconW = math.floor(w / cols)
  local row = 0
  local col = 0

  for i, icon in ipairs(desktopIcons) do
    col = (i - 1) % cols
    row = math.floor((i - 1) / cols)

    local ix = col * iconW + 2
    local iy = 5 + row * 3

    term.setCursorPos(ix, iy)
    term.setBackgroundColor(DESKTOP_BG)
    term.setTextColor(colors.white)
    term.write("[" .. icon.name .. "]")

    icon.x = ix
    icon.y = iy
    icon.w = #("[" .. icon.name .. "]")
    icon.h = 1
  end
end

local function getWindowById(id)
  for _, win in ipairs(windows) do
    if win.id == id then return win end
  end
end

local function bringToFront(win)
  for i, wv in ipairs(windows) do
    if wv.id == win.id then
      table.remove(windows, i)
      break
    end
  end
  table.insert(windows, win)
  focusedWinId = win.id
end

local function findWindowAt(x, y)
  for i = #windows, 1, -1 do
    local win = windows[i]
    if not win.minimized then
      if x >= win.x and x <= win.x + win.w - 1 and
         y >= win.y and y <= win.y + win.h - 1 then
        return win
      end
    end
  end
  return nil
end

-- WINDOW DRAWING -----------------------------------------

local function drawWindow(win)
  if win.minimized then return end

  local x, y, ww, hh = win.x, win.y, win.w, win.h

  -- Border (active vs inactive)
  local borderColor = (focusedWinId == win.id) and ACTIVE_BORDER or INACTIVE_BORDER
  term.setBackgroundColor(borderColor)
  term.setTextColor(borderColor)
  for iy = y - 1, y + hh do
    if iy >= 1 and iy <= h - 1 then
      term.setCursorPos(x - 1, iy)
      term.write(string.rep(" ", ww + 2))
    end
  end

  -- Title bar
  term.setBackgroundColor(TITLEBAR_BG)
  term.setTextColor(TITLEBAR_FG)
  if y >= 1 and y <= h - 1 then
    term.setCursorPos(x, y)
    term.write(string.rep(" ", ww))
  end

  -- Title text
  term.setCursorPos(x + 1, y)
  local title = win.title or "Window"
  if #title > ww - 8 then
    title = title:sub(1, ww - 8)
  end
  term.write(title)

  -- Buttons: [_] [□] [X]
  local btnX = x + ww - 9
  term.setCursorPos(btnX, y)
  term.write("[_][□][X]")

  -- Body
  term.setBackgroundColor(WINDOW_BG)
  term.setTextColor(colors.white)
  for iy = y + 1, y + hh - 1 do
    if iy >= 1 and iy <= h - 1 then
      term.setCursorPos(x, iy)
      term.write(string.rep(" ", ww))
    end
  end

  if win.appDraw then
    win.appDraw(win)
  end
end

local function closeWindow(win)
  for i, wv in ipairs(windows) do
    if wv.id == win.id then
      table.remove(windows, i)
      break
    end
  end
  if focusedWinId == win.id then
    focusedWinId = windows[#windows] and windows[#windows].id or nil
  end
end

local function minimizeWindow(win)
  win.minimized = true
  if focusedWinId == win.id then
    focusedWinId = nil
  end
end

local function maximizeWindow(win)
  if win.maximized then
    -- restore
    win.x, win.y, win.w, win.h =
      win.prevX, win.prevY, win.prevW, win.prevH
    win.maximized = false
  else
    win.prevX, win.prevY, win.prevW, win.prevH =
      win.x, win.y, win.w, win.h
    win.x = 2
    win.y = 2
    win.w = w - 3
    win.h = h - 4
    win.maximized = true
  end
end

local function restoreWindow(win)
  win.minimized = false
  bringToFront(win)
end

-- TASKBAR / START MENU -----------------------------------

local function drawTaskbar()
  term.setBackgroundColor(TASKBAR_BG)
  term.setTextColor(TASKBAR_FG)
  term.setCursorPos(1, h)
  term.clearLine()

  -- Start button
  term.setCursorPos(2, h)
  term.write("[Start]")

  -- Window buttons
  local xPos = 10
  for _, win in ipairs(windows) do
    local label = win.title or ("Win " .. win.id)
    if #label > 10 then label = label:sub(1, 10) end
    local text = "[" .. label .. "]"
    if xPos + #text < w - 10 then
      term.setCursorPos(xPos, h)
      if focusedWinId == win.id and not win.minimized then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
      else
        term.setBackgroundColor(TASKBAR_BG)
        term.setTextColor(TASKBAR_FG)
      end
      term.write(text)
      win.taskX = xPos
      win.taskW = #text
      xPos = xPos + #text + 1
    else
      win.taskX = nil
      win.taskW = nil
    end
  end

  -- Clock
  term.setBackgroundColor(TASKBAR_BG)
  term.setTextColor(TASKBAR_FG)
  local timeStr = textutils.formatTime(os.time(), true)
  local clockText = " " .. timeStr .. " "
  local cx = w - #clockText + 1
  term.setCursorPos(cx, h)
  term.write(clockText)
end

local function drawStartMenu()
  -- simple dropdown from Start button
  local menuX, menuY = 2, h - 6
  if menuY < 2 then menuY = 2 end
  local menuW, menuH = 18, 5

  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  for iy = 0, menuH - 1 do
    term.setCursorPos(menuX, menuY + iy)
    term.write(string.rep(" ", menuW))
  end

  local items = {
    "Shell",
    "File Browser",
    "Viewer",
    "Shutdown",
    "Reboot",
  }

  for i, label in ipairs(items) do
    term.setCursorPos(menuX + 1, menuY + i - 1)
    term.write(label)
  end

  return {
    x = menuX,
    y = menuY,
    w = menuW,
    h = menuH,
    items = items,
    visible = true,
  }
end

local startMenu = { visible = false }

local function redrawAll()
  drawDesktop()
  for _, win in ipairs(windows) do
    drawWindow(win)
  end
  drawTaskbar()
  if startMenu.visible then
    drawStartMenu()
  end
end

-- APPS ---------------------------------------------------

local function newWindow(title, x, y, ww, hh)
  local win = {
    id = nextWinId,
    x = x, y = y,
    w = ww, h = hh,
    title = title,
    minimized = false,
    maximized = false,
  }
  nextWinId = nextWinId + 1
  table.insert(windows, win)
  bringToFront(win)
  return win
end

-- Shell app
local function launchShell()
  local win = newWindow("Shell",
    5, 4,
    math.floor(w * 0.7),
    math.floor(h * 0.6)
  )

  local native = term.current()
  local shellWin = window.create(
    native,
    win.x + 1, win.y + 1,
    win.w - 2, win.h - 2,
    true
  )

  win.appDraw = function(self)
    -- shell draws itself
  end

  win.handle = function(self, event, p1, p2, p3)
    -- keyboard handled by shell
  end

  redrawAll()
  local oldTerm = term.redirect(shellWin)
  shell.run()
  term.redirect(oldTerm)
  closeWindow(win)
  redrawAll()
end

-- File browser
local function launchFiles()
  local win = newWindow("File Browser",
    8, 3,
    math.floor(w * 0.6),
    math.floor(h * 0.6)
  )

  win.cwd = "/"
  win.scroll = 0
  win.files = fs.list(win.cwd)
  win.selected = 1

  local function refreshFiles()
    win.files = fs.list(win.cwd)
    win.selected = math.min(win.selected, #win.files)
    if win.selected < 1 then win.selected = 1 end
  end

  win.appDraw = function(self)
    local innerX = self.x + 1
    local innerY = self.y + 1
    local innerW = self.w - 2
    local innerH = self.h - 2

    term.setBackgroundColor(WINDOW_BG)
    term.setTextColor(colors.white)

    term.setCursorPos(innerX, innerY)
    term.write(("Path: %s"):format(self.cwd:sub(1, innerW)))
    for i = 2, innerH do
      local idx = i - 1 + self.scroll
      term.setCursorPos(innerX, innerY + i - 1)
      term.write(string.rep(" ", innerW))
      local name = self.files[idx]
      if name then
        local full = fs.combine(self.cwd, name)
        local prefix = fs.isDir(full) and "[D] " or "    "
        if idx == self.selected then
          term.setBackgroundColor(colors.white)
          term.setTextColor(colors.black)
        else
          term.setBackgroundColor(WINDOW_BG)
          term.setTextColor(colors.white)
        end
        term.setCursorPos(innerX, innerY + i - 1)
        term.write((prefix .. name):sub(1, innerW))
      end
    end
  end

  win.handle = function(self, event, p1, p2, p3)
    if event == "key" then
      if p1 == keys.up then
        if self.selected > 1 then
          self.selected = self.selected - 1
        elseif self.scroll > 0 then
          self.scroll = self.scroll - 1
        end
      elseif p1 == keys.down then
        if self.selected < #self.files then
          self.selected = self.selected + 1
        else
          self.scroll = self.scroll + 1
        end
      elseif p1 == keys.enter then
        local fname = self.files[self.selected]
        if fname then
          local path = fs.combine(self.cwd, fname)
          if fs.isDir(path) then
            self.cwd = path
            self.scroll = 0
            self.selected = 1
            refreshFiles()
          else
            local f = fs.open(path, "r")
            if f then
              local content = f.readAll()
              f.close()
              local vwin = newWindow("View: " .. fname,
                self.x + 2, self.y + 2,
                math.floor(self.w * 0.8),
                math.floor(self.h * 0.8)
              )
              vwin.text = content
              vwin.scroll = 0
              vwin.appDraw = function(sw)
                local ix = sw.x + 1
                local iy = sw.y + 1
                local iw = sw.w - 2
                local ih = sw.h - 2
                term.setBackgroundColor(WINDOW_BG)
                term.setTextColor(colors.white)
                local lines = {}
                for line in (sw.text .. "\n"):gmatch("(.-)\n") do
                  table.insert(lines, line)
                end
                for i = 1, ih do
                  local idx = i + sw.scroll
                  term.setCursorPos(ix, iy + i - 1)
                  term.write(string.rep(" ", iw))
                  local line = lines[idx]
                  if line then
                    term.setCursorPos(ix, iy + i - 1)
                    term.write(line:sub(1, iw))
                  end
                end
              end
              vwin.handle = function(sw, ev, a)
                if ev == "key" then
                  if a == keys.up then
                    if sw.scroll > 0 then sw.scroll = sw.scroll - 1 end
                  elseif a == keys.down then
                    sw.scroll = sw.scroll + 1
                  end
                end
              end
            end
          end
        end
      elseif p1 == keys.backspace then
        if self.cwd ~= "/" then
          self.cwd = fs.combine(self.cwd, "..")
          self.scroll = 0
          self.selected = 1
          refreshFiles()
        end
      end
      redrawAll()
    end
  end

  redrawAll()
end

-- Viewer app
local function launchViewer()
  local win = newWindow("Welcome",
    6, 4,
    math.floor(w * 0.6),
    math.floor(h * 0.5)
  )

  win.text =
    "Welcome to AdvancedDesktop OS!\n\n" ..
    "- Click icons on the desktop to open apps.\n" ..
    "- Use the Start menu for system actions.\n" ..
    "- Taskbar buttons switch/minimize windows.\n" ..
    "- Drag windows by the title bar.\n" ..
    "- Use [_] [□] [X] to minimize, maximize, close.\n\n" ..
    "You can extend this OS by editing the code."

  win.scroll = 0

  win.appDraw = function(self)
    local ix = self.x + 1
    local iy = self.y + 1
    local iw = self.w - 2
    local ih = self.h - 2
    term.setBackgroundColor(WINDOW_BG)
    term.setTextColor(colors.white)
    local lines = {}
    for line in (self.text .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, line)
    end
    for i = 1, ih do
      local idx = i + self.scroll
      term.setCursorPos(ix, iy + i - 1)
      term.write(string.rep(" ", iw))
      local line = lines[idx]
      if line then
        term.setCursorPos(ix, iy + i - 1)
        term.write(line:sub(1, iw))
      end
    end
  end

  win.handle = function(self, event, p1)
    if event == "key" then
      if p1 == keys.up then
        if self.scroll > 0 then self.scroll = self.scroll - 1 end
      elseif p1 == keys.down then
        self.scroll = self.scroll + 1
      end
      redrawAll()
    end
  end

  redrawAll()
end

local appLaunchers = {
  shell  = launchShell,
  files  = launchFiles,
  viewer = launchViewer,
}

-- INPUT HANDLING -----------------------------------------

local function toggleStartMenu()
  startMenu.visible = not startMenu.visible
  redrawAll()
end

local function handleStartMenuClick(x, y)
  if not startMenu.visible then return end
  local menu = drawStartMenu()
  startMenu = menu

  if x < menu.x or x > menu.x + menu.w - 1 or
     y < menu.y or y > menu.y + menu.h - 1 then
    startMenu.visible = false
    redrawAll()
    return
  end

  local index = y - menu.y + 1
  local item = menu.items[index]
  startMenu.visible = false

  if item == "Shell" then
    launchShell()
  elseif item == "File Browser" then
    launchFiles()
  elseif item == "Viewer" then
    launchViewer()
  elseif item == "Shutdown" then
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    error("System halted", 0)
  elseif item == "Reboot" then
    os.reboot()
  end
  redrawAll()
end

local function handleDesktopClick(x, y)
  if y == h and x >= 2 and x <= 8 then
    toggleStartMenu()
    return
  end

  if startMenu.visible then
    handleStartMenuClick(x, y)
    return
  end

  for _, icon in ipairs(desktopIcons) do
    if x >= icon.x and x <= icon.x + icon.w - 1 and
       y >= icon.y and y <= icon.y + icon.h - 1 then
      local launcher = appLaunchers[icon.app]
      if launcher then launcher() end
      return
    end
  end
end

local function handleTaskbarClick(x, y)
  if y ~= h then return false end
  for _, win in ipairs(windows) do
    if win.taskX and win.taskW then
      if x >= win.taskX and x <= win.taskX + win.taskW - 1 then
        if focusedWinId == win.id and not win.minimized then
          minimizeWindow(win)
        else
          restoreWindow(win)
        end
        redrawAll()
        return true
      end
    end
  end
  return false
end

local function handleMouseClick(button, x, y)
  if y == h then
    if x >= 2 and x <= 8 then
      toggleStartMenu()
      return
    end
    if handleTaskbarClick(x, y) then return end
  end

  local win = findWindowAt(x, y)
  if win then
    bringToFront(win)
    focusedWinId = win.id

    if y == win.y then
      local btnStart = win.x + win.w - 9
      if x >= btnStart and x <= btnStart + 2 then
        minimizeWindow(win)
      elseif x >= btnStart + 3 and x <= btnStart + 5 then
        maximizeWindow(win)
      elseif x >= btnStart + 6 and x <= btnStart + 8 then
        closeWindow(win)
      else
        win.dragging = true
        win.dragOffX = x - win.x
        win.dragOffY = y - win.y
      end
    else
      if win.handle then
        win.handle(win, "mouse_click", button, x, y)
      end
    end
    redrawAll()
  else
    handleDesktopClick(x, y)
  end
end

local function handleMouseDrag(button, x, y)
  for _, win in ipairs(windows) do
    if win.dragging and not win.maximized then
      win.x = math.max(2, math.min(w - win.w, x - win.dragOffX))
      win.y = math.max(2, math.min(h - win.h - 1, y - win.dragOffY))
      redrawAll()
      return
    end
  end
end

local function handleMouseUp(button, x, y)
  for _, win in ipairs(windows) do
    if win.dragging then
      win.dragging = false
    end
  end
end

local function handleKey(key)
  local top = focusedWinId and getWindowById(focusedWinId) or windows[#windows]
  if top and top.handle then
    top.handle(top, "key", key)
  end
end

-- MAIN LOOP ----------------------------------------------

local function main()
  term.setCursorBlink(false)
  redrawAll()

  while true do
    drawTaskbar()
    local event, p1, p2, p3 = os.pullEvent()
    if event == "mouse_click" then
      handleMouseClick(p1, p2, p3)
    elseif event == "mouse_drag" then
      handleMouseDrag(p1, p2, p3)
    elseif event == "mouse_up" then
      handleMouseUp(p1, p2, p3)
    elseif event == "key" then
      handleKey(p1)
    elseif event == "term_resize" then
      w, h = term.getSize()
      redrawAll()
    end
  end
end

main()
