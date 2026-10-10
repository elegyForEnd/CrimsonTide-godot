@echo off
cd /d "%~dp0"
if exist "dist\CrimsonTide-ForwardPlus-v10.exe" (
  start "Crimson Tide Quests" "dist\CrimsonTide-ForwardPlus-v10.exe" -- --preview-story --story-act=1 --story-stage=0 --preview-items --preview-quests
) else (
  start "Crimson Tide Quests" "Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -- --preview-story --story-act=1 --story-stage=0 --preview-items --preview-quests
)
