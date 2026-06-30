local ffi = require("ffi")
local bit = require("bit")

local bor = bit.bor

-- HANDLE, HWND, HINSTANCE, HDC, LPCSTR, WORD, UINT, DWORD, BOOL, BYTE,
-- LONG_PTR, ULONG_PTR, UINT_PTR, LPARAM, WPARAM, LRESULT уже определены в window.lua
ffi.cdef [[

typedef HANDLE HDC;
typedef HANDLE HGLRC;

typedef void* PROC;

typedef struct tagPIXELFORMATDESCRIPTOR {
  WORD  nSize;
  WORD  nVersion;
  DWORD dwFlags;
  BYTE  iPixelType;
  BYTE  cColorBits;
  BYTE  cRedBits;
  BYTE  cRedShift;
  BYTE  cGreenBits;
  BYTE  cGreenShift;
  BYTE  cBlueBits;
  BYTE  cBlueShift;
  BYTE  cAlphaBits;
  BYTE  cAlphaShift;
  BYTE  cAccumBits;
  BYTE  cAccumRedBits;
  BYTE  cAccumGreenBits;
  BYTE  cAccumBlueBits;
  BYTE  cAccumAlphaBits;
  BYTE  cDepthBits;
  BYTE  cStencilBits;
  BYTE  cAuxBuffers;
  BYTE  iLayerType;
  BYTE  bReserved;
  DWORD dwLayerMask;
  DWORD dwVisibleMask;
  DWORD dwDamageMask;
} PIXELFORMATDESCRIPTOR;

HDC GetDC(HWND hWnd);
int ReleaseDC(HWND hWnd, HDC hDC);

int ChoosePixelFormat(HDC hdc, const PIXELFORMATDESCRIPTOR *ppfd);
BOOL SetPixelFormat(HDC hdc, int format, const PIXELFORMATDESCRIPTOR *ppfd);
BOOL SwapBuffers(HDC hdc);

HGLRC wglCreateContext(HDC hdc);
BOOL wglDeleteContext(HGLRC hglrc);
BOOL wglMakeCurrent(HDC hdc, HGLRC hglrc);
PROC wglGetProcAddress(LPCSTR lpszProc);

void glClearColor(float red, float green, float blue, float alpha);
void glClear(unsigned int mask);
void glViewport(int x, int y, int width, int height);
const unsigned char* glGetString(unsigned int name);
unsigned int glGetError(void);

typedef HGLRC (__stdcall *PFNWGLCREATECONTEXTATTRIBSARBPROC)(
  HDC hDC,
  HGLRC hShareContext,
  const int *attribList
);

typedef BOOL (__stdcall *PFNWGLSWAPINTERVALEXTPROC)(int interval);

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef unsigned int GLbitfield;
typedef float GLfloat;
typedef char GLchar;
typedef unsigned char GLboolean;

typedef GLuint (__stdcall *PFNGLCREATESHADERPROC)(GLenum type);
typedef void   (__stdcall *PFNGLSHADERSOURCEPROC)(GLuint shader, GLsizei count, const GLchar **string, const GLint *length);
typedef void   (__stdcall *PFNGLCOMPILESHADERPROC)(GLuint shader);
typedef void   (__stdcall *PFNGLGETSHADERIVPROC)(GLuint shader, GLenum pname, GLint *params);
typedef void   (__stdcall *PFNGLGETSHADERINFOLOGPROC)(GLuint shader, GLsizei maxLength, GLsizei *length, GLchar *infoLog);
typedef void   (__stdcall *PFNGLDELETESHADERPROC)(GLuint shader);

typedef GLuint (__stdcall *PFNGLCREATEPROGRAMPROC)(void);
typedef void   (__stdcall *PFNGLATTACHSHADERPROC)(GLuint program, GLuint shader);
typedef void   (__stdcall *PFNGLLINKPROGRAMPROC)(GLuint program);
typedef void   (__stdcall *PFNGLGETPROGRAMIVPROC)(GLuint program, GLenum pname, GLint *params);
typedef void   (__stdcall *PFNGLGETPROGRAMINFOLOGPROC)(GLuint program, GLsizei maxLength, GLsizei *length, GLchar *infoLog);
typedef void   (__stdcall *PFNGLDELETEPROGRAMPROC)(GLuint program);
typedef void   (__stdcall *PFNGLUSEPROGRAMPROC)(GLuint program);

typedef GLint  (__stdcall *PFNGLGETUNIFORMLOCATIONPROC)(GLuint program, const GLchar *name);
typedef void   (__stdcall *PFNGLUNIFORM1FPROC)(GLint location, GLfloat v0);
typedef void   (__stdcall *PFNGLUNIFORM2FPROC)(GLint location, GLfloat v0, GLfloat v1);

typedef void   (__stdcall *PFNGLGENVERTEXARRAYSPROC)(GLsizei n, GLuint *arrays);
typedef void   (__stdcall *PFNGLBINDVERTEXARRAYPROC)(GLuint array);
typedef void   (__stdcall *PFNGLDRAWARRAYSPROC)(GLenum mode, GLint first, GLsizei count);
]]

