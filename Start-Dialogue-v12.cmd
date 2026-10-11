@echo off
cd /d "%~dp0"
if exist "dist\CrimsonTide-ForwardPlus-v12.exe" (
    start "" "dist\CrimsonTide-ForwardPlus-v12.exe" -- --skip-intro
) else (
    start "" "Godot_v4.7.2-stable_win64.exe" --path "%~dp0" -- --skip-intro
)
