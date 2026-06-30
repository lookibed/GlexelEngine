local M = {}

local keys_down = {}
local keys_pressed = {}
local keys_released = {}

local mouse_buttons_down = {}
local mouse_buttons_pressed = {}
local mouse_buttons_released = {}

local mx = 0
local my = 0

local key_names = {
  BACKSPACE = 0x08,
  TAB = 0x09,
  ENTER = 0x0D,
  SHIFT = 0x10,
  CTRL = 0x11,
  ALT = 0x12,
  ESC = 0x1B,
  SPACE = 0x20,

  LEFT = 0x25,
  UP = 0x26,
  RIGHT = 0x27,
  DOWN = 0x28,

  ["0"] = 0x30,
  ["1"] = 0x31,
  ["2"] = 0x32,
  ["3"] = 0x33,
  ["4"] = 0x34,
  ["5"] = 0x35,
  ["6"] = 0x36,
  ["7"] = 0x37,
  ["8"] = 0x38,
  ["9"] = 0x39,

  A = 0x41,
  B = 0x42,
  C = 0x43,
  D = 0x44,
  E = 0x45,
  F = 0x46,
  G = 0x47,
  H = 0x48,
  I = 0x49,
  J = 0x4A,
  K = 0x4B,
  L = 0x4C,
  M = 0x4D,
  N = 0x4E,
  O = 0x4F,
  P = 0x50,
  Q = 0x51,
  R = 0x52,
  S = 0x53,
  T = 0x54,
  U = 0x55,
  V = 0x56,
  W = 0x57,
  X = 0x58,
  Y = 0x59,
  Z = 0x5A,

  F1 = 0x70,
  F2 = 0x71,
  F3 = 0x72,
  F4 = 0x73,
  F5 = 0x74,
  F6 = 0x75,
  F7 = 0x76,
  F8 = 0x77,
  F9 = 0x78,
  F10 = 0x79,
  F11 = 0x7A,
  F12 = 0x7B,
}

local function resolve_key(key)
  if type(key) == "number" then
    return key
  end

  key = tostring(key):upper()

  return key_names[key]
end

local function normalize_mouse_button(button)
  button = tostring(button):lower()

  if button == "l" then
    return "left"
  elseif button == "r" then
    return "right"
  elseif button == "m" then
    return "middle"
  end

  return button
end

-- ============================================================
-- Query API
-- ============================================================

function M.down(key)
  local vk = resolve_key(key)
  return vk ~= nil and keys_down[vk] == true
end

function M.pressed(key)
  local vk = resolve_key(key)
  return vk ~= nil and keys_pressed[vk] == true
end

function M.released(key)
  local vk = resolve_key(key)
  return vk ~= nil and keys_released[vk] == true
end

function M.mouse_x()
  return mx
end

function M.mouse_y()
  return my
end

function M.mouse_pos()
  return mx, my
end

function M.mouse_down(button)
  button = normalize_mouse_button(button)
  return mouse_buttons_down[button] == true
end

function M.mouse_pressed(button)
  button = normalize_mouse_button(button)
  return mouse_buttons_pressed[button] == true
end

function M.mouse_released(button)
  button = normalize_mouse_button(button)
  return mouse_buttons_released[button] == true
end

-- ============================================================
-- Event feed from window.lua
-- ============================================================

function M._key_down(vk)
  if not keys_down[vk] then
    keys_pressed[vk] = true
  end

  keys_down[vk] = true
end

function M._key_up(vk)
  if keys_down[vk] then
    keys_released[vk] = true
  end

  keys_down[vk] = false
end

function M._mouse_move(x, y)
  mx = x
  my = y
end

function M._mouse_down(button, x, y)
  button = normalize_mouse_button(button)

  mx = x
  my = y

  if not mouse_buttons_down[button] then
    mouse_buttons_pressed[button] = true
  end

  mouse_buttons_down[button] = true
end

function M._mouse_up(button, x, y)
  button = normalize_mouse_button(button)

  mx = x
  my = y

  if mouse_buttons_down[button] then
    mouse_buttons_released[button] = true
  end

  mouse_buttons_down[button] = false
end

-- Вызывать один раз в конце каждого кадра.
function M._end_frame()
  for k in pairs(keys_pressed) do
    keys_pressed[k] = nil
  end

  for k in pairs(keys_released) do
    keys_released[k] = nil
  end

  for k in pairs(mouse_buttons_pressed) do
    mouse_buttons_pressed[k] = nil
  end

  for k in pairs(mouse_buttons_released) do
    mouse_buttons_released[k] = nil
  end
end

return M
