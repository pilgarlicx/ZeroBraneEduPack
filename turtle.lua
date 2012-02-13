-- Copyright (C) 2011-2012 Paul Kulchenko
-- A turtle graphics library

require("wx")

local inloop = wx.wxGetApp():IsMainLoopRunning()

local frame
local bitmap
local mdc = wx.wxMemoryDC()

local sounds
local bitmaps
local key
local click
local exit
local autoUpdate
local showTurtles

local function pick(...)
  local topick = {}
  for _,value in ipairs({...}) do
    topick[value] = true
  end
  for num,turtle in ipairs(turtles) do
    turtle.picked = topick[num] or false
  end
end

local function trtl(num)
  if num then return turtles[num] end

  local trtl = {
    picked = false,
    pendn = wx.wxPen(wx.wxBLACK_PEN),
    penup = wx.wxTRANSPARENT_PEN,
    down = true,
    angle = 0.0,
    x = 0.0,
    y = 0.0,
  }
  table.insert(turtles, trtl)
  pick(#turtles)
  return trtl
end

local function each(callback, ...)
  local r1, r2, r3 -- expect to return no more than three values
  for num,turtle in ipairs(turtles) do
    if turtle.picked then
      if callback then r1, r2, r3 = callback(turtle, ...) end
    end
  end
  return r1, r2, r3
end

local function round(value) return math.floor(value+0.5) end

local function showTurtle(turtle)
  local pen = wx.wxPen(wx.wxBLACK_PEN)
  local size = turtle.pendn:GetWidth()
  pen:SetWidth(size > 5 and 5 or size)
  pen:SetColour(turtle.pendn:GetColour())

  mdc:SelectObject(bitmap)
  mdc:SetPen(pen)

  local angle = turtle.angle
  local dist = 10
  local x1 = round(turtle.x + dist * math.cos(angle * math.pi/180))
  local y1 = round(turtle.y + dist * math.sin(angle * math.pi/180))
  local x2 = round(turtle.x + dist * math.cos((angle +120) * math.pi/180))
  local y2 = round(turtle.y + dist * math.sin((angle +120) * math.pi/180))
  local x3 = round(turtle.x + dist * math.cos((angle -120) * math.pi/180))
  local y3 = round(turtle.y + dist * math.sin((angle -120) * math.pi/180))

  mdc:DrawLine(x1, y1, x2, y2)
  mdc:DrawLine(x2, y2, x3, y3)
  mdc:DrawLine(x3, y3, x1, y1)

  mdc:SetPen(wx.wxNullPen)
  mdc:SelectObject(wx.wxNullBitmap)
end

local function updt(update)
  local curr = autoUpdate
  if update ~= nil then autoUpdate = update end

  local save
  if showTurtles then
    save = snap()
    each(showTurtle)
  end

  frame:Refresh()
  frame:Update()
  wx.wxGetApp():MainLoop()

  if showTurtles then undo(save) end

  return curr
end

local function reset()
  local size = frame:GetClientSize()
  local w,h = size:GetWidth(),size:GetHeight()
  bitmap = wx.wxBitmap(w,h)

  sounds = {}
  bitmaps = {}
  key = nil
  click = {}
  exit = true
  autoUpdate = true
  showTurtles = false

  turtles = {}
  trtl() -- add one turtle

  mdc:SetDeviceOrigin(w/2, h/2)
  mdc:SelectObject(bitmap)
  mdc:Clear()
  mdc:SetFont(wx.wxSWISS_FONT) -- thin TrueType font
  mdc:SelectObject(wx.wxNullBitmap)

  updt()
end

-- paint event handler for the frame that's called by wxEVT_PAINT
function OnPaint(event)
  -- must always create a wxPaintDC in a wxEVT_PAINT handler
  local dc = wx.wxPaintDC(frame)
  dc:DrawBitmap(bitmap, 0, 0, true)
  dc:delete() -- ALWAYS delete() any wxDCs created when done
end

local function open()
  -- if the window is open, then only reset it
  if frame then return reset() end
  frame = wx.wxFrame(
    wx.NULL, -- no parent for toplevel windows
    wx.wxID_ANY, -- don't need a wxWindow ID
    "Turtle Graph Window",
    wx.wxDefaultPosition,
    wx.wxSize(450, 450),
    wx.wxDEFAULT_FRAME_STYLE + wx.wxSTAY_ON_TOP
    - wx.wxRESIZE_BORDER - wx.wxMAXIMIZE_BOX)

  frame:Connect(wx.wxEVT_CLOSE_WINDOW,
    function(event)
      if inloop then event:Skip() frame = nil else os.exit() end
    end)

  -- connect the paint event handler function with the paint event
  frame:Connect(wx.wxEVT_PAINT, OnPaint)
  frame:Connect(wx.wxEVT_ERASE_BACKGROUND, function () end) -- do nothing

  frame:Connect(wx.wxEVT_KEY_DOWN, function (event) key = event:GetKeyCode() end)
  frame:Connect(wx.wxEVT_LEFT_DCLICK, function (event) click['l2'] = event:GetLogicalPosition(mdc) end)
  frame:Connect(wx.wxEVT_RIGHT_DCLICK, function (event) click['r2'] = event:GetLogicalPosition(mdc) end)
  frame:Connect(wx.wxEVT_LEFT_UP, function (event) click['lu'] = event:GetLogicalPosition(mdc) end)
  frame:Connect(wx.wxEVT_RIGHT_UP, function (event) click['ru'] = event:GetLogicalPosition(mdc) end)
  frame:Connect(wx.wxEVT_LEFT_DOWN, function (event) click['ld'] = event:GetLogicalPosition(mdc) end)
  frame:Connect(wx.wxEVT_RIGHT_DOWN, function (event) click['rd'] = event:GetLogicalPosition(mdc) end)

  frame:Connect(wx.wxEVT_IDLE,
    function ()
      if exit and not inloop then wx.wxGetApp():ExitMainLoop() end
    end)

  frame:Show(true)

  reset()
end

local function line(x1, y1, x2, y2)
  mdc:SelectObject(bitmap)

  each(function(turtle)
    mdc:SetPen(turtle.down and turtle.pendn or turtle.penup)
    mdc:DrawLine(x1, y1, x2, y2)
    mdc:SetPen(wx.wxNullPen)
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function rect(x, y, w, h, r)
  mdc:SelectObject(bitmap)

  each(function(turtle)
    mdc:SetPen(turtle.down and turtle.pendn or turtle.penup)
    if r then mdc:DrawRoundedRectangle(x, y, w, h, r)
    else mdc:DrawRectangle(x, y, w, h) end
    mdc:SetPen(wx.wxNullPen)
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function oval(x, y, w, h, color, start, finish)
  h = h or w
  start = start or 0
  finish = finish or 0

  mdc:SelectObject(bitmap)

  each(function(turtle)
    mdc:SetPen(turtle.down and turtle.pendn or turtle.penup)
    mdc:SetBrush(
      color and wx.wxBrush(color, wx.wxSOLID) or wx.wxTRANSPARENT_BRUSH)
    mdc:DrawEllipticArc(x-w, y-h, w*2, h*2, start, finish)
    mdc:SetBrush(wx.wxNullBrush)
    mdc:SetPen(wx.wxNullPen)
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function move(dist)
  if not dist then return end

  mdc:SelectObject(bitmap)

  each(function(turtle)
    mdc:SetPen(turtle.down and turtle.pendn or turtle.penup)

    local dx = dist * math.cos(turtle.angle * math.pi/180)
    local dy = dist * math.sin(turtle.angle * math.pi/180)
    turtle.x, turtle.y = turtle.x+dx, turtle.y+dy
    mdc:DrawLine(round(turtle.x-dx), round(turtle.y-dy), round(turtle.x), round(turtle.y))
    mdc:SetPen(wx.wxNullPen)
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function fill(color, dx, dy)
  if not color then return end

  mdc:SelectObject(bitmap)

  each(function(turtle)
    mdc:SetBrush(wx.wxBrush(color, wx.wxSOLID))
    mdc:FloodFill(turtle.x+(dx or 0), turtle.y+(dy or 0),
      turtle.pendn:GetColour(), wx.wxFLOOD_BORDER)
    mdc:SetBrush(wx.wxNullBrush) -- release the brush
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function text(text, angle)
  if not text then return end

  mdc:SelectObject(bitmap)

  each(function(turtle)
    if angle then
      mdc:DrawRotatedText(text, turtle.x, turtle.y, angle)
    else
      mdc:DrawText(text, turtle.x, turtle.y)
    end
  end)

  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function load(file)
  if not file then return end
  if not wx.wxFileName(file):FileExists() then file = file .. ".png" end

  if not bitmaps[file] then
    bitmaps[file] = wx.wxBitmap()
    bitmaps[file]:LoadFile(file, wx.wxBITMAP_TYPE_ANY)
  end

  -- if the size is the same, then load the entire bitmap
  if bitmap:GetWidth() == bitmaps[file]:GetWidth() and
     bitmap:GetHeight() == bitmaps[file]:GetHeight() then
    bitmap:LoadFile(file, wx.wxBITMAP_TYPE_ANY)
  else
    each(function(turtle)
      mdc:SelectObject(bitmap)
      mdc:DrawBitmap(bitmaps[file], turtle.x, turtle.y, true)
      mdc:SelectObject(wx.wxNullBitmap)
    end)
  end
  if autoUpdate then updt() end
end

local function wipe()
  mdc:SelectObject(bitmap)
  mdc:Clear()
  mdc:SelectObject(wx.wxNullBitmap)
  if autoUpdate then updt() end
end

local function logf(value)
  local curr = mdc:GetLogicalFunction()
  if value then mdc:SetLogicalFunction(value) end
  return curr
end

local function wait(seconds)
  if seconds then
    wx.wxMilliSleep(seconds*1000)
  else
    exit = false
    wx.wxGetApp():MainLoop()
  end
end

local function pndn() each(function(turtle) turtle.down = true end) end
local function pnup() each(function(turtle) turtle.down = false end) end
local function rand(limit) return limit and (math.random(limit)-1) or (0) end

local drawing = {
  show = function () showTurtles = true updt() end,
  hide = function () showTurtles = false updt() end,
  copy = function () end, -- copy a turtle
  name = function () end, -- name the turtle
  trtl = trtl,
  pick = pick,

  pndn = pndn,
  pnup = pnup,
  pnsz = function (...)
    local r = each(function(turtle, size)
      local curr = turtle.pendn:GetWidth()
      if size then turtle.pendn:SetWidth(size) end
      return curr
    end, ...)
    if showTurtles then updt() end
    return r
  end,
  pncl = function (...)
    local r = each(function(turtle, color)
      local curr = turtle.pendn:GetColour()
      if color then turtle.pendn:SetColour(color) end
      return curr
    end, ...)
    if showTurtles then updt() end
    return r
  end,
  posn = function (...)
    return each(function(turtle, nx, ny)
      if not nx and not ny then return turtle.x, turtle.y end
      if nx then turtle.x = nx end
      if ny then turtle.y = ny end
    end, ...)
  end,
  dist = function ()
    return each(function(turtle)
      local x, y = turtle.x, turtle.y
      return math.sqrt(x*x + y*y)
    end)
  end,
  turn = function (angle)
    if not angle then return end
    each(function(turtle) turtle.angle = (turtle.angle + angle) % 360 end)
    if showTurtles then updt() end
  end,
  bank = function () end,
  ptch = function () end,
  fill = fill,
  move = move,
  jump = function (dist) pnup() move(dist) pndn() end,
  back = function (dist) move(-dist) end,

  line = line,
  rect = rect,
  crcl = function (x, y, r, c, s, f) oval(x, y, r, r, c, s, f) end,
  oval = oval,

  colr = function (r, g, b)
    if not g or not b then return r end
    return wx.wxColour(r, g, b):GetAsString(wx.wxC2S_HTML_SYNTAX)
  end,
  char = function (char)
    if char then return type(char) == 'string' and char:byte() or char end
    local curr = key
    key = nil
    return curr
  end,
  clck = function (type)
    if not click[type] then return end
    local curr = click[type]
    click[type] = nil
    return curr.x, curr.y
  end,
  wipe = wipe,
  wait = wait,
  updt = updt,
  rand = rand,
  ranc = function () return colr(rand(256),rand(256),rand(256)) end,
  logf = logf,
  load = load,
  save = function (file) bitmap:SaveFile(file .. '.png', wx.wxBITMAP_TYPE_PNG) end,
  snap = function () return bitmap:GetSubBitmap(
    wx.wxRect(0, 0, bitmap:GetWidth(), bitmap:GetHeight())) end,
  undo = function (snapshot) if snapshot then bitmap = wx.wxBitmap(snapshot) end end,
  play = function (file)
    if not wx.wxFileName(file):FileExists() then file = file .. ".wav" end
    if not sounds[file] then sounds[file] = wx.wxSound(file) end
    sounds[file]:Play()
  end,
  text = text,
  time = function () return os.clock() end,
  open = open,
  done = function () frame:Close() end,
  init = function () end, -- initialize turtle and the field
  size = function (x, y)
    local size = frame:GetClientSize()
    if not x and not y then return size:GetWidth(), size:GetHeight() end
    frame:SetClientSize(x or size:GetWidth(), y or size:GetHeight())
    reset()
  end,
}

math.randomseed(os.clock()*1000)
open()

for name, func in pairs(drawing) do
  _G[name] = func
end
