--[[
  SimpleDesktop OS for ComputerCraft Advanced Computer
  - Desktop with icons
  - Taskbar with clock
  - Basic window manager (move/close windows)
  - Example apps: Shell, File Browser, Text Viewer

  Save as: /startup
]]

-- CONFIG -------------------------------------------------

local DESKTOP_BG = colors.blue
local TASKBAR_BG = colors.gray
local TASKBAR_FG = colors.white
local TITLEBAR_BG = colors.lightGray
local TITLEBAR_FG = colors.black
local WINDOW_BG = colors.black

-- STATE --------------------------------------------------

local w, h = term.getSize()

local windows = {}      -- { {id, x, y, w, h, title, draw, handle, dragging, dragOffX, dragOffY} }
local nextWinId = 1

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

  -- Simple "logo"
  centerText(2, "SimpleDesktop OS", colors.white, DESKTOP_BG)
  centerText(3, "Advanced Computer", colors.yellow, DESKTOP_BG)

  -- Draw icons in a grid
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

local function drawTaskbar()
  term.setBackgroundColor(TASKBAR_BG)
  term.setTextColor(TASKBAR_FG)
  term.setCursorPos(1, h)
  term.clearLine()

  -- "Start" button
  term.setCursorPos(2, h)
  term.write("[Start]")

  -- Clock on right
  local timeStr = textutils.formatTime(os.time(), true)
  local clockText = " " .. timeStr .. " "
  local cx = w - #clockText + 1
  term.setCursorPos(cx, h)
  term.write(clockText)
end

local function redrawAll()
  drawDesktop()
  drawTaskbar()
  -- Draw windows in order
  for _, win in ipairs(windows) do
    win.draw(win)
  end
end

-- WINDOW MANAGER -----------------------------------------

local function bringToFront(win)
  -- Remove and reinsert at end
  for i, wv in ipairs(windows) do
    if wv.id == win.id then
      table.remove(windows, i)
      break
    end
  end
  table.insert(windows, win)
end

local function findWindowAt(x, y)
  -- Topmost first: iterate backwards
  for i = #windows, 1, -1 do
    local win = windows[i]
    if x >= win.x and x <= win.x + win.w - 1 and
       y >= win.y and y <= win.y + win.h - 1 then
      return win
    end
  end
  return nil
end

local function drawWindow(win)
  -- Frame
  local x, y, ww, hh = win.x, win.y, win.w, win.h

  -- Title bar
  term.setBackgroundColor(TITLEBAR_BG)
  term.setTextColor(TITLEBAR_FG)
  for iy = y, y do
    term.setCursorPos(x, iy)
    term.write(string.rep(" ", ww))
  end

  -- Title text
  term.setCursorPos(x + 1, y)
  term.write(win.title)

  -- Close button [X]
  term.setCursorPos(x + ww - 3, y)
  term.write("[X]")

  -- Body
  term.setBackgroundColor(WINDOW_BG)
  term.setTextColor(colors.white)
  for iy = y + 1, y + hh - 1 do
    term.setCursorPos(x, iy)
    term.write(string.rep(" ", ww))
  end

  -- Let app draw inside
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
  redrawAll()
end

-- APPS ---------------------------------------------------

-- Shell app: just runs the built-in shell in a sub-window-like environment
local function launchShell()
  local win = {
    id = nextWinId,
    x = 5, y = 4,
    w = math.floor(w * 0.7),
    h = math.floor(h * 0.6),
    title = "Shell",
  }
  nextWinId = nextWinId + 1

  -- Create a window object for the shell
  local native = term.current()
  local shellWin = window.create(native, win.x + 1, win.y + 1, win.w - 2, win.h - 2, true)

  win.appDraw = function(self)
    -- shell window is already drawn by shell; nothing here
  end

  win.handle = function(self, event, p1, p2, p3)
    -- No special mouse handling inside; shell handles keyboard
  end

  win.draw = drawWindow

  table.insert(windows, win)
  bringToFront(win)
  redrawAll()

  -- Run shell in parallel
  local oldTerm = term.redirect(shellWin)
  shell.run()
  term.redirect(oldTerm)
  closeWindow(win)
end

