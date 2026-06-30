package.path = "./?.lua;./?/init.lua;" .. package.path

require("window")
local gl = require("gl")
local testlib = require("tests.testlib")

local tex = nil
local gl_done = false

testlib.run_window_test("test_02_texture_create", 10, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true
    tex = gl.create_texture_rgba8(256, 256)
    print("[TEX] created id=", tostring(tex))
  elseif phase == "frame" then
  elseif phase == "render" then
    gl.clear(0.08, 0.02, 0.02, 1.0)
    gl.swap()
  elseif phase == "shutdown" then
    if tex then gl.delete_texture(tex); print("[TEX] deleted") end
    if gl_done then gl.shutdown() end
  end
end)
