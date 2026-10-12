@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist "dist\CrimsonTide-ForwardPlus-v14.exe" (
    "%~dp0dist\CrimsonTide-ForwardPlus-v14.exe"
) else (
    "%~dp0Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." --rendering-method forward_plus
)
