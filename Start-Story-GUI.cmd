@echo off
cd /d "%~dp0"
if exist "dist\CrimsonTide-ForwardPlus-v10.exe" (
  start "Crimson Tide" "dist\CrimsonTide-ForwardPlus-v10.exe" -- --skip-intro
) else (
  start "Crimson Tide" "Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --skip-intro
)
