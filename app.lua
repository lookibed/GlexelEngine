local gdi = require("gdi")
local canvas = require("canvas")
local input = require("input")

local app = {}

function app.init(ctx)
  app.width = ctx.width
  app.height = ctx.height
  app.time = 0

  app.fps = 0
  app.fps_accum = 0
  app.fps_frames = 0

  app.player = {
    x = ctx.width * 0.5,
    y = ctx.height * 0.5,
    vx = 0,
    vy = 0,
    size = 28,
  }

  gdi.init(ctx.hwnd, ctx.width, ctx.height)
end

function app.resize(width, height)
  app.width = width
  app.height = height

  gdi.resize(width, height)
end

function app.update(dt)
  app.time = app.time + dt

  app.fps_accum = app.fps_accum + dt
  app.fps_frames = app.fps_frames + 1

  if app.fps_accum >= 0.25 then
    app.fps = app.fps_frames / app.fps_accum
    app.fps_accum = 0
    app.fps_frames = 0
  end

  if input.pressed("ESC") then
    return "quit"
  end

  local p = app.player

  local ax = 0
  local ay = 0

  if input.down("A") or input.down("LEFT") then
    ax = ax - 1
  end

  if input.down("D") or input.down("RIGHT") then
    ax = ax + 1
  end

  if input.down("W") or input.down("UP") then
    ay = ay - 1
  end

  if input.down("S") or input.down("DOWN") then
    ay = ay + 1
  end

  -- Нормализация диагонали.
  if ax ~= 0 and ay ~= 0 then
    local inv = 1 / math.sqrt(2)
    ax = ax * inv
    ay = ay * inv
  end

  local accel = 2400
  local friction = 12

  p.vx = p.vx + ax * accel * dt
  p.vy = p.vy + ay * accel * dt

  -- Space = пинок в сторону мышки.
  if input.pressed("SPACE") then
    local mx, my = input.mouse_pos()
    local dx = mx - p.x
    local dy = my - p.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len > 0.001 then
      dx = dx / len
      dy = dy / len

      p.vx = p.vx + dx * 900
      p.vy = p.vy + dy * 900
    end
  end

  -- ЛКМ = телепорт игрока.
  if input.mouse_pressed("left") then
    p.x, p.y = input.mouse_pos()
    p.vx = 0
    p.vy = 0
  end

  -- Простое трение.
  p.vx = p.vx - p.vx * friction * dt
  p.vy = p.vy - p.vy * friction * dt

  p.x = p.x + p.vx * dt
  p.y = p.y + p.vy * dt

  -- Коллизия со стенами.
  local half = p.size * 0.5

  if p.x < half then
    p.x = half
    p.vx = -p.vx * 0.45
  end

  if p.x > app.width - half then
    p.x = app.width - half
    p.vx = -p.vx * 0.45
  end

  if p.y < half then
    p.y = half
    p.vy = -p.vy * 0.45
  end

  if p.y > app.height - half then
    p.y = app.height - half
    p.vy = -p.vy * 0.45
  end
end

function app.render()
  local w = app.width
  local h = app.height
  local t = app.time
  local p = app.player

  local bg = gdi.rgb(12, 13, 18)
  local white = gdi.rgb(235, 240, 255)
  local muted = gdi.rgb(80, 90, 120)
  local yellow = gdi.rgb(255, 230, 90)
  local green = gdi.rgb(90, 255, 140)
  local red = gdi.rgb(255, 80, 90)
  local blue = gdi.rgb(80, 160, 255)

  canvas.clear(bg)

  -- Фоновая сетка.
  local grid = 40
  for x = 0, w, grid do
    canvas.line(x, 0, x, h, muted)
  end

  for y = 0, h, grid do
    canvas.line(0, y, w, y, muted)
  end

  -- Мышь и линия импульса.
  local mx, my = input.mouse_pos()

  canvas.line(p.x, p.y, mx, my, gdi.rgb(50, 80, 90))
  canvas.circle(mx, my, 14, green)
  canvas.rect(mx - 2, my - 2, 5, 5, white)

  -- Игрок.
  local pulse = 1 + math.sin(t * 8) * 0.08
  local size = p.size * pulse

  canvas.circle_filled(p.x, p.y, size, blue)
  canvas.circle(p.x, p.y, size + 4, white)

  -- Вектор скорости.
  canvas.line(p.x, p.y, p.x + p.vx * 0.08, p.y + p.vy * 0.08, red)

  -- UI.
  canvas.text("INPUT STATE DEMO", 24, 24, white, 3)
  canvas.text("WASD / ARROWS - MOVE", 24, 64, muted, 2)
  canvas.text("SPACE - BOOST TO MOUSE", 24, 86, muted, 2)
  canvas.text("LEFT CLICK - TELEPORT", 24, 108, muted, 2)
  canvas.text("FPS: " .. tostring(math.floor(app.fps)), 24, h - 58, yellow, 2)
  canvas.text("VEL: " .. math.floor(p.vx) .. ":" .. math.floor(p.vy), 24, h - 34, green, 2)

  canvas.present()
end

function app.key_down(vk)
end

function app.key_up(vk)
end

function app.mouse_move(x, y)
end

function app.mouse_down(button, x, y)
end

function app.mouse_up(button, x, y)
end

function app.shutdown()
  gdi.shutdown()
end

return app
