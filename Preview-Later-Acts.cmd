@echo off
cd /d "%~dp0"
echo Act 2: Foundry / Act 3: Observatory / Act 4: Rose estate
echo Act 5: Shipyard / Act 6: Reliquary
choice /c 23456 /n /m "Choose an act [2-6]: "
if errorlevel 6 exit /b 1
if errorlevel 1 goto launch
exit /b 1
:launch
set /a "storyPreviewAct=%errorlevel%+1"
set "storyPreviewExe=CrimsonTide-ForwardPlus-v7.exe"
if not exist "%storyPreviewExe%" set "storyPreviewExe=dist\CrimsonTide-ForwardPlus-v7.exe"
if not exist "%storyPreviewExe%" exit /b 1
start "Crimson Tide Art Preview" "%storyPreviewExe%" -- --preview-story --story-act=%storyPreviewAct% --story-stage=0
