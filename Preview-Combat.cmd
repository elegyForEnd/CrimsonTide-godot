@echo off
cd /d "%~dp0"
set "APPDATA=%~dp0.testappdata"
"%~dp0Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0" --rendering-method forward_plus --script tools/preview_combat_finish.gd
