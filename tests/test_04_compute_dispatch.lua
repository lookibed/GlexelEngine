package.path = "./?.lua;./?/init.lua;" .. package.path

require("window")
local gl = require("gl")
local shader = require("shader")
local testlib = require("tests.testlib")

local function ceil_div(a, b)
  return math.floor((a + b - 1) / b)
end

local comp = nil
local tex = nil
local gl_done = false
local shader_done = false

testlib.run_window_test("test_04_compute_dispatch", 10, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true
    comp = shader.compute("compute_dispatch_test", "shaders/compute.comp")
    print("[DISPATCH] compute shader id=", tostring(comp.id))
    shader_done = true
    tex = gl.create_texture_rgba8(256, 256)
    print("[DISPATCH] texture id=", tostring(tex))
  elseif phase == "frame" then
    shader.update_all(0.016)

    local t = app.elapsed

    comp:use()
    comp:uniform1f("u_time", t)
    comp:uniform2f("u_resolution", 256, 256)

    gl.bind_image_texture_write(0, tex)
    gl.dispatch_compute(ceil_div(256, 8), ceil_div(256, 8), 1)
    gl.compute_barrier()
  elseif phase == "render" then
    gl.clear(0.02, 0.02, 0.10, 1.0)
    gl.swap()
  elseif phase == "shutdown" then
    if tex then gl.delete_texture(tex) end
    if shader_done then shader.shutdown_all() end
    if gl_done then gl.shutdown() end
  end
end)
