local window = require("window")
local app = require("app")

window.run({
  title = "LuaJIT + WinAPI FFI",
  width = 1280,
  height = 720,
  app = app,
})
