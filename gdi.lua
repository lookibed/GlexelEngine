local ffi = require("ffi")
local bit = require("bit")

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift

-- Типы HANDLE, HWND, RECT, BYTE, WORD, UINT, DWORD, BOOL, LONG, LPCSTR, LONG_PTR уже определены в window.lua
ffi.cdef [[
typedef void* HDC;
typedef void* HGDIOBJ;
typedef unsigned long DWORD_PTR;

typedef struct tagBITMAPINFOHEADER {
  DWORD biSize;
  LONG  biWidth;
  LONG  biHeight;
  WORD  biPlanes;
  WORD  biBitCount;
  DWORD biCompression;
  DWORD biSizeImage;
  LONG  biXPelsPerMeter;
  LONG  biYPelsPerMeter;
  DWORD biClrUsed;
  DWORD biClrImportant;
} BITMAPINFOHEADER;

typedef struct tagRGBQUAD {
  BYTE rgbBlue;
  BYTE rgbGreen;
  BYTE rgbRed;
  BYTE rgbReserved;
} RGBQUAD;

typedef struct tagBITMAPINFO {
  BITMAPINFOHEADER bmiHeader;
  RGBQUAD          bmiColors[1];
} BITMAPINFO;

HDC GetDC(HWND hWnd);
int ReleaseDC(HWND hWnd, HDC hDC);

int StretchDIBits(
  HDC hdc,
  int xDest,
  int yDest,
  int DestWidth,
  int DestHeight,
  int xSrc,
  int ySrc,
  int SrcWidth,
  int SrcHeight,
  const void *lpBits,
  const BITMAPINFO *lpbmi,
  UINT iUsage,
  DWORD rop
);
]]

local user32 = ffi.load("user32")
local gdi32 = ffi.load("gdi32")

local M = {}

local BI_RGB = 0
local DIB_RGB_COLORS = 0
local SRCCOPY = 0x00CC0020

local renderer = {
  hwnd = nil,
  width = 0,
  height = 0,
  info = nil,
  pixels = nil,
}

local function color_u32(r, g, b)
  return bor(lshift(r, 16), lshift(g, 8), b)
end

M.rgb = color_u32

function M.init(hwnd, width, height)
  renderer.hwnd = hwnd
  M.resize(width, height)
end

function M.resize(width, height)
  width = math.max(1, math.floor(width or 1))
  height = math.max(1, math.floor(height or 1))

  renderer.width = width
  renderer.height = height

  local info = ffi.new("BITMAPINFO")
  info.bmiHeader.biSize = ffi.sizeof("BITMAPINFOHEADER")
  info.bmiHeader.biWidth = width
  info.bmiHeader.biHeight = -height
  info.bmiHeader.biPlanes = 1
  info.bmiHeader.biBitCount = 32
  info.bmiHeader.biCompression = BI_RGB
  info.bmiHeader.biSizeImage = width * height * 4
  info.bmiHeader.biXPelsPerMeter = 0
  info.bmiHeader.biYPelsPerMeter = 0
  info.bmiHeader.biClrUsed = 0
  info.bmiHeader.biClrImportant = 0

  renderer.info = info
  renderer.pixels = ffi.new("uint32_t[?]", width * height)
end

function M.width()
  return renderer.width
end

function M.height()
  return renderer.height
end

function M.clear(color)
  local pixels = renderer.pixels
  local count = renderer.width * renderer.height

  for i = 0, count - 1 do
    pixels[i] = color
  end
end

function M.rect(x, y, w, h, color)
  local width = renderer.width
  local height = renderer.height
  local pixels = renderer.pixels

  x = math.floor(x)
  y = math.floor(y)
  w = math.floor(w)
  h = math.floor(h)

  local x0 = math.max(0, x)
  local y0 = math.max(0, y)
  local x1 = math.min(width, x + w)
  local y1 = math.min(height, y + h)

  if x1 <= x0 or y1 <= y0 then
    return
  end

  for py = y0, y1 - 1 do
    local row = py * width

    for px = x0, x1 - 1 do
      pixels[row + px] = color
    end
  end
end

function M.pixel(x, y, color)
  x = math.floor(x)
  y = math.floor(y)

  if x < 0 or y < 0 or x >= renderer.width or y >= renderer.height then
    return
  end

  renderer.pixels[y * renderer.width + x] = color
end

function M.present()
  local hwnd = renderer.hwnd
  local width = renderer.width
  local height = renderer.height

  if hwnd == nil or renderer.pixels == nil then
    return
  end

  local hdc = user32.GetDC(hwnd)

  gdi32.StretchDIBits(
    hdc,
    0,
    0,
    width,
    height,
    0,
    0,
    width,
    height,
    renderer.pixels,
    renderer.info,
    DIB_RGB_COLORS,
    SRCCOPY
  )

  user32.ReleaseDC(hwnd, hdc)
end

function M.shutdown()
  renderer.hwnd = nil
  renderer.width = 0
  renderer.height = 0
  renderer.info = nil
  renderer.pixels = nil
end

return M
