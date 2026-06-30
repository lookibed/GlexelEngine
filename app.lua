local gl = require("gl")
local shader = require("shader")

local app = {}

app.gl_ready = false
app.pending_resize = nil

local function ceil_div(a, b)
  return math.floor((a + b - 1) / b)
end

local function recreate_output_texture()
  if app.output_texture and app.output_texture ~= 0 then
    gl.delete_texture(app.output_texture)
  end

  app.output_texture = gl.create_texture_rgba8(app.width, app.height)
end

function app.init(ctx)
  app.gl_ready = false

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

  app.compute_program = shader.compute(
    "compute",
    "shaders/compute.comp"
  )

  if app.pending_resize then
    app.width = app.pending_resize.width
    app.height = app.pending_resize.height
    app.pending_resize = nil
  end

  app.gl_ready = true

  gl.viewport(app.width, app.height)
  recreate_output_texture()
end

function app.resize(width, height)
  width = math.max(1, width)
  height = math.max(1, height)

  if not app.gl_ready then
    app.pending_resize = { width = width, height = height }
    return
  end

  app.width = width
  app.height = height

  gl.viewport(width, height)
  recreate_output_texture()
end

function app.update(dt)
  app.time = app.time + dt

  shader.update_all(dt)
end

function app.render()
  if not app.gl_ready then
    return
  end

  if not app.output_texture or app.output_texture == 0 then
    return
  end

  -- Pass 1: compute shader пишет в texture.
  app.compute_program:use()
  app.compute_program:uniform1f("u_time", app.time)
  app.compute_program:uniform2f("u_resolution", app.width, app.height)

  gl.bind_image_texture_write(0, app.output_texture)

  local groups_x = ceil_div(app.width, 8)
  local groups_y = ceil_div(app.height, 8)

  gl.dispatch_compute(groups_x, groups_y, 1)
  gl.compute_barrier()

  -- Pass 2: fullscreen triangle показывает texture.
  gl.clear(0.0, 0.0, 0.0, 1.0)

  app.screen_program:use()

  gl.bind_texture(0, app.output_texture)
  app.screen_program:uniform1i("u_texture", 0)

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
  if app.output_texture then
    gl.delete_texture(app.output_texture)
    app.output_texture = nil
  end

  shader.shutdown_all()
  gl.shutdown()
end

return app