local user32 = ffi.load("user32")
local gdi32 = ffi.load("gdi32")
local opengl32 = ffi.load("opengl32")

local M = {}

-- ============================================================
-- Constants
-- ============================================================

local PFD_TYPE_RGBA = 0
local PFD_MAIN_PLANE = 0

local PFD_DOUBLEBUFFER = 0x00000001
local PFD_DRAW_TO_WINDOW = 0x00000004
local PFD_SUPPORT_OPENGL = 0x00000020

local GL_COLOR_BUFFER_BIT = 0x00004000
local GL_VENDOR = 0x1F00
local GL_RENDERER = 0x1F01
local GL_VERSION = 0x1F02
local GL_SHADING_LANGUAGE_VERSION = 0x8B8C

local WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
local WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
local WGL_CONTEXT_FLAGS_ARB = 0x2094
local WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126

local WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
local WGL_CONTEXT_DEBUG_BIT_ARB = 0x00000001

-- ============================================================
-- State
-- ============================================================

local state = {
  hwnd = nil,
  hdc = nil,
  hglrc = nil,

  wglCreateContextAttribsARB = nil,
  wglSwapIntervalEXT = nil,

  version = nil,
  vendor = nil,
  renderer = nil,
  shading_language = nil,
}

M.fn = {}

local function is_bad_gl_pointer(ptr)
  if ptr == nil then
    return true
  end

  local ok, addr = pcall(function()
    return tonumber(ffi.cast("intptr_t", ptr))
  end)

  if not ok or addr == nil then
    return false
  end

  return addr == 0 or addr == 1 or addr == 2 or addr == 3 or addr == -1
end

local function load_gl_proc(name, ctype)
  local ptr = opengl32.wglGetProcAddress(name)

  if is_bad_gl_pointer(ptr) then
    error("OpenGL function not available: " .. name)
  end

  return ffi.cast(ctype, ptr)
end

