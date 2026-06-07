--[[
  NovaOS v0.1 - Full-stack OS for ComputerCraft Advanced Computer
  - Stage 0: Firmware splash
  - Stage 1: BIOS menu (boot, settings, info, power)
  - Stage 2: Bootloader with progress bar
  - Stage 3: Desktop OS with window manager, start menu, taskbar

  Future: cluster module (multi-computer compute nodes via rednet)
]]

-----------------------------
-- GLOBAL / ENV SETUP
-----------------------------

local term = term
local native = term.current()
local w, h = term.getSize()

local function resize()
  w, h = term.getSize()
end

-----------------------------
-- SIMPLE GRAPHICS LAYER
-----------------------------

local gfx = {}

function gfx.clear(bg)
  term.setBackgroundColor(bg or colors.black)
  term.setTextColor(colors.white)
  term.clear()
end

function gfx.fillRect(x, y, ww, hh, bg)
  term.setBackgroundColor(bg or colors.black)
  for iy = y, y + hh - 1 do
    if iy >= 1 and iy <= h then
      term.setCursorPos(x, iy)
      term.write(string.rep(" ", math.max(0, math.min(ww, w - x + 1))))
    end
  end
end

function gfx.frameRect(x, y, ww, hh, border)
  term.setBackgroundColor(border or colors.gray)
  for iy = y, y + hh - 1 do
    if iy >= 1 and iy <= h then
      term.setCursorPos(x, iy)
      term.write(string.rep(" ", math.max(0, math.min(ww, w - x + 1))))
    end
  end
end

function gfx.shadowRect(x, y, ww, hh)
  local sx = x + 1
  local sy = y + 1
  term.setBackgroundColor(colors.gray)
  for iy = sy, sy + hh - 1 do
    if iy >= 1 and iy <= h then
      term.setCursorPos(sx, iy)
      term.write(string.rep(" ", math.max(0, math.min(ww, w - sx + 1))))
    end
  end
end

function gfx.text(x, y, text, fg, bg)
  if y < 1 or y > h then return end
  term.setCursorPos(x, y)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.write(text)
end

