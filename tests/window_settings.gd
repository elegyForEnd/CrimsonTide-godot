extends SceneTree

## 窗口设置（全屏/窗口 · 分辨率档位 · 玩家手拖的尺寸）回归。
##
## 这一套的真值分成三处，任何一处单独改都会让"设置页显示的"和"启动时应用的"
## 分叉，所以这里逐条钉住：
##   ① `profile.gd` 的 `data` 默认值 ↔ `window_settings.gd` 的常量（首次下载默认全屏）
##   ② 存档往返：JSON 读回来是 float，窗口键全是整数，走的是 `apply_data` 里那条
##      显式归一（§11.18 的坑），不归一就会被默认值冲掉
##   ③ 旧档（只有 `fullscreen` 一个键）不能崩、也不能被塞一个桌面尺寸的窗口
##   ④ 纯函数：档位标签 / 尺寸→档位 / 档位→尺寸（含屏幕夹取与越界兜底）
##
## 只读：临时档写在 `user://` 下一个专用文件名，跑完删掉，不碰 profile.json。

var checks := 0
var failures := 0

const WindowSettings = preload("res://scripts/window_settings.gd")
const TEST_PATH := "user://window-settings-test.json"

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# ① 默认值三处一致（首次下载 = 全屏）。
	var fresh := Profile.new()
	check(WindowSettings.DEFAULT_FULLSCREEN == true, "首次下载默认全屏")
	check(fresh.data.fullscreen == WindowSettings.DEFAULT_FULLSCREEN, "profile.gd 的 fullscreen 默认值与 window_settings.gd 一致")
	check(fresh.data.window_preset == WindowSettings.CUSTOM, "profile.gd 的 window_preset 默认值是 CUSTOM")
	check(Vector2i(int(fresh.data.window_w),int(fresh.data.window_h)) == WindowSettings.DEFAULT_WINDOW, "profile.gd 的窗口默认尺寸与 window_settings.gd 一致")

	# ② 缺文件 → 默认值（启动器在首次下载里只靠这一条决定全屏）。
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var missing := WindowSettings.read_saved(TEST_PATH)
	check(missing.fullscreen == WindowSettings.DEFAULT_FULLSCREEN, "存档不存在时读出默认全屏")
	check(int(missing.preset) == WindowSettings.CUSTOM, "存档不存在时读出 CUSTOM 档")
	check(Vector2i(int(missing.w),int(missing.h)) == WindowSettings.DEFAULT_WINDOW, "存档不存在时读出默认尺寸")

	# ③ 旧档：只有 fullscreen，没有三个新键。
	write_raw('{"version":1,"fullscreen":false}')
	var legacy := WindowSettings.read_saved(TEST_PATH)
	check(legacy.fullscreen == false, "旧档里的 fullscreen 被读出来")
	check(int(legacy.preset) == WindowSettings.CUSTOM, "旧档缺 window_preset 时按 CUSTOM 处理，不塞桌面尺寸")
	var legacy_profile := Profile.new()
	legacy_profile.path=TEST_PATH
	legacy_profile.load_profile()
	check(legacy_profile.data.fullscreen == false, "旧档的 fullscreen 过得了 apply_data")
	check(legacy_profile.data.window_preset == WindowSettings.CUSTOM, "旧档缺的窗口键走默认值")
	check(legacy_profile.data.window_w == WindowSettings.DEFAULT_WINDOW.x, "旧档缺的窗口宽度走默认值")

	# ④ 新档往返：整数键必须显式归一（JSON 是 float），否则每次启动都被默认值冲掉。
	var saved := Profile.new()
	saved.path=TEST_PATH
	saved.data.fullscreen=false
	saved.data.window_preset=2
	saved.data.window_w=1920
	saved.data.window_h=1080
	saved.save_profile()
	var back := WindowSettings.read_saved(TEST_PATH)
	check(back.fullscreen == false, "往返：全屏开关")
	check(int(back.preset) == 2, "往返：分辨率档位")
	check(int(back.w) == 1920 and int(back.h) == 1080, "往返：窗口尺寸")
	var reloaded := Profile.new()
	reloaded.path=TEST_PATH
	reloaded.load_profile()
	check(reloaded.data.window_preset == 2, "往返：档位过得了 apply_data 的类型匹配")
	check(reloaded.data.window_w == 1920 and reloaded.data.window_h == 1080, "往返：尺寸过得了 apply_data 的类型匹配")
	check(typeof(reloaded.data.window_w) == TYPE_INT, "往返：尺寸读回来是 int 而不是 float")

	# ⑤ 越界/脏数据被夹回合法区间，不会把窗口开到屏幕外面。
	write_raw('{"version":1,"window_preset":99,"window_w":999999,"window_h":1}')
	var dirty := Profile.new()
	dirty.path=TEST_PATH
	dirty.load_profile()
	check(dirty.data.window_preset == WindowSettings.FOLLOW_DESKTOP, "越界档位被夹到最大档")
	check(dirty.data.window_w == 16384 and dirty.data.window_h == 240, "越界窗口尺寸被夹到合法区间")

	# ⑥ 纯函数。
	check(WindowSettings.preset_label(WindowSettings.FOLLOW_DESKTOP) == "跟随桌面", "跟随桌面档的标签")
	check(WindowSettings.preset_label(0) == "1280×720", "档位 0 的标签就是它的像素")
	check(WindowSettings.preset_for_size(Vector2i(1920,1080)) == 2, "1920×1080 命中档位 2")
	check(WindowSettings.preset_for_size(Vector2i(1111,777)) == WindowSettings.CUSTOM, "非档位尺寸算自定义")
	check(WindowSettings.preset_size(WindowSettings.CUSTOM,Vector2i(3840,2160)) == WindowSettings.DEFAULT_WINDOW, "CUSTOM 档的兜底尺寸")
	check(WindowSettings.preset_size(WindowSettings.FOLLOW_DESKTOP,Vector2i(2560,1440)) == Vector2i(2560,1440), "跟随桌面就是屏幕可用区域")
	check(WindowSettings.preset_size(3,Vector2i(1920,1080)) == Vector2i(1920,1080), "档位比屏幕大时被夹到屏幕内")
	check(WindowSettings.preset_size(0,Vector2i(800,600)) == Vector2i(960,600), "屏幕偏小时被夹进屏幕（宽触到最小窗口、高触到屏幕）")
	check(WindowSettings.preset_size(0,Vector2i(320,240)) == WindowSettings.MIN_WINDOW, "屏幕比最小窗口还小时取最小窗口，不会算出负数尺寸")
	check(WindowSettings.preset_size(0,Vector2i(3840,2160)) == Vector2i(1280,720), "屏幕足够大时档位原样返回")

	# ⑦ 豁免开关：本用例是 `--script` 运行，必须豁免（否则回归会去动窗口几何）。
	check(WindowSettings.skip_window_control(), "--script 回归运行必须豁免窗口控制")

	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	await process_frame
	print("WINDOW SETTINGS ", checks, " checks / ", failures, " failures")
	quit(1 if failures else 0)
