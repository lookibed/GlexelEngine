local ffi = require("ffi")
local bit = require("bit")
local input = require("input")

local bor = bit.bor
local band = bit.band
local rshift = bit.rshift

local is64 = ffi.abi("64bit")

ffi.cdef((is64 and [[
typedef int64_t  LONG_PTR;
typedef uint64_t ULONG_PTR;
typedef uint64_t UINT_PTR;
]] or [[
typedef int32_t  LONG_PTR;
typedef uint32_t ULONG_PTR;
typedef uint32_t UINT_PTR;
]]) .. [[

typedef void* HANDLE;
typedef HANDLE HWND;
typedef HANDLE HINSTANCE;
typedef HANDLE HICON;
typedef HANDLE HCURSOR;
typedef HANDLE HBRUSH;
typedef HANDLE HMENU;

typedef const char* LPCSTR;

typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned int UINT;
typedef unsigned long DWORD;
typedef int BOOL;
typedef long LONG;

typedef LONG_PTR LPARAM;
typedef UINT_PTR WPARAM;
typedef LONG_PTR LRESULT;

typedef unsigned short ATOM;

typedef LRESULT (__stdcall *WNDPROC)(HWND, UINT, WPARAM, LPARAM);

typedef struct tagPOINT {
  LONG x;
  LONG y;
} POINT;

typedef struct tagMSG {
  HWND   hwnd;
  UINT   message;
  WPARAM wParam;
  LPARAM lParam;
  DWORD  time;
  POINT  pt;
  DWORD  lPrivate;
} MSG;

typedef struct tagRECT {
  LONG left;
  LONG top;
  LONG right;
  LONG bottom;
} RECT;

typedef struct tagWNDCLASSEXA {
  UINT      cbSize;
  UINT      style;
  WNDPROC   lpfnWndProc;
  int       cbClsExtra;
  int       cbWndExtra;
  HINSTANCE hInstance;
  HICON     hIcon;
  HCURSOR   hCursor;
  HBRUSH    hbrBackground;
  LPCSTR    lpszMenuName;
  LPCSTR    lpszClassName;
  HICON     hIconSm;
} WNDCLASSEXA;

HINSTANCE GetModuleHandleA(LPCSTR lpModuleName);

ATOM RegisterClassExA(const WNDCLASSEXA *unnamedParam1);

HWND CreateWindowExA(
  DWORD     dwExStyle,
  LPCSTR    lpClassName,
  LPCSTR    lpWindowName,
  DWORD     dwStyle,
  int       X,
  int       Y,
  int       nWidth,
  int       nHeight,
  HWND      hWndParent,
  HMENU     hMenu,
  HINSTANCE hInstance,
  void*     lpParam
);

BOOL DestroyWindow(HWND hWnd);

BOOL ShowWindow(HWND hWnd, int nCmdShow);
BOOL UpdateWindow(HWND hWnd);

BOOL PeekMessageA(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
BOOL TranslateMessage(const MSG *lpMsg);
LRESULT DispatchMessageA(const MSG *lpMsg);

LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
void PostQuitMessage(int nExitCode);

HCURSOR LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);

BOOL GetClientRect(HWND hWnd, RECT *lpRect);

BOOL QueryPerformanceCounter(int64_t *lpPerformanceCount);
BOOL QueryPerformanceFrequency(int64_t *lpFrequency);

void Sleep(DWORD dwMilliseconds);

DWORD GetLastError(void);
]])

local user32 = ffi.load("user32")
local kernel32 = ffi.load("kernel32")

local M = {}

-- ============================================================
-- WinAPI constants
-- ============================================================

local WM_ERASEBKGND  = 0x0014
local WM_DESTROY      = 0x0002
local WM_SIZE         = 0x0005
local WM_CLOSE        = 0x0010
local WM_QUIT         = 0x0012

local WM_KEYDOWN      = 0x0100
local WM_KEYUP        = 0x0101

local WM_MOUSEMOVE    = 0x0200
local WM_LBUTTONDOWN  = 0x0201
local WM_LBUTTONUP    = 0x0202
local WM_RBUTTONDOWN  = 0x0204
local WM_RBUTTONUP    = 0x0205
local WM_MBUTTONDOWN  = 0x0207
local WM_MBUTTONUP    = 0x0208

