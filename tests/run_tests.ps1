param(
  [string]$LuaJit = "D:\Prog\LuaJit\luajit.exe"
)

$ErrorActionPreference = "Continue"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$tests = @(
  "tests/test_00_boot.lua",
  "tests/test_01_loader_probe.lua",
  "tests/test_02_texture_create.lua",
  "tests/test_03_shader_compute_compile.lua",
  "tests/test_04_compute_dispatch.lua",
  "tests/test_10_resize_before_init.lua"
)

Write-Host "Project root: $Root"
Write-Host "LuaJIT: $LuaJit"
Write-Host ""

foreach ($test in $tests) {
  Write-Host "========================================"
  Write-Host "RUN $test"
  Write-Host "========================================"

  $p = Start-Process `
    -FilePath $LuaJit `
    -ArgumentList $test `
    -WorkingDirectory $Root `
    -NoNewWindow `
    -PassThru `
    -Wait

  Write-Host "EXIT CODE: $($p.ExitCode)"
  Write-Host ""
}
