local M = {}

function M.run_window_test(name, duration_seconds, test_fn, options)
  options = options or {}
  duration_seconds = duration_seconds or 10

  local window = require("window")
  local survived = false

  local app = {
    width = options.width or 320,
    height = options.height or 240,
    elapsed = 0,
    last_heartbeat = 0,
    heartbeat_interval = options.heartbeat_interval or 1,
    failed = false,
  }

  function app.init(ctx)
    print("[TEST " .. name .. "] init start")

    local ok, err = pcall(function()
      test_fn("init", app, ctx)
    end)

    if not ok then
      print("[TEST " .. name .. "] FAILED in init:", err)
      app.failed = true
      return "quit"
    end

    print("[TEST " .. name .. "] init OK")
  end

  function app.resize(width, height)
    app.width = width
    app.height = height
  end

  function app.update(dt)
    app.elapsed = app.elapsed + dt

    local ok, err = pcall(function()
      test_fn("frame", app, nil, dt)
    end)

    if not ok then
      print("[TEST " .. name .. "] FAILED in frame:", err)
      app.failed = true
      return "quit"
    end

    -- Heartbeat каждые heartbeat_interval секунд.
    if app.elapsed - app.last_heartbeat >= app.heartbeat_interval then
      app.last_heartbeat = app.elapsed
      print("[TEST " .. name .. "] alive  " .. string.format("%.1f", app.elapsed) .. "s")
    end

    -- Достигли длительности → успех.
    if app.elapsed >= duration_seconds then
      survived = true
      return "quit"
    end
  end

  function app.render()
    local ok, err = pcall(function()
      test_fn("render", app, nil)
    end)

    if not ok then
      print("[TEST " .. name .. "] FAILED in render:", err)
      app.failed = true
    end
  end

  function app.shutdown()
    if survived then
      print("[TEST " .. name .. "] PASSED  " .. string.format("%.1f", app.elapsed) .. "s")
    else
      print("[TEST " .. name .. "] FAILED  " .. string.format("%.1f", app.elapsed) .. "s")
    end

    pcall(function()
      test_fn("shutdown", app, nil)
    end)
  end

  window.run({
    title = "test: " .. name,
    width = app.width,
    height = app.height,
    app = app,
  })
end

return M
