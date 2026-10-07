@echo off
rem ============================================================================
rem  Crimson Tide - 开发者模式启动（判定框总览）
rem
rem  与 游戏启动.cmd 的唯一区别：先设环境变量 CRIMSON_DEV_RANGES=all 再走同一条启动链
rem  （同样的 Godot 类缓存守卫 + 同样的 Godot 可执行文件）。守卫与可执行文件的路径都在
rem  游戏启动.cmd 里，这里不复制第二份，避免两处漂移。
rem
rem  看到什么：当前已接入批次的判定框。第一批（魔境 2D 战场）：
rem    · 青色 主人索敌圈       SOUL_SEEK   = 300
rem    · 紫色 灵体索敌圈       SOUL_NEAR   = 166.7
rem    · 黄色 灵体射程         SOUL_RANGE  = 150
rem    · 橙色 灵体追击停靠     SOUL_KEEP   = 127.5
rem    · 绿色 角色地形判定半径 （ruins.gd move() 默认 15）
rem    · 红色 怪物半径 / 细红线 = 灵体的当前目标
rem    · F9 收起/展开文字标签
rem  其余批次（营地设施交互框、搜打撤 3D、房型与地形、UI 交互框）的清单与代码入口见
rem  工作区上一层（D:\dsh\Game\任务.md）。
rem
rem  正式游玩请用 游戏启动.cmd —— 不设这个环境变量时，判定框覆盖层**根本不会被创建**。
rem  Godot 侧读法：scripts/dev_ranges.gd 的 enabled()。
rem ============================================================================
setlocal
cd /d "%~dp0"
set "CRIMSON_DEV_RANGES=all"
echo [dev] CRIMSON_DEV_RANGES=all  -> 判定框总览已开启
call "%~dp0游戏启动.cmd" %*
endlocal
