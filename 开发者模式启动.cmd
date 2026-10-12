@echo off
rem ===========================================================================
rem  Crimson Tide - developer mode launcher (judgement-range overlay).
rem
rem  Same chain as Start-Game.cmd: class-cache guard, resource import, launch.
rem  The only difference is CRIMSON_DEV_RANGES=all, which makes main.gd create
rem  scripts/dev_ranges.gd. Without that variable the overlay node is never
rem  built at all.
rem
rem  KEEP THIS FILE PURE ASCII WITH CRLF LINE ENDINGS.
rem  cmd.exe reads .cmd files through the OEM code page (cp936 here). Non-ASCII
rem  bytes corrupt its line parsing: a multi-byte character swallows the
rem  following LF, merges the next line into the current one, drops the "set"
rem  and feeds comment text into the callee as arguments. The previous
rem  UTF-8/LF version of this file did exactly that (2026-10-11) - the overlay
rem  never actually turned on. Chinese notes: KAIFAZHEMOSHI.md.
rem ===========================================================================
setlocal
cd /d "%~dp0"

set "CORE=%CD%\Start-Game.cmd"
if not exist "%CORE%" (
  echo [error] Missing Start-Game.cmd next to this launcher.
  echo [error] Expected: %CORE%
  pause
  exit /b 2
)

set "CRIMSON_DEV_RANGES=all"

rem Self-check: the variable has to survive into a child process, because that
rem is exactly what the launch below relies on. A silently skipped "set" is the
rem bug that shipped in the UTF-8 version of this file.
cmd /c "if not defined CRIMSON_DEV_RANGES exit 1"
if errorlevel 1 (
  echo [error] CRIMSON_DEV_RANGES did not reach the child environment.
  pause
  exit /b 3
)

echo [dev] CRIMSON_DEV_RANGES=%CRIMSON_DEV_RANGES% - judgement-range overlay on
echo [dev] chain: class-cache guard -^> import -^> launch (same as Start-Game.cmd)

call "%CORE%" %*
set "RC=%errorlevel%"
endlocal & exit /b %RC%
