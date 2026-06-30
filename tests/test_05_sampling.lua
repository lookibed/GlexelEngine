package.path = "./?.lua;./?/init.lua;" .. package.path

require("window")
local gl = require("gl")
local shader = require("shader")
local testlib = require("tests.testlib")

local function ceil_div(a, b)
  return math.floor((a + b - 1) / b)
end

local compute = nil
local screen = nil
local tex = nil
local vao = nil
local gl_done = false
local shader_done = false

testlib.run_window_test("test_05_sampling", 15, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true

    compute = shader.compute("compute_sampling", "shaders/compute.comp")
    screen = shader.graphics("screen_sampling", "shaders/fullscreen.vert", "shaders/fullscreen.frag")
    shader_done = true
    print("[SAMP] compute id=", tostring(compute.id), "screen id=", tostring(screen.id))

    vao = gl.create_vertex_array()
    gl.bind_vertex_array(vao)
    print("[SAMP] VAO created=", tostring(vao))

    tex = gl.create_texture_rgba8(app.width, app.height)
    print("[SAMP] texture id=", tostring(tex))
  elseif phase == "frame" then
    shader.update_all(0.016)

    local t = app.elapsed

    compute:use()
    compute:uniform1f("u_time", t)
    compute:uniform2f("u_resolution", app.width, app.height)
    gl.bind_image_texture_write(0, tex)
    gl.dispatch_compute(ceil_div(app.width, 8), ceil_div(app.height, 8), 1)
    gl.compute_barrier()

    gl.clear(0.0, 0.0, 0.0, 1.0)

    screen:use()
    gl.bind_texture(0, tex)
    screen:uniform1i("u_texture", 0)
    gl.bind_vertex_array(vao)
    gl.draw_triangles(0, 3)
    gl.swap()
  elseif phase == "render" then
  elseif phase == "shutdown" then
    if tex then gl.delete_texture(tex) end
    if shader_done then shader.shutdown_all() end
    if gl_done then gl.shutdown() end
  end
end, { width = 1280, height = 720 })
