package.path = "./?.lua;./?/init.lua;" .. package.path

local window = require("window")

-- Тест Layer 1: real app.lua с gl_ready guard.
local app = require("app")

local survived = false
local quit_fn = nil

local orig_init = app.init

function app.init(ctx)
  quit_fn = ctx.quit
  orig_init(ctx)

  survived = true
  print("[TEST] Layer 1 OK: resize before init did NOT crash")
  print("[TEST] app.width =", app.width, "app.height =", app.height)
  quit_fn()
end

print("[TEST] test_10_resize_before_init — проверка Layer 1 (gl_ready guard)")

window.run({
  title = "test_10_resize_before_init",
  width = 320,
  height = 240,
  app = app,
})

if survived then
  print("[TEST] PASSED — resize-before-init безопасен, отложен через pending_resize")
else
  print("[TEST] FAILED — не дожили до конца")
  os.exit(1)
end
