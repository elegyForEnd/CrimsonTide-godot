@echo off
rem Crimson Tide - source launcher.
rem
rem Since 2026-10-12 the resource import and the class-cache guard run INSIDE the
rem game (the launcher screen in scripts/boot.gd): the player gets a progress bar
rem over the looping PV instead of a console window, and a stale cache is repaired
rem there too. So the default path below just starts the game.
rem
rem Flags:
rem   (none)         start the game; the in-game launcher does the checking
rem   --check        run tools/check_class_cache.ps1 -ImportResources first (dev/CI)
rem   --import-only  run that check and exit without starting the game
rem
rem Keep this file pure ASCII with CRLF line endings: cmd.exe reads .cmd files
rem through the OEM code page (cp936 here), and non-ASCII comments corrupt its
rem line parsing. Chinese notes live in PROJECT-GUIDE.md.
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

if /i "%~1"=="--check" goto check
if /i "%~1"=="--import-only" goto check
goto run

:check
set "CHECK=%CD%\tools\check_class_cache.ps1"
if not exist "%CHECK%" (
  echo [error] Missing tools\check_class_cache.ps1
  pause
  exit /b 2
)

set "PS=pwsh"
where pwsh >nul 2>&1
if errorlevel 1 set "PS=powershell"

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%CHECK%" -ProjectPath "%CD%" -ImportResources

if errorlevel 1 (
  echo [error] Resource setup failed. See the messages above.
  pause
  exit /b 2
)

if /i "%~1"=="--import-only" (
  echo [setup] --import-only requested, not starting the game.
  exit /b 0
)

:run
echo [run] Starting %NAME% ...
start "%NAME%" "%GODOT%" --path .
exit /b 0
