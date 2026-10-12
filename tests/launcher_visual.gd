extends SceneTree
## 启动器（boot.tscn）视觉回归：把每张画面存成 PNG，人眼可查 + 关键项自动断言。
##
## 覆盖：忠告（字体兜底）、PV、PV +「点击任意键开始游戏」、编译进度页（进度条 /
## 圆形静音 / 世界观文案）、重启确认卡、出错卡。
##
## ⚠️ 这个用例**不真跑导入**（那会拉起一个编辑器子进程）；它只搭界面出来拍照。
## 真的导入链路由 `tests/launcher_env.gd`（判定）+ 手工开窗验证负责。
##
## 最重要的一条断言是"PV 真的渲染出来了"：`boot.tscn` 的根是 CanvasLayer，PV 外面
## 套了一层 `CanvasGroup`（第二批水滴转场要靠它把整组一起上材质），而
## CanvasGroup 套 VideoStreamPlayer 是有兼容风险的组合——黑屏了必须在这里红。

var checks := 0
var failures := 0

const OUT := "res://build/launcher"

var boot: Node
var last_image: Image

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	last_image=root.get_texture().get_image()
	last_image.save_png("%s/%s.png" % [OUT,name])
	print("LAUNCHER SHOT ",name)

## 数一数"明显亮"的像素：用来判断画面到底是不是一片黑。
func bright_pixels(image: Image) -> int:
	var count := 0
	for y in range(0,image.get_height(),8):
		for x in range(0,image.get_width(),8):
			var color := image.get_pixel(x,y)
			if (color.r+color.g+color.b)/3.0>0.35:
				count+=1
	return count

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1440,900)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1440,900))
	var scene: PackedScene = load("res://scenes/boot.tscn")
	boot=scene.instantiate()
	root.add_child(boot)
	await create_timer(1.4).timeout
	shot("01-advice")
	check(bright_pixels(last_image)>50,"忠告画面画出来了（中文有字体可渲染）")

	# PV：先单独拍一张（不叠提示文字），验证 CanvasGroup 套 VideoStreamPlayer 能不能出画。
	boot._start_video()
	if boot.prompt!=null:
		boot.prompt.hide()
	await create_timer(2.6).timeout
	shot("02-video")
	check(bright_pixels(last_image)>150,"PV 真的渲染出来了（CanvasGroup 没把它吃掉）")

	# PV +「点击任意键开始游戏」
	boot._show_prompt()
	await create_timer(0.9).timeout
	shot("03-video-prompt")
	check(bright_pixels(last_image)>150,"提示文字叠在 PV 上仍然有画面")

	# 编译进度页：只搭界面，不拉子进程。这里必须停掉 `_process`——真的导入时它每
	# 0.35s 轮询一次子进程，而用例里根本没有子进程，第一次轮询就会把页面切成"完成"。
	boot._build_compile_ui()
	boot.set_process(false)
	boot.phase=boot.Phase.COMPILE
	boot.flavor_label.text=boot.FLAVOR[1]
	boot.stage_label.text="正在导入资源  ·  42%"
	boot.bar.set_ratio(0.42)
	boot._show_mute_button()
	boot._apply_mute()
	await create_timer(0.7).timeout
	shot("04-compile")
	check(bright_pixels(last_image)>150,"进度页画出来了")

	boot._toggle_mute()
	await create_timer(0.4).timeout
	shot("05-compile-muted")
	boot._toggle_mute()

	boot._build_confirm_card()
	await create_timer(0.5).timeout
	shot("06-confirm")

	boot._build_blocked_card("资源导入没有完成。","[setup] importing res://assets/...\n[error] Godot resource import failed (exit 1).")
	await create_timer(0.5).timeout
	shot("07-blocked")

	# 「点击任意键开始游戏」的两条硬要求（用户点名要的）：
	#   ① 点右上角那个圆形静音按钮只静音，**不能**顺带进游戏；
	#   ② 点空白处/按任意键才进游戏。
	# 用真鼠标事件走一遍完整输入链（`_unhandled_input` 收不到被 Button 消费掉的点击）。
	var graphics = root.get_node("/root/GraphicsQuality")
	var muted_before := bool(graphics.launcher_mute)
	boot.phase=boot.Phase.VIDEO

	# 「提前渲染」闸门（用户第 4 轮要求：把转场做成"编译着色器"的一部分）：
	# 点击**之前**，启动器必须已经做到三件事，否则点击会退回兜底的同步
	# `load(main.tscn)`（约 5.3s）+ 它的 `_ready()`（约 4.5s）——那就是"点击后卡几秒"。
	var waited := 0.0
	while not boot.prewarm_done and waited<25.0:
		await create_timer(0.1).timeout
		waited+=0.1
	check(boot.prewarm_done,"预热在超时前完成（等了 %.1fs）" % waited)
	check(boot.shader_warm,"水滴材质提前画过帧：GPU 管线在点击**之前**就编译好了")
	check(boot.login_ready,"登录页已提前挂好（点击时不用再 load + instantiate）")

	click_at(boot.mute.position + boot.mute.size*0.5)
	await create_timer(0.4).timeout
	check(bool(graphics.launcher_mute) != muted_before, "点圆形静音按钮切换了静音")
	check(boot.phase==boot.Phase.VIDEO, "点静音按钮没有顺带进游戏")
	# 给"点击→切场景"计时：预热生效时这里只做"抓图 + 复用材质 + 盖板"，不该有加载卡顿。
	var click_ms := Time.get_ticks_msec()
	click_at(Vector2(200,200))
	# 水滴转场：先抓一张启动器画面（等一帧 + 一次 GPU→CPU 回读），再把登录页挂到
	# 启动器层下面；然后靠扩散的圆把那张抓图擦掉。这里按时间点连拍，用来**实测**
	# "登录页什么时候能看清"——那个数就是 `boot.gd TRANSITION_SECONDS` 的来源。
	await create_timer(0.2).timeout
	click_ms=Time.get_ticks_msec()-click_ms
	check(current_scene!=null and String(current_scene.name)=="CrimsonTide",
		"点空白处立刻挂上了主场景（当前场景=%s）" % (String(current_scene.name) if current_scene else "null"))
	check(current_scene==boot.login_instance,"转场复用的是**预热好的那一份**登录页（没有重新 load）")
	check(click_ms<1500,"点击没有被同步加载卡住（点击→切场景实测 %dms）" % click_ms)
	check(is_instance_valid(boot) and boot.dissolving, "水滴转场正在演算")
	check(is_instance_valid(boot) and boot.video.is_playing(), "启动器层藏起来之后 PV 仍在播放（音频才淡得出来）")
	var elapsed := 0.2
	for mark in [0.4,0.6,0.8,1.0,1.2,1.4]:
		await create_timer(maxf(0.01,mark-elapsed)).timeout
		elapsed=mark
		shot("10-transition-%03d" % int(mark*1000.0))
	check(not is_instance_valid(boot), "转场收尾把启动器层整个释放了（不留每帧演算）")
	# 收尾彻底释放（用户原话）：抓图盖板是启动器专用的 layer=110，转场后 root 上不该再有它。
	# （不能用"layer>=100"来数：main.gd 自己的 cinema_layer 就是 100，会误报。）
	var overlay_left := 0
	for child in root.get_children():
		if child is CanvasLayer and child.layer==110:
			overlay_left+=1
	check(overlay_left==0,"转场收尾把抓图盖板从 root 上释放了（残留 %d）" % overlay_left)
	check(bright_pixels(last_image)>30, "转场结束后看得见登录页（不是一片黑）")
	graphics.set_launcher_mute(muted_before)

	print("LAUNCHER VISUAL ", checks, " checks / ", failures, " failures  -> ", OUT)
	quit(1 if failures else 0)

## 模拟一次真鼠标左键点击（按下+抬起），位置写进事件里，走完整输入链。
func click_at(at: Vector2) -> void:
	if DisplayServer.get_name()=="headless":
		return
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=at
		Input.parse_input_event(event)
