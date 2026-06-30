package.path = "./?.lua;./?/init.lua;" .. package.path

require("window")
local gl = require("gl")
local testlib = require("tests.testlib")

local gl_done = false

testlib.run_window_test("test_00_boot", 10, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true
  elseif phase == "frame" then
  elseif phase == "render" then
    gl.clear(0.02, 0.03, 0.07, 1.0)
    gl.swap()
  elseif phase == "shutdown" then
    if gl_done then gl.shutdown() end
  end
end)
