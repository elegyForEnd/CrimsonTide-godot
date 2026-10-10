@echo off
cd /d "%~dp0"
set "storyPreviewExe=CrimsonTide-ForwardPlus-v8.exe"
if not exist "%storyPreviewExe%" set "storyPreviewExe=dist\CrimsonTide-ForwardPlus-v8.exe"
if not exist "%storyPreviewExe%" exit /b 1
start "Crimson Tide Boundary Preview" "%storyPreviewExe%" -- --preview-story --story-act=1 --story-stage=2
