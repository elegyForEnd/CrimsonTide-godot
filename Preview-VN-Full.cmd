@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "APPDATA=%~dp0.testappdata"
if exist "dist\CrimsonTide-ForwardPlus-v14.exe" (
    "%~dp0dist\CrimsonTide-ForwardPlus-v14.exe" -- --vn-full-gallery
) else (
    "%~dp0Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." --rendering-method forward_plus --script tools/preview_vn_full.gd
)
