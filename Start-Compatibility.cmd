@echo off
setlocal
cd /d "%~dp0"
start "Crimson Tide Compatibility" "Godot_v4.7.2-stable_win64.exe" --path . --rendering-method gl_compatibility
