local gl = require("gl")
local shader = require("shader")

local app = {}

function app.init(ctx)
  app.width = ctx.width
  app.height = ctx.height
  app.time = 0

  gl.init(ctx.hwnd, ctx.width, ctx.height)

  app.vao = gl.create_vertex_array()
  gl.bind_vertex_array(app.vao)

  app.screen_program = shader.graphics(
    "fullscreen",
    "shaders/fullscreen.vert",
    "shaders/fullscreen.frag"
  )
end

function app.resize(width, height)
  app.width = width
  app.height = height

  gl.viewport(width, height)
end

function app.update(dt)
  app.time = app.time + dt

  shader.update_all(dt)
end

function app.render()
  gl.clear(0.02, 0.02, 0.03, 1.0)

  app.screen_program:use()
  app.screen_program:uniform1f("u_time", app.time)
  app.screen_program:uniform2f("u_resolution", app.width, app.height)

  gl.bind_vertex_array(app.vao)
  gl.draw_triangles(0, 3)

  gl.swap()
end

function app.key_down(vk)
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
  shader.shutdown_all()
  gl.shutdown()
end

return app
