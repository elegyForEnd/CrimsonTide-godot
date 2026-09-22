@echo off
rem 启动源码版血潮守望（含装备槽 / 双击装备 / R 旋转修复）。
rem dist/CrimsonTide.exe 是旧导出包，重新导出前请用本脚本验证。
cd /d "%~dp0"
start "" "Godot_v4.7.2-stable_win64_console.exe" --path .