local function load_gl_functions()
  local fn = M.fn

  fn.glCreateShader = load_gl_proc("glCreateShader", "PFNGLCREATESHADERPROC")
  fn.glShaderSource = load_gl_proc("glShaderSource", "PFNGLSHADERSOURCEPROC")
  fn.glCompileShader = load_gl_proc("glCompileShader", "PFNGLCOMPILESHADERPROC")
  fn.glGetShaderiv = load_gl_proc("glGetShaderiv", "PFNGLGETSHADERIVPROC")
  fn.glGetShaderInfoLog = load_gl_proc("glGetShaderInfoLog", "PFNGLGETSHADERINFOLOGPROC")
  fn.glDeleteShader = load_gl_proc("glDeleteShader", "PFNGLDELETESHADERPROC")

  fn.glCreateProgram = load_gl_proc("glCreateProgram", "PFNGLCREATEPROGRAMPROC")
  fn.glAttachShader = load_gl_proc("glAttachShader", "PFNGLATTACHSHADERPROC")
  fn.glLinkProgram = load_gl_proc("glLinkProgram", "PFNGLLINKPROGRAMPROC")
  fn.glGetProgramiv = load_gl_proc("glGetProgramiv", "PFNGLGETPROGRAMIVPROC")
  fn.glGetProgramInfoLog = load_gl_proc("glGetProgramInfoLog", "PFNGLGETPROGRAMINFOLOGPROC")
  fn.glDeleteProgram = load_gl_proc("glDeleteProgram", "PFNGLDELETEPROGRAMPROC")
  fn.glUseProgram = load_gl_proc("glUseProgram", "PFNGLUSEPROGRAMPROC")

  fn.glGetUniformLocation = load_gl_proc("glGetUniformLocation", "PFNGLGETUNIFORMLOCATIONPROC")
  fn.glUniform1f = load_gl_proc("glUniform1f", "PFNGLUNIFORM1FPROC")
  fn.glUniform2f = load_gl_proc("glUniform2f", "PFNGLUNIFORM2FPROC")

  fn.glGenVertexArrays = load_gl_proc("glGenVertexArrays", "PFNGLGENVERTEXARRAYSPROC")
  fn.glBindVertexArray = load_gl_proc("glBindVertexArray", "PFNGLBINDVERTEXARRAYPROC")
  fn.glDrawArrays = load_gl_proc("glDrawArrays", "PFNGLDRAWARRAYSPROC")
end

-- ============================================================
-- Helpers
-- ============================================================

local function cstr(ptr)
  if ptr == nil then
    return nil
  end

  return ffi.string(ptr)
end

local function check_gl_error(label)
  local err = opengl32.glGetError()

  if err ~= 0 then
    print("GL ERROR after " .. label .. ": 0x" .. string.format("%X", err))
  end
end

local function load_wgl_proc(name, ctype)
  local ptr = opengl32.wglGetProcAddress(name)

  if ptr == nil then
    return nil
  end

  return ffi.cast(ctype, ptr)
end

local function choose_basic_pixel_format(hdc)
  local pfd = ffi.new("PIXELFORMATDESCRIPTOR")
  pfd.nSize = ffi.sizeof("PIXELFORMATDESCRIPTOR")
  pfd.nVersion = 1
  pfd.dwFlags = bor(PFD_DRAW_TO_WINDOW, PFD_SUPPORT_OPENGL, PFD_DOUBLEBUFFER)
  pfd.iPixelType = PFD_TYPE_RGBA
  pfd.cColorBits = 32
  pfd.cAlphaBits = 8
  pfd.cDepthBits = 24
  pfd.cStencilBits = 8
  pfd.iLayerType = PFD_MAIN_PLANE

  local format = gdi32.ChoosePixelFormat(hdc, pfd)

  if format == 0 then
    error("ChoosePixelFormat failed")
  end

  if gdi32.SetPixelFormat(hdc, format, pfd) == 0 then
    error("SetPixelFormat failed")
  end
end

local function create_legacy_context(hdc)
  local ctx = opengl32.wglCreateContext(hdc)

  if ctx == nil then
    error("wglCreateContext failed")
  end

  if opengl32.wglMakeCurrent(hdc, ctx) == 0 then
    error("wglMakeCurrent legacy failed")
  end

  return ctx
end