-- Simple file browser: lists files in root and lets you open text files read-only
local function launchFiles()
  local win = {
    id = nextWinId,
    x = 8, y = 3,
    w = math.floor(w * 0.6),
    h = math.floor(h * 0.6),
    title = "File Browser",
  }
  nextWinId = nextWinId + 1

  win.scroll = 0
  win.files = fs.list("/")
  win.selected = 1

  win.appDraw = function(self)
    local innerX = self.x + 1
    local innerY = self.y + 1
    local innerW = self.w - 2
    local innerH = self.h - 2

    term.setBackgroundColor(WINDOW_BG)
    term.setTextColor(colors.white)

    for i = 1, innerH do
      local idx = i + self.scroll
      term.setCursorPos(innerX, innerY + i - 1)
      term.write(string.rep(" ", innerW))
      local name = self.files[idx]
      if name then
        if idx == self.selected then
          term.setBackgroundColor(colors.white)
          term.setTextColor(colors.black)
        else
          term.setBackgroundColor(WINDOW_BG)
          term.setTextColor(colors.white)
        end
        term.setCursorPos(innerX, innerY + i - 1)
        term.write(name:sub(1, innerW))
      end
    end
  end

  win.handle = function(self, event, p1, p2, p3)
    if event == "key" then
      if p1 == keys.up then
        if self.selected > 1 then
          self.selected = self.selected - 1
        end
      elseif p1 == keys.down then
        if self.selected < #self.files then
          self.selected = self.selected + 1
        end
      elseif p1 == keys.enter then
        local fname = self.files[self.selected]
        if fname then
          local path = "/" .. fname
          if fs.isDir(path) then
            -- enter directory
            self.files = fs.list(path)
            self.selected = 1
            self.scroll = 0
            self.title = "Files: " .. path
          else
            -- open viewer window
            local f = fs.open(path, "r")
            if f then
              local content = f.readAll()
              f.close()
              -- viewer window
              local vwin = {
                id = nextWinId,
                x = self.x + 2,
                y = self.y + 2,
                w = math.floor(self.w * 0.8),
                h = math.floor(self.h * 0.8),
                title = "View: " .. fname,
              }
              nextWinId = nextWinId + 1
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

              vwin.handle = function(sw, ev, a, b, c)
                if ev == "key" then
                  if a == keys.up then
                    if sw.scroll > 0 then sw.scroll = sw.scroll - 1 end
                  elseif a == keys.down then
                    sw.scroll = sw.scroll + 1
                  end
                end
              end

              vwin.draw = drawWindow
              table.insert(windows, vwin)
              bringToFront(vwin)
              redrawAll()
            end
          end
        end
      end
      redrawAll()
    end
  end

  win.draw = drawWindow
  table.insert(windows, win)
  bringToFront(win)
  redrawAll()
end

-- Simple text viewer demo
local function launchViewer()
  local win = {
    id = nextWinId,
    x = 6, y = 4,
    w = math.floor(w * 0.6),
    h = math.floor(h * 0.5),
    title = "Welcome",
  }
  nextWinId = nextWinId + 1

  win.text = "Welcome to SimpleDesktop OS!\n\n" ..
             "- Click icons on the desktop to open apps.\n" ..
             "- Drag windows by their title bar.\n" ..
             "- Click [X] to close a window.\n\n" ..
             "You can extend this OS by editing startup."

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

  win.handle = function(self, event, p1, p2, p3)
    if event == "key" then
      if p1 == keys.up then
        if self.scroll > 0 then self.scroll = self.scroll - 1 end
      elseif p1 == keys.down then
        self.scroll = self.scroll + 1
      end
      redrawAll()
    end
  end

  win.draw = drawWindow
  table.insert(windows, win)
  bringToFront(win)
  redrawAll()
end

local appLaunchers = {
  shell  = launchShell,
  files  = launchFiles,
  viewer = launchViewer,
}

-- INPUT HANDLING -----------------------------------------

local function handleDesktopClick(x, y)
  -- Taskbar: Start button
  if y == h and x >= 2 and x <= 8 then
    -- Simple start menu: open viewer as "About"
    launchViewer()
    return
  end

  -- Icons
  for _, icon in ipairs(desktopIcons) do
    if x >= icon.x and x <= icon.x + icon.w - 1 and
       y >= icon.y and y <= icon.y + icon.h - 1 then
      local launcher = appLaunchers[icon.app]
      if launcher then launcher() end
      return
    end
  end
end

local function handleMouseClick(button, x, y)
  -- Check windows first (topmost)
  local win = findWindowAt(x, y)
  if win then
    bringToFront(win)

    -- Title bar?
    if y == win.y then
      -- Close button?
      if x >= win.x + win.w - 3 and x <= win.x + win.w - 1 then
        closeWindow(win)
        return
      else
        -- Start dragging
        win.dragging = true
        win.dragOffX = x - win.x
        win.dragOffY = y - win.y
      end
    else
      -- Pass event to app
      if win.handle then
        win.handle(win, "mouse_click", button, x, y)
      end
    end
    redrawAll()
  else
    -- Desktop click
    handleDesktopClick(x, y)
  end
end

local function handleMouseDrag(button, x, y)
  for _, win in ipairs(windows) do
    if win.dragging then
      win.x = math.max(1, math.min(w - win.w + 1, x - win.dragOffX))
      win.y = math.max(1, math.min(h - win.h, y - win.dragOffY))
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
  -- Send to topmost window
  local top = windows[#windows]
  if top and top.handle then
    top.handle(top, "key", key)
  end
end

-- MAIN LOOP ----------------------------------------------

local function main()
  term.setCursorBlink(false)
  redrawAll()

  while true do
    drawTaskbar() -- refresh clock
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
