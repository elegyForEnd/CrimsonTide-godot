extends RefCounted
## 窗口模式与窗口尺寸（全屏 / 分辨率档位 / 玩家手拖的尺寸）。
##
## 为什么单独一个文件、而且不写 `class_name`：
## 这套设置必须由**启动器**（`boot.gd`，它跑在主场景之前、而且必须能在
## `.godot/` 还没导入的首次下载里活下来）和**设置页**（`main.gd`）共用一份真值。
## 而首次下载时 `global_script_class_cache.cfg` 是空的，任何依赖全局类名的脚本
## 都可能解析失败，所以这里刻意做到零依赖：没有 `class_name`、不 preload 别的
## 脚本、不碰任何贴图。
##
## 真值的写入点仍然只有一个：`profile.gd` 的 `save_profile()`。本文件只负责
## 「键名 + 默认值 + 怎么应用到窗口」，所以 `profile.gd` 的 `data` 字面量里那几个
## 键（`fullscreen` / `window_preset` / `window_w` / `window_h`）改名时，这里必须同步。

const PROFILE_PATH := "user://profile.json"

## 首次下载默认全屏；玩家在设置页改过之后，下一次启动就继承玩家的选择
## （`profile.gd` 的 `data` 里那个 `fullscreen` 默认值必须与这里一致）。
const DEFAULT_FULLSCREEN := true
const DEFAULT_WINDOW := Vector2i(1600,900)

## 设置页给出的窗口分辨率档位。`FOLLOW_DESKTOP` 不是固定尺寸：每次启动按当前
## 屏幕可用区域现算，所以玩家换显示器/换分辨率也不会跑到屏幕外面去。
const PRESETS: Array[Vector2i] = [
	Vector2i(1280,720),
	Vector2i(1600,900),
	Vector2i(1920,1080),
	Vector2i(2560,1440),
]
const FOLLOW_DESKTOP := 4
## 玩家用鼠标拖出来的尺寸：存的是具体像素，`window_preset` 记成这个值。
const CUSTOM := -1
const MIN_WINDOW := Vector2i(960,540)

## 窗口控制的豁免开关：命中任意一条就**完全不碰窗口**。
## - `--headless` 没有窗口；
## - `--script`（`tools/run_all_tests.ps1` 的每一个用例）自己管几何，回归测试
##   依赖 1440×900 之类的固定窗口，不能被这里的全屏默认值掀翻；
## - 命令行上显式给了窗口参数（`-w` / `-f` / `--resolution` …）时那是玩家的最后
##   一句话，优先级高于存档。
const CLI_WINDOW_FLAGS := ["-w","--windowed","-f","--fullscreen","-m","--maximized","--resolution","--position"]

static func skip_window_control() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var args := OS.get_cmdline_args()
	if "--script" in args:
		return true
	for flag in CLI_WINDOW_FLAGS:
		if flag in args:
			return true
	return false

static func screen_usable() -> Vector2i:
	var size := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	if size.x <= 0 or size.y <= 0:
		size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	if size.x <= 0 or size.y <= 0:
		return DEFAULT_WINDOW
	return size

static func clamp_size(value: Vector2i, screen: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(value.x,MIN_WINDOW.x,maxi(MIN_WINDOW.x,screen.x)),
		clampi(value.y,MIN_WINDOW.y,maxi(MIN_WINDOW.y,screen.y))
	)

static func preset_label(index: int) -> String:
	if index == FOLLOW_DESKTOP:
		return "跟随桌面"
	if index >= 0 and index < PRESETS.size():
		return "%d×%d" % [PRESETS[index].x,PRESETS[index].y]
	return "自定义"

## 档位解析成真实像素；`CUSTOM` 走调用方存下来的 `window_w`/`window_h`。
static func preset_size(index: int, screen: Vector2i) -> Vector2i:
	if index == FOLLOW_DESKTOP:
		return clamp_size(screen,screen)
	if index >= 0 and index < PRESETS.size():
		return clamp_size(PRESETS[index],screen)
	return DEFAULT_WINDOW

## 从存档里读出窗口设置。存档不存在（首次下载）时返回默认值——**不是**返回空，
## 因为启动器必须能只靠这个函数决定首次启动就是全屏。
## `path` 可覆盖：回归测试用它指向一份临时档，免得去动玩家真正的 profile.json。
static func read_saved(path: String = PROFILE_PATH) -> Dictionary:
	var out := {
		"fullscreen": DEFAULT_FULLSCREEN,
		# `CUSTOM` rather than `FOLLOW_DESKTOP`: an old save that only ever stored
		# the fullscreen flag has no size to inherit, and handing that player a
		# desktop-sized window would be a surprise. `profile.gd`'s literal says the
		# same thing (see the note at the top of this file).
		"preset": CUSTOM,
		"w": DEFAULT_WINDOW.x,
		"h": DEFAULT_WINDOW.y,
	}
	if not FileAccess.file_exists(path):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return out
	if parsed.has("fullscreen") and parsed["fullscreen"] is bool:
		out["fullscreen"] = parsed["fullscreen"]
	if parsed.get("window_preset") is float or parsed.get("window_preset") is int:
		out["preset"] = int(parsed["window_preset"])
	if parsed.get("window_w") is float or parsed.get("window_w") is int:
		out["w"] = int(parsed["window_w"])
	if parsed.get("window_h") is float or parsed.get("window_h") is int:
		out["h"] = int(parsed["window_h"])
	return out

## 把一份设置应用到真实窗口。全屏就只切模式；窗口态则同时定尺寸并居中。
## 落定后打一行 `[window]`：玩家报"全屏没生效/窗口跑到屏幕外"时，这是唯一能一眼
## 看出"启动时到底应用了什么"的地方（本工程其它启动链也有这种单行诊断）。
static func apply(fullscreen: bool, preset: int, width: int, height: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("[window] 全屏")
		return
	var screen := screen_usable()
	var size := preset_size(preset,screen) if preset >= 0 else clamp_size(Vector2i(width,height),screen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
	print("[window] 窗口 %d×%d（%s，屏幕可用 %d×%d）" % [size.x,size.y,preset_label(preset),screen.x,screen.y])

## 启动器与主场景开头的统一入口：先过豁免开关，再按存档应用。
static func apply_saved() -> void:
	if skip_window_control():
		return
	var saved := read_saved()
	apply(bool(saved["fullscreen"]),int(saved["preset"]),int(saved["w"]),int(saved["h"]))

## 窗口尺寸与某个档位完全一致时返回该档位，否则返回 `CUSTOM`。
## 设置页用它高亮当前档位，拖拽尺寸写回时也用它判断"这还是不是某个档位"。
static func preset_for_size(size: Vector2i) -> int:
	for i in PRESETS.size():
		if PRESETS[i] == size:
			return i
	return CUSTOM