local function create_core_context(hdc, legacy_ctx)
  local wglCreateContextAttribsARB = load_wgl_proc(
    "wglCreateContextAttribsARB",
    "PFNWGLCREATECONTEXTATTRIBSARBPROC"
  )

  if wglCreateContextAttribsARB == nil then
    error("wglCreateContextAttribsARB not available. OpenGL driver too old or broken.")
  end

  state.wglCreateContextAttribsARB = wglCreateContextAttribsARB

  local attribs = ffi.new("int[?]", 9, {
    WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
    WGL_CONTEXT_MINOR_VERSION_ARB, 3,
    WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
    WGL_CONTEXT_FLAGS_ARB, 0,
    0
  })

  local core_ctx = wglCreateContextAttribsARB(hdc, nil, attribs)

  if core_ctx == nil then
    error("wglCreateContextAttribsARB failed for OpenGL 4.3 core")
  end

  opengl32.wglMakeCurrent(nil, nil)
  opengl32.wglDeleteContext(legacy_ctx)

  if opengl32.wglMakeCurrent(hdc, core_ctx) == 0 then
    error("wglMakeCurrent core failed")
  end

  return core_ctx
end

local function try_load_swap_interval()
  local swap_interval = load_wgl_proc(
    "wglSwapIntervalEXT",
    "PFNWGLSWAPINTERVALEXTPROC"
  )

  state.wglSwapIntervalEXT = swap_interval

  if swap_interval ~= nil then
    swap_interval(1)
  end
end

-- ============================================================
-- Public API
-- ============================================================

function M.init(hwnd, width, height)
  state.hwnd = hwnd
  state.hdc = user32.GetDC(hwnd)

  if state.hdc == nil then
    error("GetDC failed")
  end

  choose_basic_pixel_format(state.hdc)

  local legacy_ctx = create_legacy_context(state.hdc)
  state.hglrc = create_core_context(state.hdc, legacy_ctx)

  load_gl_functions()

  try_load_swap_interval()

  state.vendor = cstr(opengl32.glGetString(GL_VENDOR))
  state.renderer = cstr(opengl32.glGetString(GL_RENDERER))
  state.version = cstr(opengl32.glGetString(GL_VERSION))
  state.shading_language = cstr(opengl32.glGetString(GL_SHADING_LANGUAGE_VERSION))

  print("OpenGL initialized")
  print("  Vendor:   ", state.vendor)
  print("  Renderer: ", state.renderer)
  print("  Version:  ", state.version)
  print("  GLSL:     ", state.shading_language)

  M.viewport(width, height)
  check_gl_error("gl init")
end

function M.viewport(width, height)
  width = math.max(1, math.floor(width or 1))
  height = math.max(1, math.floor(height or 1))

  opengl32.glViewport(0, 0, width, height)
end

function M.clear(r, g, b, a)
  opengl32.glClearColor(r or 0, g or 0, b or 0, a or 1)
  opengl32.glClear(GL_COLOR_BUFFER_BIT)
end

function M.swap()
  if state.hdc ~= nil then
    gdi32.SwapBuffers(state.hdc)
  end
end

function M.shutdown()
  if state.hglrc ~= nil then
    opengl32.wglMakeCurrent(nil, nil)
    opengl32.wglDeleteContext(state.hglrc)
    state.hglrc = nil
  end

  if state.hdc ~= nil and state.hwnd ~= nil then
    user32.ReleaseDC(state.hwnd, state.hdc)
    state.hdc = nil
  end

  state.hwnd = nil

  print("OpenGL shutdown")
end

function M.info()
  return {
    vendor = state.vendor,
    renderer = state.renderer,
    version = state.version,
    shading_language = state.shading_language,
  }
end

function M.use_program(program)
  M.fn.glUseProgram(program or 0)
end

function M.create_vertex_array()
  local vao = ffi.new("GLuint[1]")
  M.fn.glGenVertexArrays(1, vao)
  return vao[0]
end

function M.bind_vertex_array(vao)
  M.fn.glBindVertexArray(vao or 0)
end

function M.draw_triangles(first, count)
  local GL_TRIANGLES = 0x0004
  M.fn.glDrawArrays(GL_TRIANGLES, first or 0, count or 3)
end

return M
