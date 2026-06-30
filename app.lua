local gl = require("gl")

local app = {}

function app.init(ctx)
  app.width = ctx.width
  app.height = ctx.height
  app.time = 0

  gl.init(ctx.hwnd, ctx.width, ctx.height)
end

function app.resize(width, height)
  app.width = width
  app.height = height

  gl.viewport(width, height)
end

function app.update(dt)
  app.time = app.time + dt
end

function app.render()
  local t = app.time

  local r = math.sin(t * 1.1) * 0.5 + 0.5
  local g = math.sin(t * 1.7 + 2.0) * 0.5 + 0.5
  local b = math.sin(t * 2.3 + 4.0) * 0.5 + 0.5

  gl.clear(r * 0.25, g * 0.25, b * 0.25, 1.0)
  gl.swap()
end

function app.key_down(vk)
  -- ESC
  if vk == 0x1B then
    return "quit"
  end
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
  gl.shutdown()
end

return app
