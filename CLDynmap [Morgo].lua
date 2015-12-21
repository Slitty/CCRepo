function writeColor(mon, text, fgColor, bgColor)
  if (mon.isColor()) then
    if fgColor then
      mon.setTextColor(fgColor)
    end
    if bgColor then
      mon.setBackgroundColor(bgColor)
    end
  end
  mon.write(text)
  if (mon.isColor()) then
    mon.setTextColor(colors.black)
    mon.setBackgroundColor(colors.white)
  end
end

-- Return a wrapped device given a search term.
function getDevice(search)
  local plist = peripheral.getNames()
  local i, name
  for i, name in pairs(plist) do
    if string.find(peripheral.getType(name), search) then
      return peripheral.wrap(name)
    end
  end
  if search == monitor then
    return term
  else
    return nil
  end
end

function readSettings(user)
  local filename, _ = user:gsub(" ", "_")
  filename = filename..".settings"
  local settingsFile = fs.combine(settingsDirectory, filename)
  local fh = fs.open(settingsFile, "r")
  if fh then
    return textutils.unserialize(fh.readAll())
  end
  return nil
end

function writeSettings(user, settings)
  local filename, _ = user:gsub(" ", "_")
  filename = filename..".settings"
  local settingsFile = fs.combine(settingsDirectory, filename)
  local fh = fs.open(settingsFile, "w")
  if fh then
    fh.write(textutils.serialize(settings))
    fh.close()
  end
end

-- This function extracts information from the livemap
-- at the current timestamp and stores it in global 
-- tables.
function extractLiveMap()
  local t = {}
  local name, armor, account, health, world, x, y, z
  local a = 0
  local b = 0

  fh = http.get("http://tekkit.craftersland.net:25800/up/world/world/" .. ts)
  if not fh then
    return
  end

  s = fh.readAll()
  fh.close()
  _,_,ts = string.find(s, "{\"timestamp\":(%d+),")

  -- Could not find the timestamp so the page must have not returned completely.
  if not ts then
    return
  end

  -- Extract out the player information
  players = {}
  playerCount = 0
  local a = 0
  local b = 0
  local name, armor, account, health, z, y, world, x
  while (true) do
    a, b, name, armor, account, health, z, y, world, x = string.find(s, "\"sort\":0,\"name\":\"([^\"]+)\",\"armor\":(%d+),\"account\":\"([^\"]+)\",\"health\":(%d+),\"type\":\"player\",\"z\":([-0-9.]+),\"y\":([-0-9.]+),\"world\":\"([^\"]+)\",\"x\":([-0-9.]+)", b + 1)
    if (a == nil) then
      break
    end
    if world == "DIM-1" then
      world = "nether"
    elseif world == "DIM-28" then
      world = "moon"
    elseif world == "DIM-29" then
      world = "mars"
    elseif world == "-some-other-bogus-world-" then
      world = "camouflage"
    elseif world:sub(1, 8) == "DIM_MYST" then
      world = "myst_"..world:sub(9)
    elseif world:sub(1, 16) == "DIM_SPACESTATION" then
      world = "spacestation_"..world:sub(17)
    end
    worlds[world] = 1
    players[account] = {}
    players[account].armor = tonumber(armor)
    players[account].name = name
    players[account].health = tonumber(health)
    players[account].world = world
    local yn = tonumber(y)
    if yn > 999 then
      yn = 999
    end
    players[account].loc = vector.new(tonumber(x), yn, tonumber(z))
    playerCount = playerCount + 1
  end
end

function getDir(s, t)
  local dir = math.atan2(s.z - t.z, s.x - t.x)
  if dir > 2.75 or dir < -2.74 then
    return "W"
  elseif dir > -2.75 and dir < -1.95 then
    return "NW"
  elseif dir > -1.96 and dir < -1.17 then
    return "N"
  elseif dir > -1.18 and dir < -0.38 then
    return "NE"
  elseif dir > -0.39 and dir < 0.40 then
    return "E"
  elseif dir > 0.39 and dir < 1.19 then
    return "SE"
  elseif dir > 1.18 and dir < 1.96 then
    return "S"
  elseif dir > 1.96 and dir < 2.76 then
    return "SW"
  end
end