local PM_REMOVE       = 0x0001

local WS_OVERLAPPED   = 0x00000000
local WS_CAPTION      = 0x00C00000
local WS_SYSMENU      = 0x00080000
local WS_THICKFRAME   = 0x00040000
local WS_MINIMIZEBOX  = 0x00020000
local WS_MAXIMIZEBOX  = 0x00010000
local WS_VISIBLE      = 0x10000000

local WS_OVERLAPPEDWINDOW =
  bor(
    WS_OVERLAPPED,
    WS_CAPTION,
    WS_SYSMENU,
    WS_THICKFRAME,
    WS_MINIMIZEBOX,
    WS_MAXIMIZEBOX
  )

local CW_USEDEFAULT = -2147483648
local SW_SHOW = 5

local COLOR_WINDOW = 5
local IDC_ARROW = 32512

-- ============================================================
-- State
-- ============================================================

local state = {
  hwnd = nil,
  app = nil,
  running = false,
  width = 0,
  height = 0,
}

-- Очень важно: callback должен жить, пока живёт окно.
-- Если LuaJIT GC его соберёт, WinAPI потом прыгнет в мёртвый адрес.
local wndproc_callback = nil

-- ============================================================
-- Helpers
-- ============================================================

local function get_x_lparam(lparam)
  local v = band(tonumber(lparam), 0xFFFF)
  if v >= 0x8000 then
    v = v - 0x10000
  end
  return v
end

local function get_y_lparam(lparam)
  local v = band(rshift(tonumber(lparam), 16), 0xFFFF)
  if v >= 0x8000 then
    v = v - 0x10000
  end
  return v
end

local function get_width_lparam(lparam)
  return band(tonumber(lparam), 0xFFFF)
end

local function get_height_lparam(lparam)
  return band(rshift(tonumber(lparam), 16), 0xFFFF)
end

local function get_client_size(hwnd)
  local rect = ffi.new("RECT")
  user32.GetClientRect(hwnd, rect)

  return {
    width = tonumber(rect.right - rect.left),
    height = tonumber(rect.bottom - rect.top),
  }
end

local function now_seconds()
  local counter = ffi.new("int64_t[1]")
  local freq = ffi.new("int64_t[1]")

  kernel32.QueryPerformanceCounter(counter)
  kernel32.QueryPerformanceFrequency(freq)

  return tonumber(counter[0]) / tonumber(freq[0])
end

local function quit()
  if state.hwnd ~= nil then
    user32.DestroyWindow(state.hwnd)
  else
    user32.PostQuitMessage(0)
  end
end

M.quit = quit

-- ============================================================
-- Window procedure
-- ============================================================

local function wndproc(hwnd, msg, wparam, lparam)
  local app = state.app

  if msg == WM_ERASEBKGND then
    return 1
  end

  if msg == WM_SIZE then
    local width = get_width_lparam(lparam)
    local height = get_height_lparam(lparam)

    state.width = width
    state.height = height

    if app and app.resize then
      app.resize(width, height)
    end

    return 0
  end

  if msg == WM_KEYDOWN then
    local vk = tonumber(wparam)

    input._key_down(vk)

    if app and app.key_down then
      local result = app.key_down(vk)

      if result == "quit" then
        quit()
      end
    end

    return 0
  end

  if msg == WM_KEYUP then
    local vk = tonumber(wparam)

    input._key_up(vk)

    if app and app.key_up then
      app.key_up(vk)
    end

    return 0
  end

  if msg == WM_MOUSEMOVE then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_move(x, y)

    if app and app.mouse_move then
      app.mouse_move(x, y)
    end

    return 0
  end

  if msg == WM_LBUTTONDOWN then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_down("left", x, y)

    if app and app.mouse_down then
      app.mouse_down("left", x, y)
    end

    return 0
  end

  if msg == WM_LBUTTONUP then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_up("left", x, y)

    if app and app.mouse_up then
      app.mouse_up("left", x, y)
    end

    return 0
  end

  if msg == WM_RBUTTONDOWN then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_down("right", x, y)

    if app and app.mouse_down then
      app.mouse_down("right", x, y)
    end

    return 0
  end

  if msg == WM_RBUTTONUP then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_up("right", x, y)

    if app and app.mouse_up then
      app.mouse_up("right", x, y)
    end

    return 0
  end

  if msg == WM_MBUTTONDOWN then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_down("middle", x, y)

    if app and app.mouse_down then
      app.mouse_down("middle", x, y)
    end

    return 0
  end

  if msg == WM_MBUTTONUP then
    local x = get_x_lparam(lparam)
    local y = get_y_lparam(lparam)

    input._mouse_up("middle", x, y)

    if app and app.mouse_up then
      app.mouse_up("middle", x, y)
    end

    return 0
  end

  if msg == WM_CLOSE then
    user32.DestroyWindow(hwnd)
    return 0
  end

  if msg == WM_DESTROY then
    state.running = false

    if app and app.shutdown then
      app.shutdown()
    end

    user32.PostQuitMessage(0)
    return 0
  end

  return user32.DefWindowProcA(hwnd, msg, wparam, lparam)
