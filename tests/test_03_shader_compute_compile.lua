package.path = "./?.lua;./?/init.lua;" .. package.path

require("window")
local gl = require("gl")
local shader = require("shader")
local testlib = require("tests.testlib")

local comp = nil
local gl_done = false
local shader_done = false

testlib.run_window_test("test_03_shader_compute_compile", 10, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true
    comp = shader.compute("compute_test", "shaders/compute.comp")
    print("[COMPILE] compute shader id=", tostring(comp.id))
    shader_done = true
  elseif phase == "frame" then
    shader.update_all(0.016)
  elseif phase == "render" then
    gl.clear(0.02, 0.08, 0.02, 1.0)
    gl.swap()
  elseif phase == "shutdown" then
    if shader_done then shader.shutdown_all() end
    if gl_done then gl.shutdown() end
  end
end)
