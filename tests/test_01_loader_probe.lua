package.path = "./?.lua;./?/init.lua;" .. package.path

local ffi = require("ffi")
require("window")
local gl = require("gl")
local testlib = require("tests.testlib")

-- Не переопределяем существующие типы — они уже в window/gl.
ffi.cdef [[
HINSTANCE LoadLibraryA(LPCSTR lpLibFileName);
]]

local kernel32 = ffi.load("kernel32")
local opengl32 = ffi.load("opengl32")

local function ptr_num(ptr)
  if ptr == nil then return nil end
  local ok, n = pcall(function() return tonumber(ffi.cast("intptr_t", ptr)) end)
  if ok then return n end
  return nil
end

local function is_bad(ptr)
  local n = ptr_num(ptr)
  if n == nil then return true end
  return n == 0 or n == 1 or n == 2 or n == 3 or n == -1
end

local names = {
  "glBindTexture", "glGenTextures", "glDeleteTextures",
  "glTexParameteri", "glTexImage2D",
  "glActiveTexture", "glCreateShader", "glShaderSource",
  "glCompileShader", "glCreateProgram", "glUseProgram",
  "glUniform1i", "glDispatchCompute", "glMemoryBarrier", "glBindImageTexture",
}

local gl_done = false
local probed = false

testlib.run_window_test("test_01_loader_probe", 10, function(phase, app, ctx)
  if phase == "init" then
    gl.init(ctx.hwnd, ctx.width, ctx.height)
    gl_done = true

    local module = kernel32.LoadLibraryA("opengl32.dll")
    print("[PROBE] opengl32 module=", tostring(module), "bad=", tostring(is_bad(module)))

    for _, name in ipairs(names) do
      local wgl_ptr = opengl32.wglGetProcAddress(name)
      local dll_ptr = nil
      if module ~= nil then
        dll_ptr = kernel32.GetProcAddress(module, name)
      end
      print("[PROBE]", name,
        "wgl=", tostring(ptr_num(wgl_ptr)), "wgl_bad=", tostring(is_bad(wgl_ptr)),
        "dll=", tostring(ptr_num(dll_ptr)), "dll_bad=", tostring(is_bad(dll_ptr)))
    end

    probed = true
  elseif phase == "frame" then
  elseif phase == "render" then
    gl.clear(0.04, 0.02, 0.02, 1.0)
    gl.swap()
  elseif phase == "shutdown" then
    if gl_done then gl.shutdown() end
  end
end)