function displayPlayersOnMon()
  local p = {}
  local i = 1
  local st = {}
  local x = 1
  local y = 3
  for key in pairs(players) do
    if players[key].world == "world" or players[key].world == "camouflage" then
      p[key] = players[key]
      local offset = defaultSettings.hereDefault - p[key].loc
      if p[key].world == "camouflage" then
        p[key].dist = 999999
      else
        p[key].dist = math.floor(math.sqrt(offset.x * offset.x + offset.z * offset.z))
        p[key].dir = getDir(p[key].loc, defaultSettings.hereDefault)
      end
      st[#st+1] = key
    end
  end
  table.sort(st, function(a, b) return p[a].dist < p[b].dist end)
  mon.setCursorPos(x, y)
  writeColor(mon, string.rep(" ", monW), colors.white, colors.grey)
  mon.setCursorPos(x, y)
  writeColor(mon, "--== Overworld ==--", colors.white, colors.grey)
  for k = 1, #st do
    account = st[k]
    mon.setCursorPos(x, y + k)
    local pc = colors.cyan
    if account == highlight then
      pc = colors.yellow
    end
    writeColor(mon, rightPad(account, 12), pc)
    mon.setCursorPos(x + 13, y + k)
    if p[account].world == "camouflage" then
      writeColor(mon, "Camouflage", colors.red)
    else
      text = string.format("%s %s %s %s (%s)",
          leftPad(math.floor(p[account].loc.x), 5),
          leftPad(math.floor(p[account].loc.z), 5),
          leftPad(math.floor(p[account].loc.y), 3),
          leftPad(p[account].dist, 5),
          p[account].dir)
      mon.write(text)
    end
  end
  if monW < 65 then
    return
  end
  x = 45
  local mapY = monH - 3 - y
  local mapX = monW - x
  local map = {}
  map[1] = "+"..string.rep("-", mapX - 2).."+"
  for ty = 2, mapY - 1 do
    map[ty] = "|"..string.rep(" ", mapX - 2).."|"
  end
  map[mapY] = "+"..string.rep("-", mapX - 2).."+"
  local px = math.floor((defaultSettings.hereSpawn.x - xLim[1]) / xLim[2] * mapX)
  local py = math.floor((defaultSettings.hereSpawn.z - yLim[1]) / yLim[2] * mapY)
  map[py] = string.sub(map[py], 1, px - 1).."@"..string.sub(map[py], px + 1)
  local px = math.floor((defaultSettings.hereDefault.x - xLim[1]) / xLim[2] * mapX)
  local py = math.floor((defaultSettings.hereDefault.z - yLim[1]) / yLim[2] * mapY)
  map[py] = string.sub(map[py], 1, px - 1).."#"..string.sub(map[py], px + 1)
  mon.setCursorPos(x, y)
  if mapMode then
    writeColor(mon, "--== World Map ==--", colors.white, colors.grey)
    y = y + 1
    local a = 65
    for k = 1, #st do
      account = st[k]
      if p[account].world ~= "camouflage" then
        local px = math.floor((p[account].loc.x - xLim[1]) / xLim[2] * mapX)
        local py = math.floor((p[account].loc.z - yLim[1]) / yLim[2] * mapY)
        local c = string.sub(map[py], px, px)
        if c == " " or c == "|" or c == "+" or c == "-" then
          c = string.char(a)
          map[py] = string.sub(map[py], 1, px - 1)..c..string.sub(map[py], px + 1)
          a = a + 1
        end
        mon.setCursorPos(x - 3, y)
        mon.write(c)
        y = y + 1
      end
    end
    for ty = 1, mapY do
      mon.setCursorPos(x, ty + 3)
      mon.write(map[ty])
    end
  else
    writeColor(mon, "--== Other Dimensions ==--", colors.white, colors.grey)
    y = y + 1
    for key in pairs(players) do
      if players[key].world ~= "world" and players[key].world ~= "camouflage" then
        mon.setCursorPos(x, y)
        local pc = colors.cyan
        if key == highlight then
          pc = colors.yellow
        end
        writeColor(mon, rightPad(key, 12), pc)
        mon.setCursorPos(x + 13, y)
        text = string.format("%s %s %s %s",
            leftPad(math.floor(players[key].loc.x), 5),
            leftPad(math.floor(players[key].loc.z), 5),
            leftPad(math.floor(players[key].loc.y), 3),
            players[key].world)
        mon.write(text)
        y = y + 1
      end
    end
  end
end

function displayPlayersOnUsersGlass(user)
  local settings = users[user].settings
  local surface = glass.getUserSurface(user)
  if not surface then
    return
  end
  local x = settings.trackLoc.x
  local y = settings.trackLoc.y
  local p = {}
  local st = {}
  for key in pairs(players) do
    if players[key].world == settings.worldFilter or players[key].world == "camouflage" then
      p[key] = players[key]
      local offset = users[user].here - p[key].loc
      if p[key].world == "camouflage" then
        p[key].dist = 999999
      else
        p[key].dist = math.floor(math.sqrt(offset.x * offset.x + offset.z * offset.z))
      end
      p[key].dir = getDir(p[key].loc, users[user].here)
      st[#st+1] = key
    end
  end
  surface.addBox(x, y, 226, #st * 10 + 4, 0x0000FF, 0.3)
  table.sort(st, function(a, b) return p[a].dist < p[b].dist end)
  x = x + 2
  y = y + 2
  for k = 1, #st do
    account = st[k]
    local pc = 0x80FFFF
    if account == highlight then
      pc = 0xFFFF00
    end
    surface.addText(x, y + (10 * (k-1)), account:sub(1, 12), pc)
    if p[account].world == "camouflage" then
      surface.addText(x + 75, y + (10 * (k-1)), "Camouflage", 0xFF0000)
    else
      surface.addText(x + 75, y + (10 * (k-1)), string.format("%d", players[account].loc.x), 0xFFFFFF)
      surface.addText(x + 110, y + (10 * (k-1)), string.format("%d", players[account].loc.z), 0xFFFFFF)
      surface.addText(x + 145, y + (10 * (k-1)), string.format("%d", players[account].loc.y), 0xFFFFFF)
      surface.addText(x + 165, y + (10 * (k-1)), string.format("%d", players[account].dist), 0xFFFFFF)
    surface.addText(x + 200, y + (10 * (k-1)), string.format("(%s)", players[account].dir), 0xFFFFFF)
    end
  end
end

function rightPad(v, n)
  return string.sub(""..v..string.rep(" ", n), 1, n)
end

function leftPad(v, n)
  nv = ""..v
  lv = string.len(nv)
  if (lv > n) then
    return string.sub(nv, n - lv + 1, lv)
  else
    return string.rep(" ", n - lv )..nv
  end
end

function refresh()
  extractLiveMap()
  updateMonitor()
  if glass then
    updateGlass()
  end
end

function updateMonitor()
  mon.clear()
  mon.setCursorPos(1, 1)
  mon.write(string.format("Visible Players: %d", playerCount))
  s = textutils.formatTime(os.time(), false)
  mon.setCursorPos(monW - string.len(s), 1)
  mon.write(s)
  displayPlayersOnMon()
  local x = 1
  local y = monH - 2
  mon.setCursorPos(x, y)
  writeColor(mon, string.rep(" ", monW), colors.white, colors.grey)
  mon.setCursorPos(x, y + 1)
  writeColor(mon, string.rep(" ", monW), colors.white, colors.black)
  mon.setCursorPos(x, y + 2)
  writeColor(mon, string.rep(" ", monW), colors.white, colors.black)
  mon.setCursorPos(x, y)
  writeColor(mon, "--== Current Glass Users ==--", colors.white, colors.grey)
  y = y + 1
end

function updateGlass()
  for _, user in pairs(glass.getUsers()) do
    local surface = glass.getUserSurface(user)
    if surface then
      surface.clear()
      if users[user] then
        if users[user].track then
          displayPlayersOnUsersGlass(user)
        end
        if users[user].glassOutput then
          local x = users[user].settings.outputLoc.x
          local y = users[user].settings.outputLoc.y
          local l = users[user].settings.outputLoc.l
          surface.addBox(x, y, l * 5, 40, 0x000000, 0.3)
          surface.addText(x + 5, y + 5, users[user].glassOutput:sub(1, l - 1), 0xFFFFFF)
          surface.addText(x + 5, y + 15, users[user].glassOutput:sub(l, l * 2 - 1), 0xFFFFFF)
          surface.addText(x + 5, y + 25, users[user].glassOutput:sub(l * 2, l * 3 - 1), 0xFFFFFF)
        end
      else
        local settings = readSettings(user)
        if settings then
          users[user] = {}
          users[user].settings = settings
          users[user].glassOutput = "Welcome "..user
          users[user].here = defaultSettings.hereDefault
          users[user].track = true
        elseif defaultSettings.privUsers[user] then
          -- Allow priviledged users even if they don't have settings
          -- just give them the default.
          users[user] = {}
          users[user].settings = defaultSettings
          users[user].glassOutput = "Welcome "..user.." (priv)"
          users[user].here = defaultSettings.hereDefault
          users[user].track = true
        else
          surface.addBox(40, 40, 159, 20, 0x000000, 0.5)
          surface.addText(45, 45, "Not a valid user.", 0xFF0000)
        end
      end
    end
  end
end

function parseCommand(command, user)
  if not command or not user or not users[user] then
    return
  end
  if command:lower() == "clear" then
    users[user].glassOutput = nil
    return
  elseif command:lower() == "loc default" then
    users[user].here = users[user].settings.hereDefault
    users[user].glassOutput = "Location set to default."
    return
  elseif command:lower() == "loc spawn" then
    users[user].here = users[user].settings.hereSpawn
    users[user].glassOutput = "Location set to spawn."
    return
  elseif command:lower():sub(1, 4) == "loc " then
    local a, b, x, z, y = string.find(command:lower(), "loc[ ]+([-0-9.]+)[ ]+([-0-9.]+)[ ]+([-0-9.]+)")
    if a then
      users[user].here = vector.new(x, y, z)
      users[user].glassOutput = "Location set to x:"..x.." z:"..z.." y:"..y
      return
    end
    local a, b, x, z = string.find(command:lower(), "loc[ ]+([-0-9.]+)[ ]+([-0-9.]+)")
    if a then
      users[user].here = vector.new(x, 65, z)
      users[user].glassOutput = "Location set to x:"..x.." z:"..z
      return
    end
    users[user].glassOutput = "Usage: loc {default|spawn|x z y} to set tracking location."
    return
  elseif command:lower() == "track" then
    users[user].track = not users[user].track
    if users[user].track then
      users[user].glassOutput = "Tracking turned on."
    else
      users[user].glassOutput = "Tracking turned off."
    end
    return
  elseif command:lower():sub(1, 6) == "track " then
    local a, b, x, y = string.find(command:lower(), "track[ ]+(%d+)[ ]+(%d+)")
    if a then
      users[user].settings.trackLoc.x = x
      users[user].settings.trackLoc.y = y
      users[user].glassOutput = "Track window location set to x:"..x.." y:"..y
      track = true
      writeSettings(user, users[user].settings)
      return
    end
    users[user].glassOutput = "Usage: track <x y> Toggle track and set window location."
    return
  elseif command:lower():sub(1, 7) == "output " then
    local a, b, x, y, l = string.find(command:lower(), "output[ ]+(%d+)[ ]+(%d+)[ ]+(%d+)")
    if a then
      users[user].settings.outputLoc.x = x
      users[user].settings.outputLoc.y = y
      users[user].settings.outputLoc.l = l
      users[user].glassOutput = "Track window location set to x:"..x.." y:"..y
      writeSettings(user, users[user].settings)
      return
    end
    users[user].glassOutput = "Usage: output <x y length> Set output window location and length."
    return
  elseif command:lower():sub(1, 5) == "count" then
    if not me then
      users[user].glassOutput = "No ME interface found."
      return
    end
    local a, b, id, dmg = string.find(command:lower(), "count[ ]+(%d+):(%d+)")
    if a then
      local n = me.countOfItemType(id, dmg)
      users[user].glassOutput = "Count: "..n
      return
    end
    users[user].glassOutput = "Usage: count id:dmg"
    return
  elseif command:lower():sub(1, 5) == "craft" then
    if not me then
      users[user].glassOutput = "No ME interface found."
      return
    end
    local a, b, id, dmg, qty = string.find(command:lower(), "craft[ ]+(%d+):(%d+)[ ]+(%d+)")
    if a then
      local n = me.requestCrafting({id=tonumber(id), dmg=tonumber(dmg), qty=tonumber(qty)})
      users[user].glassOutput = "Crafting requested."
      return
    end
    users[user].glassOutput = "Usage: craft id:dmg quantity"
    return
  elseif command:lower():sub(1, 7) == "deliver" then
    if not me then
      users[user].glassOutput = "No ME interface found."
      return
    end
    local a, b, id, dmg, qty = string.find(command:lower(), "deliver[ ]+(%d+):(%d+)[ ]+(%d+)")
    if a then
      local n = me.extractItem({id=tonumber(id), dmg=tonumber(dmg), qty=tonumber(qty)}, "up")
      users[user].glassOutput = "Delivered "..n.." items."
      return
    end
    users[user].glassOutput = "Usage: deliver id:dmg quantity"
    return
  elseif command:lower() == "worlds" then
    users[user].glassOutput = "Available worlds:"
    for k, v in pairs(worlds) do
      if k ~= "camouflage" then
        users[user].glassOutput = users[user].glassOutput.." "..k
      end
    end
  elseif command:lower():sub(1, 9) == "highlight" then
    local a, b, u = string.find(command, "highlight[ ]+([^ ]+)")
    if a then
      if u == "clear" then
        highlight = ""
      else
        highlight = u
        users[user].glassOutput = "Now highlighting "..highlight
      end
    end
    return
  elseif command:lower():sub(1, 5) == "world" then
    users[user].settings.worldFilter = "world"
    local a, b, w = string.find(command:lower(), "world[ ]+([^ ]+)")
    if a then
      users[user].settings.worldFilter = w
    end
    users[user].glassOutput = "World filter set to: "..users[user].settings.worldFilter
    writeSettings(user, users[user].settings)
    return
  elseif command:lower() == "help" then
    users[user].glassOutput = "Commands available: track, loc, output, clear, count, craft, deliver, world, worlds"
    if defaultSettings.privUsers[user] then
      users[user].glassOutput = users[user].glassOutput..", register, unregister"
    end
    return
  end
  if defaultSettings.privUsers[user] then
    if command:sub(1, 8) == "register" then
      local a, b, u = string.find(command, "register[ ]+([^ ]+)")
      if a then
        local filename, _ = u:gsub(" ", "_")
        filename = filename..".settings"
        local settingsFile = fs.combine(settingsDirectory, filename)
        local defaultFile = fs.combine(settingsDirectory, "default.settings")
        fs.copy(defaultFile, settingsFile)
        users[user].glassOutput = "Registered glass user "..u
      else
        users[user].glassOutput = "Usage: register <username>"
      end
      return
    elseif command:sub(1, 10) == "unregister" then
      local a, b, u = string.find(command, "unregister[ ]+([^ ]+)")
      if a then
        local filename, _ = u:gsub(" ", "_")
        filename = filename..".settings"
        local settingsFile = fs.combine(settingsDirectory, filename)
        if fs.exists(settingsFile) then
          fs.delete(settingsFile)
          users[u] = nil
          users[user].glassOutput = "Unregistered glass user "..u
        else
          users[user].glassOutput = "User "..u.." was not registered."
        end
      else
        users[user].glassOutput = "Usage: register <username>"
      end
      return
    end
  end
end

function main()
  refreshTimer = os.startTimer(2.0)
  refresh()
  while not endProgram do
    event, p1, p2, p3, p4 = os.pullEvent()
    if event == "timer" then
      refreshTimer = os.startTimer(2.0)
      refresh()
    elseif event == "monitor_touch" then
      mapMode = not mapMode
      refreshTimer = os.startTimer(2.0)
      refresh()
    elseif event == "chat_command" then
      parseCommand(p1, p2)
      -- The command may have taken more than a refresh tick so make sure
      -- the timer is restarted.
      refreshTimer = os.startTimer(2.0)
      refresh()
    elseif event == "key" then
      if p1 == keys.q then
        endProgram = true
        sleep(0)
      end
    end
  end
end

-- Initialization of global variables
mon = getDevice("monitor")
glass = getDevice("glassesbridge")
me = getDevice("me_interface")

endProgram = false
mapMode = true

xLim = {-4530, 10765}
yLim = {-4330, 10605}

-- Initialize the monitors
mon.setTextScale(0.5)
mon.setBackgroundColor(colors.white)
mon.clear()
monW, monH = mon.getSize()

if glass then
  glass.clear()
end

-- Get the current timestamp from the livemap server 
-- because computercraft doesn't have access to the
-- real time.
fh = http.get("http://tekkit.craftersland.net:25800/up/world/world/111")
s = fh.readAll()
fh.close()
_,_,ts = string.find(s, "{\"timestamp\":(%d+).")

-- Players and player sort table.
playerCount = 0
players = {}
st = {}
worlds = {}
users = {}
highlight = ""

-- Default settings.
if fs.isDir("/disk/settings") then
  settingsDirectory = "/disk/settings"
elseif fs.isDir("/settings") then
  settingsDirectory = "/settings"
else
  print("Could not locate settings directory!")
end
print("TrackerGlass initialized.")
print("Using settings directory "..settingsDirectory)
defaultSettings = readSettings("default")
if not defaultSettings then
  defaultSettings = {}
  defaultSettings.worldFilter = "world"
  defaultSettings.hereDefault = vector.new(-314, 100, -2538)
  defaultSettings.hereSpawn = vector.new(910, 65, 1035)
  defaultSettings.trackLoc = {x=1, y=1}
  defaultSettings.outputLoc = {x=400, y=40, l=40}
  writeSettings("default", defaultSettings)
end

-- Main program.  This calls the main function and traps all errors.
-- Additionally it clears all of the displays so that it is obvious
-- when the program exits.
 
arg = { ... }
local ok, err = pcall(main)
if (not ok) then
  print(err)
end
-- Clear all the existing displays.
mon.setBackgroundColor(colors.white)
mon.clear()
if glass then
  glass.clear()
  for _, user in pairs(glass.getUsers()) do
    local surface = glass.getUserSurface(user)
    if surface then
      surface.clear()
    end
  end
end
