local ffi = require("ffi")
local gl = require("gl")

local M = {}

local GL_VERTEX_SHADER = 0x8B31
local GL_FRAGMENT_SHADER = 0x8B30

local GL_COMPILE_STATUS = 0x8B81
local GL_LINK_STATUS = 0x8B82
local GL_INFO_LOG_LENGTH = 0x8B84

local programs = {}

local function log_line(text)
  local f = io.open("shader_hotreload.log", "a")
  if f then
    f:write(os.date("[%H:%M:%S] "), text, "\n")
    f:close()
  end
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil, "Cannot open file: " .. path
  end

  local data = f:read("*a")
  f:close()

  return data
end

local function get_shader_log(shader)
  local len = ffi.new("GLint[1]")
  gl.fn.glGetShaderiv(shader, GL_INFO_LOG_LENGTH, len)

  if len[0] <= 1 then
    return ""
  end

  local buf = ffi.new("char[?]", len[0])
  local written = ffi.new("GLsizei[1]")

  gl.fn.glGetShaderInfoLog(shader, len[0], written, buf)

  return ffi.string(buf, written[0])
end

local function get_program_log(program)
  local len = ffi.new("GLint[1]")
  gl.fn.glGetProgramiv(program, GL_INFO_LOG_LENGTH, len)

  if len[0] <= 1 then
    return ""
  end

  local buf = ffi.new("char[?]", len[0])
  local written = ffi.new("GLsizei[1]")

  gl.fn.glGetProgramInfoLog(program, len[0], written, buf)

  return ffi.string(buf, written[0])
end

local function compile_shader(kind, source, path)
  local shader = gl.fn.glCreateShader(kind)

  if shader == 0 then
    return nil, "glCreateShader failed: " .. path
  end

  local src = ffi.new("const char*[1]")
  local cbuf = ffi.new("char[?]", #source + 1)
  ffi.copy(cbuf, source)
  src[0] = ffi.cast("const char*", cbuf)

  local len = ffi.new("GLint[1]", #source)

  gl.fn.glShaderSource(shader, 1, src, len)
  gl.fn.glCompileShader(shader)

  local ok = ffi.new("GLint[1]")
  gl.fn.glGetShaderiv(shader, GL_COMPILE_STATUS, ok)

  if ok[0] == 0 then
    local err = get_shader_log(shader)
    gl.fn.glDeleteShader(shader)

    return nil, "Compile failed: " .. path .. "\n" .. err
  end

  return shader
end

local function link_program(vs, fs)
  local program = gl.fn.glCreateProgram()

  if program == 0 then
    return nil, "glCreateProgram failed"
  end

  gl.fn.glAttachShader(program, vs)
  gl.fn.glAttachShader(program, fs)
  gl.fn.glLinkProgram(program)

  local ok = ffi.new("GLint[1]")
  gl.fn.glGetProgramiv(program, GL_LINK_STATUS, ok)

  if ok[0] == 0 then
    local err = get_program_log(program)
    gl.fn.glDeleteProgram(program)

    return nil, "Link failed:\n" .. err
  end

  return program
end

local Program = {}
Program.__index = Program

function Program:reload(force)
  local vs_source, vs_err = read_file(self.vertex_path)
  if not vs_source then
    self.last_error = vs_err
    log_line(vs_err)
    return false
  end

  local fs_source, fs_err = read_file(self.fragment_path)
  if not fs_source then
    self.last_error = fs_err
    log_line(fs_err)
    return false
  end

  if not force and vs_source == self.vertex_source and fs_source == self.fragment_source then
    return false
  end

  log_line("Reload requested: " .. self.name)

  local vs, err = compile_shader(GL_VERTEX_SHADER, vs_source, self.vertex_path)
  if not vs then
    self.last_error = err
    log_line(err)
    return false
  end

  local fs
  fs, err = compile_shader(GL_FRAGMENT_SHADER, fs_source, self.fragment_path)
  if not fs then
    gl.fn.glDeleteShader(vs)
    self.last_error = err
    log_line(err)
    return false
  end

  local new_program
  new_program, err = link_program(vs, fs)

  gl.fn.glDeleteShader(vs)
  gl.fn.glDeleteShader(fs)

  if not new_program then
    self.last_error = err
    log_line(err)
    return false
  end

  local old_program = self.id

  self.id = new_program
  self.vertex_source = vs_source
  self.fragment_source = fs_source
  self.last_error = nil
  self.uniform_cache = {}

  if old_program and old_program ~= 0 then
    gl.fn.glDeleteProgram(old_program)
  end

  log_line("Reload OK: " .. self.name)

  return true
end

function Program:update(dt)
  self.check_timer = self.check_timer + dt

  if self.check_timer < self.check_interval then
    return
  end

  self.check_timer = 0

  self:reload(false)
end

function Program:use()
  gl.fn.glUseProgram(self.id or 0)
end

function Program:uniform_location(name)
  local cached = self.uniform_cache[name]
  if cached ~= nil then
    return cached
  end

  local loc = gl.fn.glGetUniformLocation(self.id, name)
  self.uniform_cache[name] = loc

  return loc
end

function Program:uniform1f(name, x)
  local loc = self:uniform_location(name)
  if loc >= 0 then
    gl.fn.glUniform1f(loc, x)
  end
end

function Program:uniform2f(name, x, y)
  local loc = self:uniform_location(name)
  if loc >= 0 then
    gl.fn.glUniform2f(loc, x, y)
  end
end

function Program:delete()
  if self.id and self.id ~= 0 then
    gl.fn.glDeleteProgram(self.id)
    self.id = 0
  end
end

function M.graphics(name, vertex_path, fragment_path)
  local program = setmetatable({
    name = name,
    vertex_path = vertex_path,
    fragment_path = fragment_path,

    id = 0,

    vertex_source = nil,
    fragment_source = nil,

    last_error = nil,

    check_timer = 0,
    check_interval = 0.25,

    uniform_cache = {},
  }, Program)

  local ok = program:reload(true)

  if not ok then
    error("Initial shader load failed: " .. name .. "\n" .. tostring(program.last_error))
  end

  table.insert(programs, program)

  return program
end

function M.update_all(dt)
  for i = 1, #programs do
    programs[i]:update(dt)
  end
end

function M.shutdown_all()
  for i = 1, #programs do
    programs[i]:delete()
  end

  programs = {}
end

return M
