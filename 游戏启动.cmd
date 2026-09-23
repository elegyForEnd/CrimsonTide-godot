@echo off
rem Crimson Tide - source launcher with a Godot class-cache guard.
rem
rem Why this exists:
rem Godot 4 keeps every "class_name" registration inside
rem .godot/global_script_class_cache.cfg, and .godot/ is gitignored. After a
rem "git pull" that adds brand new scripts, that cache goes stale, the main
rem scene script fails to parse with "Could not find type ...", and the game
rem shows a BLACK SCREEN right after the intro is skipped: the scene node
rem loads, but its script never attaches to it.
rem
rem This launcher verifies the cache against the scripts on disk, rebuilds it
rem headlessly with "godot --import" when they disagree, then starts the game.
rem
rem Pass --import-only to repair the cache without launching the game.
rem
rem Keep this file pure ASCII with CRLF line endings: cmd.exe reads .cmd files
rem through the OEM code page (cp936 here), and non-ASCII comments corrupt its
rem line parsing. The Chinese explanations live in tools/check_class_cache.ps1.
setlocal
cd /d "%~dp0"

set "NAME=Crimson Tide"
set "GODOT=%CD%\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" set "GODOT=%CD%\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo [error] Godot executable not found next to this launcher.
  echo [error] Expected Godot_v4.7.2-stable_win64_console.exe in:
  echo [error] %CD%
  pause
  exit /b 2
)

set "CHECK=%CD%\tools\check_class_cache.ps1"
if not exist "%CHECK%" (
  echo [error] Missing tools\check_class_cache.ps1
  pause
  exit /b 2
)

set "PS=pwsh"
where pwsh >nul 2>&1
if errorlevel 1 set "PS=powershell"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%CHECK%" -ProjectPath "%CD%"

if /i "%~1"=="--import-only" (
  echo [setup] --import-only requested, not starting the game.
  exit /b 0
)

echo [run] Starting %NAME% ...
start "%NAME%" "%GODOT%" --path .
exit /b 0
