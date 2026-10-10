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
echo Act 1: 5 Chapel, 6 Cloister, 7 Mine, 8 Tomb, 9 Castle
echo Act 2: 3 Workshop, 4 Archive, 6 Tribunal, 7 Foundry, 8 Cistern
echo Act 3: 3 Mine, 5 Tower, 7 Observatory, 8 Mausoleum
echo Act 4: 2 Estate, 3 Cloister, 5 Tomb, 6 Theatre, 7 Greenhouse, 8 Gallery
echo Act 5: 4 Flooded ruins, 6 Lighthouse, 7 Shipyard, 8 Pump room
echo Act 6: 2 Basilica, 4 Scriptorium, 5 Necropolis, 6 Cloister, 7 Reliquary, 8 Orrery
choice /c 23456789 /n /m "Choose a stage [2-9]; 7 = main showcase: "
if errorlevel 9 exit /b 1
set /a "storyPreviewStage=%errorlevel%+1"
set "storyPreviewExe=CrimsonTide-ForwardPlus-v7.exe"
if not exist "%storyPreviewExe%" set "storyPreviewExe=dist\CrimsonTide-ForwardPlus-v7.exe"
if not exist "%storyPreviewExe%" exit /b 1
start "Crimson Tide Dungeon Preview" "%storyPreviewExe%" -- --preview-story --story-act=%storyPreviewAct% --story-stage=%storyPreviewStage%