function gfx.centerText(y, text, fg, bg)
  local cx = math.floor((w - #text) / 2) + 1
  gfx.text(cx, y, text, fg, bg)
end

-----------------------------
-- CONFIG / SETTINGS
-----------------------------

local configPath = "/nova_config"
local config = {
  theme = {
    desktop_bg = colors.blue,
    taskbar_bg = colors.gray,
    taskbar_fg = colors.white,
    titlebar_bg = colors.lightGray,
    titlebar_fg = colors.black,
    window_bg = colors.black,
    active_border = colors.yellow,
    inactive_border = colors.gray,
  },
  boot_delay = 3,   -- seconds before auto-boot
}

local function loadConfig()
  if fs.exists(configPath) then
    local f = fs.open(configPath, "r")
    local ok, data = pcall(textutils.unserialize, f.readAll())
    f.close()
    if ok and type(data) == "table" then
      config = data
    end
  end
end

local function saveConfig()
  local f = fs.open(configPath, "w")
  f.write(textutils.serialize(config))
  f.close()
end

loadConfig()

-----------------------------
-- STAGE 0: FIRMWARE SPLASH
-----------------------------

local function firmwareSplash()
  resize()
  gfx.clear(colors.black)

  gfx.centerText(3, "Nova Firmware v0.1", colors.cyan)
  gfx.centerText(5, "Initializing system...", colors.white)

  gfx.fillRect(5, h - 3, w - 8, 1, colors.gray)
  for i = 0, w - 8 do
    gfx.fillRect(5, h - 3, i, 1, colors.green)
    os.sleep(0.02)
  end

  gfx.centerText(h - 1, "Press F2 for BIOS", colors.lightGray)
end

-----------------------------
-- STAGE 1: BIOS MENU
-----------------------------

local function biosMenu()
  resize()
  gfx.clear(colors.black)

  local menuItems = {
    "Boot NovaOS",
    "Settings",
    "System Info",
    "Shutdown",
    "Reboot",
  }

  local selected = 1

  local function drawMenu()
    gfx.clear(colors.black)
    gfx.centerText(2, "Nova BIOS v0.1", colors.cyan)
    gfx.centerText(3, "Advanced Computer", colors.lightGray)

    local mw, mh = 30, #menuItems + 4
    local mx = math.floor((w - mw) / 2) + 1
    local my = math.floor((h - mh) / 2)

    gfx.shadowRect(mx, my, mw, mh)
    gfx.frameRect(mx, my, mw, mh, colors.gray)
    gfx.fillRect(mx + 1, my + 1, mw - 2, mh - 2, colors.black)

    gfx.text(mx + 2, my + 1, "BIOS Menu", colors.white)

    for i, label in ipairs(menuItems) do
      local y = my + 2 + i
      local fg = (i == selected) and colors.black or colors.white
      local bg = (i == selected) and colors.white or colors.black
      gfx.text(mx + 3, y, label, fg, bg)
    end

    gfx.centerText(h - 1, "Use UP/DOWN, ENTER, ESC", colors.lightGray)
  end

  drawMenu()

  while true do
    local e, p1 = os.pullEvent()
    if e == "key" then
      if p1 == keys.up then
        if selected > 1 then selected = selected - 1 end
        drawMenu()
      elseif p1 == keys.down then
        if selected < #menuItems then selected = selected + 1 end
        drawMenu()
      elseif p1 == keys.enter then
        return menuItems[selected]
      elseif p1 == keys.escape then
        return "Boot NovaOS"
      end
    elseif e == "term_resize" then
      resize()
      drawMenu()
    end
  end
end

-----------------------------
-- BIOS: SETTINGS SCREEN
-----------------------------

local function biosSettings()
  resize()
  local options = {
    { name = "Desktop: Blue",  apply = function() config.theme.desktop_bg = colors.blue end },
    { name = "Desktop: Green", apply = function() config.theme.desktop_bg = colors.green end },
    { name = "Desktop: Purple",apply = function() config.theme.desktop_bg = colors.purple end },
    { name = "Boot delay: 1s", apply = function() config.boot_delay = 1 end },
    { name = "Boot delay: 3s", apply = function() config.boot_delay = 3 end },
    { name = "Boot delay: 5s", apply = function() config.boot_delay = 5 end },
    { name = "Back",           apply = function() end },
  }

  local selected = 1

  local function draw()
    gfx.clear(colors.black)
    gfx.centerText(2, "BIOS Settings", colors.cyan)

    local mw, mh = 32, #options + 4
    local mx = math.floor((w - mw) / 2) + 1
    local my = math.floor((h - mh) / 2)

    gfx.shadowRect(mx, my, mw, mh)
    gfx.frameRect(mx, my, mw, mh, colors.gray)
    gfx.fillRect(mx + 1, my + 1, mw - 2, mh - 2, colors.black)

    for i, opt in ipairs(options) do
      local y = my + 1 + i
      local fg = (i == selected) and colors.black or colors.white
      local bg = (i == selected) and colors.white or colors.black
      gfx.text(mx + 2, y, opt.name, fg, bg)
    end

    gfx.centerText(h - 1, "UP/DOWN, ENTER, ESC", colors.lightGray)
  end

  draw()

  while true do
    local e, p1 = os.pullEvent()
    if e == "key" then
      if p1 == keys.up then
        if selected > 1 then selected = selected - 1 end
        draw()
      elseif p1 == keys.down then
        if selected < #options then selected = selected + 1 end
        draw()
      elseif p1 == keys.enter then
        options[selected].apply()
        saveConfig()
        if options[selected].name == "Back" then
          return
        else
          draw()
        end
      elseif p1 == keys.escape then
        return
      end
    elseif e == "term_resize" then
      resize()
      draw()
    end
  end
end

-----------------------------
-- BIOS: SYSTEM INFO
-----------------------------

local function biosSystemInfo()
  resize()
  gfx.clear(colors.black)
  gfx.centerText(2, "System Information", colors.cyan)

  local info = {
    "Computer ID: " .. os.getComputerID(),
    "Label: " .. (os.getComputerLabel() or "<none>"),
    "Lua version: " .. _VERSION,
    "NovaOS version: 0.1",
    "Cluster: disabled (future)",
  }

  for i, line in ipairs(info) do
    gfx.centerText(4 + i, line, colors.white)
  end

  gfx.centerText(h - 1, "Press any key to return", colors.lightGray)
  os.pullEvent("key")
end

-----------------------------
-- STAGE 2: BOOTLOADER
-----------------------------

local function bootloader()
  resize()
  gfx.clear(colors.black)
  gfx.centerText(3, "Nova Bootloader", colors.cyan)
  gfx.centerText(5, "Loading NovaOS...", colors.white)

  local barW = w - 10
  local bx = 6
  local by = h - 4
  gfx.fillRect(bx, by, barW, 1, colors.gray)

  local steps = 20
  for i = 1, steps do
    local progress = math.floor(barW * (i / steps))
    gfx.fillRect(bx, by, progress, 1, colors.green)
    os.sleep(0.05)
  end

  gfx.centerText(h - 2, "Boot complete.", colors.lightGray)
  os.sleep(0.3)
end

-----------------------------
-- STAGE 3: DESKTOP OS
-----------------------------

local theme = config.theme

local windows = {}
local nextWinId = 1
local focusedWinId = nil

local desktopIcons = {
  { name = "Shell",   app = "shell" },
  { name = "Files",   app = "files" },
  { name = "Viewer",  app = "viewer" },
}

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
  focusedWinId = win.id
  return win
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

-----------------------------
-- DESKTOP / TASKBAR / START
-----------------------------

local startMenu = { visible = false }

local function drawDesktop()
  gfx.clear(theme.desktop_bg)
  gfx.centerText(2, "NovaOS Desktop", colors.white, theme.desktop_bg)
  gfx.centerText(3, "Advanced Computer", colors.yellow, theme.desktop_bg)

  local cols = 4
  local iconW = math.floor(w / cols)
  for i, icon in ipairs(desktopIcons) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local ix = col * iconW + 2
    local iy = 5 + row * 3
    local label = "[" .. icon.name .. "]"
    gfx.text(ix, iy, label, colors.white, theme.desktop_bg)
    icon.x = ix
    icon.y = iy
    icon.w = #label
    icon.h = 1
  end
end

local function drawWindow(win)
  if win.minimized then return end

  local x, y, ww, hh = win.x, win.y, win.w, win.h

  local borderColor = (focusedWinId == win.id) and theme.active_border or theme.inactive_border
  gfx.frameRect(x - 1, y - 1, ww + 2, hh + 2, borderColor)
  gfx.shadowRect(x, y, ww, hh)

  gfx.fillRect(x, y, ww, 1, theme.titlebar_bg)
  gfx.text(x + 1, y, (win.title or "Window"):sub(1, ww - 8), theme.titlebar_fg, theme.titlebar_bg)

  local btnX = x + ww - 9
  gfx.text(btnX, y, "[_][□][X]", theme.titlebar_fg, theme.titlebar_bg)

  gfx.fillRect(x, y + 1, ww, hh - 1, theme.window_bg)

  if win.appDraw then
    win.appDraw(win)
  end
end

local function drawTaskbar()
  gfx.fillRect(1, h, w, 1, theme.taskbar_bg)
  gfx.text(2, h, "[Start]", theme.taskbar_fg, theme.taskbar_bg)

  local xPos = 10
  for _, win in ipairs(windows) do
    local label = win.title or ("Win " .. win.id)
    if #label > 10 then label = label:sub(1, 10) end
    local text = "[" .. label .. "]"
    if xPos + #text < w - 10 then
      local fg = theme.taskbar_fg
      local bg = theme.taskbar_bg
      if focusedWinId == win.id and not win.minimized then
        fg = colors.black
        bg = colors.white
      end
      gfx.text(xPos, h, text, fg, bg)
      win.taskX = xPos
      win.taskW = #text
      xPos = xPos + #text + 1
    else
      win.taskX = nil
      win.taskW = nil
    end
  end

  local timeStr = textutils.formatTime(os.time(), true)
  local clockText = " " .. timeStr .. " "
  local cx = w - #clockText + 1
  gfx.text(cx, h, clockText, theme.taskbar_fg, theme.taskbar_bg)
end

local function drawStartMenu()
  local menuX, menuY = 2, h - 7
  if menuY < 2 then menuY = 2 end
  local menuItems = {
    "Shell",
    "File Browser",
    "Viewer",
    "Settings",
    "Shutdown",
    "Reboot",
  }
  local menuW, menuH = 18, #menuItems + 2

  gfx.shadowRect(menuX, menuY, menuW, menuH)
  gfx.frameRect(menuX, menuY, menuW, menuH, colors.gray)
  gfx.fillRect(menuX + 1, menuY + 1, menuW - 2, menuH - 2, colors.black)

  for i, label in ipairs(menuItems) do
    gfx.text(menuX + 2, menuY + i, label, colors.white, colors.black)
  end

  startMenu.items = menuItems
  startMenu.x = menuX
  startMenu.y = menuY
  startMenu.w = menuW
  startMenu.h = menuH
  startMenu.visible = true
end

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

-----------------------------
-- APPS
-----------------------------

local function launchShell()
  local win = newWindow("Shell", 5, 4, math.floor(w * 0.7), math.floor(h * 0.6))
  local shellWin = window.create(native, win.x + 1, win.y + 1, win.w - 2, win.h - 2, true)

  win.appDraw = function() end
  win.handle = function() end

  redrawAll()
  local old = term.redirect(shellWin)
  shell.run()
  term.redirect(old)
  closeWindow(win)
  redrawAll()
end

local function launchFiles()
  local win = newWindow("File Browser", 8, 3, math.floor(w * 0.6), math.floor(h * 0.6))
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
    local ix = self.x + 1
    local iy = self.y + 1
    local iw = self.w - 2
    local ih = self.h - 2

    gfx.text(ix, iy, ("Path: %s"):format(self.cwd:sub(1, iw)), colors.white, theme.window_bg)
    for i = 2, ih do
      local idx = i - 1 + self.scroll
      local y = iy + i - 1
      gfx.fillRect(ix, y, iw, 1, theme.window_bg)
      local name = self.files[idx]
      if name then
        local full = fs.combine(self.cwd, name)
        local prefix = fs.isDir(full) and "[D] " or "    "
        local fg = colors.white
        local bg = theme.window_bg
        if idx == self.selected then
          fg = colors.black
          bg = colors.white
        end
        gfx.text(ix, y, (prefix .. name):sub(1, iw), fg, bg)
      end
    end
  end

  win.handle = function(self, event, p1)
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
              local vwin = newWindow("View: " .. fname, self.x + 2, self.y + 2,
                math.floor(self.w * 0.8), math.floor(self.h * 0.8))
              vwin.text = content
              vwin.scroll = 0
              vwin.appDraw = function(sw)
                local ix = sw.x + 1
                local iy = sw.y + 1
                local iw = sw.w - 2
                local ih = sw.h - 2
                local lines = {}
                for line in (sw.text .. "\n"):gmatch("(.-)\n") do
                  table.insert(lines, line)
                end
                for i = 1, ih do
                  local idx = i + sw.scroll
                  local y = iy + i - 1
                  gfx.fillRect(ix, y, iw, 1, theme.window_bg)
                  local line = lines[idx]
                  if line then
                    gfx.text(ix, y, line:sub(1, iw), colors.white, theme.window_bg)
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

local function launchViewer()
  local win = newWindow("Welcome", 6, 4, math.floor(w * 0.6), math.floor(h * 0.5))
  win.text =
    "Welcome to NovaOS!\n\n" ..
    "- BIOS: F2 during splash.\n" ..
    "- Desktop: icons + Start menu.\n" ..
    "- Windows: drag, minimize, maximize, close.\n" ..
    "- Taskbar: click window buttons.\n\n" ..
    "Future: cluster module for multi-computer power."

  win.scroll = 0

  win.appDraw = function(self)
    local ix = self.x + 1
    local iy = self.y + 1
    local iw = self.w - 2
    local ih = self.h - 2
    local lines = {}
    for line in (self.text .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, line)
    end
    for i = 1, ih do
      local idx = i + self.scroll
      local y = iy + i - 1
      gfx.fillRect(ix, y, iw, 1, theme.window_bg)
      local line = lines[idx]
      if line then
        gfx.text(ix, y, line:sub(1, iw), colors.white, theme.window_bg)
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

-----------------------------
-- INPUT HANDLING
-----------------------------

local function toggleStartMenu()
  startMenu.visible = not startMenu.visible
  redrawAll()
end

local function handleStartMenuClick(x, y)
  if not startMenu.visible then return end
  if x < startMenu.x or x > startMenu.x + startMenu.w - 1 or
     y < startMenu.y or y > startMenu.y + startMenu.h - 1 then
    startMenu.visible = false
    redrawAll()
    return
  end

  local index = y - startMenu.y
  local item = startMenu.items[index]
  startMenu.visible = false

  if item == "Shell" then
    launchShell()
  elseif item == "File Browser" then
    launchFiles()
  elseif item == "Viewer" then
    launchViewer()
  elseif item == "Settings" then
    biosSettings()
    theme = config.theme
    redrawAll()
  elseif item == "Shutdown" then
    gfx.clear(colors.black)
    gfx.centerText(math.floor(h / 2), "System halted.", colors.red)
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

  local function findWindowAt(px, py)
    for i = #windows, 1, -1 do
      local win = windows[i]
      if not win.minimized then
        if px >= win.x and px <= win.x + win.w - 1 and
           py >= win.y and py <= win.y + win.h - 1 then
          return win
        end
      end
    end
    return nil
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

-----------------------------
-- MAIN ENTRY
-----------------------------

local function runDesktop()
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
      resize()
      redrawAll()
    end
  end
end

local function main()
  firmwareSplash()

  local bootDeadline = os.clock() + config.boot_delay
  local biosRequested = false

  while os.clock() < bootDeadline do
    local e, k = os.pullEventRaw()
    if e == "key" and k == keys.f2 then
      biosRequested = true
      break
    end
  end

  local action = "Boot NovaOS"
  if biosRequested then
    action = biosMenu()
  end

  if action == "Boot NovaOS" then
    bootloader()
    runDesktop()
  elseif action == "Settings" then
    biosSettings()
    bootloader()
    runDesktop()
  elseif action == "System Info" then
    biosSystemInfo()
    bootloader()
    runDesktop()
  elseif action == "Shutdown" then
    gfx.clear(colors.black)
    gfx.centerText(math.floor(h / 2), "System halted.", colors.red)
    error("System halted", 0)
  elseif action == "Reboot" then
    os.reboot()
  end
end

main()
