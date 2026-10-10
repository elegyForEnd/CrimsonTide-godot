@echo off
cd /d "%~dp0"
echo 1 Cave / Castle   2 Foundry   3 Observatory
echo 4 Conservatory   5 Dry dock  6 Reliquary
choice /c 123456 /n /m "Choose an act [1-6]: "
if errorlevel 7 exit /b 1
if errorlevel 1 goto launch
exit /b 1
:launch
set "storyPreviewAct=%errorlevel%"
set "storyPreviewExe=CrimsonTide-ForwardPlus-v6.exe"
if not exist "%storyPreviewExe%" set "storyPreviewExe=dist\CrimsonTide-ForwardPlus-v6.exe"
if not exist "%storyPreviewExe%" exit /b 1
start "Crimson Tide Dungeon Preview" "%storyPreviewExe%" -- --preview-story --story-act=%storyPreviewAct% --story-stage=7