end

-- ============================================================
-- Main entry
-- ============================================================

function M.run(config)
  config = config or {}

  local app = config.app or {}
  local title = config.title or "LuaJIT WinAPI Window"
  local width = config.width or 1280
  local height = config.height or 720

  state.app = app
  state.width = width
  state.height = height

  local class_name = config.class_name or "LuaJIT_FFI_Window_Class"

  local hinstance = kernel32.GetModuleHandleA(nil)

  wndproc_callback = ffi.cast("WNDPROC", wndproc)

  local wc = ffi.new("WNDCLASSEXA")
  wc.cbSize = ffi.sizeof(wc)
  wc.style = 0
  wc.lpfnWndProc = wndproc_callback
  wc.cbClsExtra = 0
  wc.cbWndExtra = 0
  wc.hInstance = hinstance
  wc.hIcon = nil
  wc.hCursor = user32.LoadCursorA(nil, ffi.cast("LPCSTR", IDC_ARROW))
  wc.hbrBackground = ffi.cast("HBRUSH", COLOR_WINDOW + 1)
  wc.lpszMenuName = nil
  wc.lpszClassName = class_name
  wc.hIconSm = nil

  local atom = user32.RegisterClassExA(wc)

  if atom == 0 then
    local err = kernel32.GetLastError()

    -- 1410 = ERROR_CLASS_ALREADY_EXISTS
    -- Это не страшно, если вдруг класс уже был зарегистрирован.
    if err ~= 1410 then
      error("RegisterClassExA failed, GetLastError = " .. tostring(err))
    end
  end

  local hwnd = user32.CreateWindowExA(
    0,
    class_name,
    title,
    bor(WS_OVERLAPPEDWINDOW, WS_VISIBLE),
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    width,
    height,
    nil,
    nil,
    hinstance,
    nil
  )

  if hwnd == nil then
    local err = kernel32.GetLastError()
    error("CreateWindowExA failed, GetLastError = " .. tostring(err))
  end

  state.hwnd = hwnd
  state.running = true

  user32.ShowWindow(hwnd, SW_SHOW)
  user32.UpdateWindow(hwnd)

  local client = get_client_size(hwnd)
  state.width = client.width
  state.height = client.height

  if app.init then
    app.init({
      hwnd = hwnd,
      width = client.width,
      height = client.height,
      quit = quit,
    })
  end

  local msg = ffi.new("MSG")
  local last_time = now_seconds()

  while state.running do
    while user32.PeekMessageA(msg, nil, 0, 0, PM_REMOVE) ~= 0 do
      if msg.message == WM_QUIT then
        state.running = false
        break
      end

      user32.TranslateMessage(msg)
      user32.DispatchMessageA(msg)
    end

    if not state.running then
      break
    end

    local current_time = now_seconds()
    local dt = current_time - last_time
    last_time = current_time

    if app.update then
      local result = app.update(dt)

      if result == "quit" then
        quit()
      end
    end

    if app.render then
      app.render()
    end

    input._end_frame()

    -- Чтобы пока не жрать 100% CPU.
    -- Потом можно заменить на нормальный frame pacing / vsync.
    kernel32.Sleep(1)
  end

  if wndproc_callback ~= nil then
    wndproc_callback:free()
    wndproc_callback = nil
  end
end

return M
