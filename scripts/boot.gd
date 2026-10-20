extends CanvasLayer
## 启动器（2026-10-12 起 boot 场景就是启动器）。
##
## 流程：健康忠告 →〔需要时〕环境自检/资源导入（PV 循环 + 进度条 + 圆形静音按钮 +
## 世界观文案轮播）→ 就绪 →「点击任意键开始游戏」→ 登录页。
##
## 这个文件有一批**硬约束**，改之前先读：
##  ① **不许引用任何全局类名**（`GothicButton`、`TideSession`、`Profile`…），也不许
##     preload 依赖全局类名的脚本。首次下载时 `.godot/global_script_class_cache.cfg`
##     还是空的，凡是走全局类名解析的代码都可能直接解析失败——而启动器恰恰要在
##     那一刻跑起来（它正是用来判断"要不要先导入"的那一个）。
##  ② **不许在 `boot.tscn` 里挂任何 ext_resource**（字体/贴图/视频）。首次下载时
##     `.godot/imported` 是空的，`.tscn` 的 ext_resource 加载失败会让**整个场景**
##     加载失败（黑屏）。字体在这里 `load()`、失败退系统字体；视频是原生读取的
##     `.ogv`，也在代码里 `load()`。
##  ③ **不许 preload `main.tscn`**（旧版 boot.gd 就是 preload 的）。类缓存过期时
##     main.gd 解析不了，preload 会让启动器自己都起不来；只能等自检通过后 `load()`。
##  ④ **布局一律按设计分辨率显式落**（`VIEW` = 1440×900，工程 stretch=canvas_items，
##     画布坐标恒为这一套）。实测：`.tscn` 里写的锚点放进 `CanvasGroup` 之后不可靠，
##     会把忠告整块推到屏幕左侧。
##  ⑤ 导入资源的子进程**只有编辑器二进制能跑**（`--import` 在 `--help` 里标 E），
##     而且导完之后**当前进程的类缓存已经过期**（全局类表是引擎启动时读一次的），
##     所以编译完成后必须重启一次进程——按用户要求，重启要玩家自己点确认。

enum Phase { ADVICE, VIDEO, COMPILE, CONFIRM, BLOCKED }

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SERIF_PATH := "res://assets/NotoSerifSC.ttf"
const VIDEO_PATH := "res://pv/pv.ogv"
const ADVICE_HOLD_SECONDS := 4.5
const FLAVOR_SECONDS := 4.0
const POLL_SECONDS := 0.35
## 进度条框尺寸：主条在上、子条在下，共用同一个描金框（用户要求：子条不单独加边框，
## 只把框高适配两行）。⚠️ 与 `scripts/launcher_bar.gd` 的 PAD/MAIN_H/GAP/SUB_H 是同
## 一套布局：11 + 25 + 6 + 8 = 50，余 12 为下留白。
const BAR_SIZE := Vector2(760,62)
## 子进度条的阶段顺序（同一时刻有多个阶段在推进时先显示谁；正确性不依赖它）。
## 引擎实际是**按资源类型分批**导入的，而且耗时极不均匀，见 `launcher_env.gd`
## `entry_counts_by_type()` 的注释与下面的 `_update_sub_progress()`。
const PHASE_ORDER := ["ctexarray","fontdata","scn","oggvorbisstr","sample","ctex"]
const PHASE_LABELS := {
	"ctexarray":"HDR 环境贴图",
	"ctex":"贴图",
	"scn":"模型与场景",
	"sample":"音效",
	"oggvorbisstr":"音乐",
	"fontdata":"字体",
}

## 供回归测试对账：进度条框高必须同时装下主条和子条（布局常量分散在两个文件里，
## 只改一边就会让子条挤出框外，而玩家只会看到"子条没了"）。
static func bar_frame_ok() -> bool:
	return BAR_SIZE.y>=Bar.needed_height()
# 忠告画面为了等预热最多多停多久。弱机上 `load(main.tscn)` + 它的 `_ready()` 要十秒级，
# 与其让 PV 卡住，不如让**静态**的忠告多停一会儿（玩家看不出静止画面多停了）；到点必须
# 放行，否则预热一旦卡死，闸门永远不开 = 玩家永远进不去。
const PREWARM_HOLD_MAX_SECONDS := 30.0
# 导入子进程的兜底超时（正常首次导入几分钟就完）。没有这条的话，万一子进程卡住，
# 玩家就只剩 Alt+F4 一条路；有这条才会翻出"重试/退出"卡片。
const IMPORT_TIMEOUT_SECONDS := 1200.0
# 设计分辨率：工程 stretch=canvas_items + viewport 1440×900，所以画布坐标恒为这一套，
# 下面所有位置直接按它写，不需要再做锚点换算。
const VIEW := Vector2(1440,900)

const Env := preload("res://scripts/launcher_env.gd")
const Bar := preload("res://scripts/launcher_bar.gd")
const MuteButton := preload("res://scripts/launcher_mute.gd")

# --- 进游戏时的"水滴擦除"转场（第二批） ---------------------------------------
const DISSOLVE_SHADER := "res://resources/launcher_dissolve.gdshader"
## 转场总时长。这个数是**实测**出来的：按帧截图看"登录页什么时候能看清"，取平均再加
## 余量；到点就把整套水滴演算清掉（用户要求，见 `_end_transition()`）。
const TRANSITION_SECONDS := 0.9
## 登录页的淡入时长（用户说"先 0.5 秒试试水"）。
const LOGIN_FADE_SECONDS := 0.5
const DROP_COUNT_MIN := 4
const DROP_COUNT_MAX := 5
## 圆心所在的那个中心圆：**面积**占屏幕 20%（用户拍板的口径）。
const DROP_REGION_AREA := 0.2
## 两滴之间最小间距，以那个中心圆的半径为 1（"互相不能生成太近"）。
const DROP_MIN_GAP := 0.55
## 半径上限，单位是"屏幕高度 = 1"：要够盖到离圆心最远的那个角（16:10 下算出来约 1.26）。
const MAX_DROP_RADIUS := 1.35

## 健康忠告的文案（原来放在 boot.tscn 里，随场景一起搬到代码：见硬约束②）。
## ⚠️ 忠告画面**不显示**"任意键跳过"这类提示行（用户要求：功能保留、前端别让玩家看见）：
## 跳过功能在 `_unhandled_input()` 里照旧生效，只是不给提示。
const ADVICE_TITLE := "健康游戏忠告"
const ADVICE_BODY := "抵制不良游戏，拒绝盗版游戏。\n注意自我保护，谨防受骗上当。\n适度游戏益脑，沉迷游戏伤身。\n合理安排时间，享受健康生活。"

## 编译期间轮播的世界观文案（用户要求：一行一句、结尾统一 `~`、只讲氛围不剧透
## 议会谎言/钟灭那条线）。术语取自 `血潮守望_CrimsonTide_PV/00_世界观与美术圣经.md`
## （守夜姬/血晶/钟影/钟门/血香/涨潮倒计时/晨钟城/影蚀之地）。
##
## ⚠️ **`~` 不是无条件的**（2026-10-19 用户第 2 轮）：`~` 是"轻松/日常/自嘲"的语气尾，
## 给预言、威胁、死亡意象加就变成了轻佻。所以规矩是：**氛围/日常句带 `~`，严肃句不带**。
## 下面三条刻意不带（用户点名的那一类），改文案时别再统一补回来：
##   · 鸦羽说，斩血潮者必先沾血   —— 谚语/血誓
##   · 血香散出去之后，异兽总会来 —— 威胁
##   · 白骨王座上的钟摆，有人正在拨动 —— 有人动了死者的东西
## `tests/launcher_progress.gd` 用 XOR 钉住这条规矩（带 `~` 的不能是严肃句，反之亦然）。
const FLAVOR: Array[String] = [
	"守夜姬正在整备装备~",
	"圣钟的影子，又缩了一小圈~",
	"血潮退去的地方，血晶还在发亮~",
	"终夜之钟的缺口，今天也没补上~",
	"影蚀之地的雾，还没散~",
	"钟摆还在走，先别让它停下~",
	"雪璃的圣歌，正在为钟声定调~",
	"鸦羽说，斩血潮者必先沾血",
	"钟门那边的暗金火光，一直亮着~",
	"血香散出去之后，异兽总会来",
	"涨潮倒计时，还没开始~",
	"白骨王座上的钟摆，有人正在拨动",
	"晨钟城的窗火，还醒着几盏~",
	"灰烬和血滴，在空气里浮着~",
	"装备一件件归位，别落下什么~",
]

var phase := Phase.ADVICE
var transitioning := false
var restarting := false
var env_report := {}
var import_pid := -1
var face: Font
var bold: Font
var dissolve: Control
var transition_overlay: CanvasLayer
var black: ColorRect
var advice: VBoxContainer
var video_frame: AspectRatioContainer
var video: VideoStreamPlayer
var compile_root: Control
## 编译页那块压暗 PV 的黑纱；单独留引用是因为窗口尺寸变了要跟着改大小。
var shade: ColorRect
var blocked_root: Panel
var confirm_root: Panel
var bar: Control
var stage_label: Label
## 子进度条下面那行小字：阶段名 + 已完成/总数 + 剩余时间。
var sub_label: Label
## 子进度条的阶段表：`[{key,label,total,done}]`，`_prepare_phases()` 在导入前建好。
var phases: Array = []
## 导入开始前各类型在 `.godot/imported` 里的条目数；`done = 现在 - 基线`。
var phase_baseline := {}
## 当前显示在子条上的阶段 key（没有阶段在推进时保持上一次的选择）。
var phase_pick := ""
var _last_entries := 0
var _entry_rate := 0.0
var _last_poll_at := 0.0
var flavor_label: Label
var mute: Button
var prompt: Label
var prompt_tween: Tween
var flavor_index := 0
var flavor_timer := 0.0
var poll_timer := 0.0
var compile_started := 0.0
# 水滴转场状态（演算用的数组在 `_end_transition()` 里会被清空）
var dissolving := false
var dissolve_elapsed := 0.0
var dissolve_warmup := false
var dissolve_material: ShaderMaterial
var drop_centers: Array[Vector2] = []
var drop_radii: Array[float] = []
var drop_speed: Array[float] = []
var drop_delay: Array[float] = []
# --- "提前渲染"（用户要求：把水滴转场做成"编译着色器"的一部分）---------------------
# 点击后卡几秒的真因**不是**水滴本身（转场演算只有约 12ms），而是点击那一刻才去做：
#   ① 水滴着色器第一次被用到 → GPU 才现编译这条管线；
#   ② `load(main.tscn)` 解析 main.gd 那张 preload 图（本机实测 5.3s）；
#   ③ `instantiate + add_child` 同步跑完 main.gd 的 `_ready()`（本机实测 4.5s）。
# 所以预热分三件事，全部提前到"玩家还在看开场"的时候做，点击那一刻只剩复用：
#   A. 水滴材质在 `_build_scene_ui()` 里就建好，并挂在一层被黑底盖住的满屏贴图上先画
#      两帧（`_shader_warm_setup()` / `_park_warm_plate()`）→ 管线提前编译，材质留着重用；
#   B. `load` 走后台线程（`load_threaded_request`），不占主线程；
#   C. 实例化 + `_ready()` 留在主线程但挪到待机期，挂到启动器层底下被盖住（见 `_prewarm_attach()`）。
# ⚠️ 闸门：预热没完成之前**不许放行**"点击任意键"（`prewarm_done`），否则玩家手快就会
#    走到 `_start_transition()` 的兜底同步 `load`——那正是要消灭的那几秒卡顿。
var login_ready := false
var login_instance: Node
var login_process_mode := Node.PROCESS_MODE_INHERIT
var prewarm_armed := false
var prewarm_done := false
var shader_warm := false
# 诊断用（与 `window_settings.gd` 的 `[window]` 同一风格）：把"预热花了多久 / 点击那一刻
# 只花了多久"打出来，弱机上再有人报"点击卡"，先看这两行就知道了。
var prewarm_started_ms := 0
var warm_plate: TextureRect
var prep_label: Label

func _ready() -> void:
	face=_resolve_face()
	bold=FontVariation.new()
	bold.base_font=face
	bold.variation_embolden=0.55
	_build_scene_ui()
	# 预览/截图/测试入口照旧直达游戏页：这是既有的开发链路（Preview-*.cmd、
	# run_all_tests.ps1 里的 *_visual 用例），不要动。
	var args := OS.get_cmdline_user_args()
	if "--skip-intro" in args or "--capture" in args or _has_preview_argument(args):
		# 开发/截图/测试入口**不走水滴转场**：那些链路要的是"立刻切到目标页"，
		# 淡入中途被截图抓到会让既有预览图整体变暗。
		_enter_game(false)
		return
	play_advice()
	# 自检与忠告并行：精确路径要读几千个小文件（本机实测 3.7s），藏在这段静态画面
	# 后面远比藏在"玩家等着进游戏"那一刻划算。
	_scan_env.call_deferred()

# --- 开场画面（全部代码构建） --------------------------------------------------

func _resolve_face() -> Font:
	if ResourceLoader.exists(SERIF_PATH):
		var loaded = load(SERIF_PATH)
		if loaded is Font:
			return loaded
	# 首次下载时字体还没导入：退到系统字体，否则启动器连一句中文都画不出来。
	var system := SystemFont.new()
	system.font_names=PackedStringArray([
		"Microsoft YaHei UI","Microsoft YaHei","SimHei","Noto Sans CJK SC","Source Han Sans SC","sans-serif"])
	ThemeDB.fallback_font=system
	return system

func _build_scene_ui() -> void:
	var view := get_viewport().get_visible_rect().size
	# 启动器 UI 的容器。**不是** `CanvasGroup`：那个在本版本（4.7.2 实测）继承的是
	# `Node2D` 而不是 `Control`（没有 size/mouse_filter，子 Control 用锚点会按 0×0 算），
	# 而且它的材质拿不到整组贴图（`texture(TEXTURE, UV)` 取到默认的 1×1 白贴图）。
	# 水滴转场因此改成"抓一张静态画面 + TextureRect + 着色器"，见 `_start_transition()`。
	dissolve=Control.new()
	dissolve.position=Vector2.ZERO
	dissolve.size=view
	dissolve.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(dissolve)
	# 建完容器立刻按**当前画布**落一次布局，并挂上窗口尺寸变化的重排
	# （`_apply_launcher_layout()` 在第一次调用时自己 connect，见那里的注释）。
	_apply_launcher_layout()
	# 水滴材质的"编译期"：必须排在 `black` **之前**，让那块不透明黑底把它整层盖住。
	_shader_warm_setup()
	black=ColorRect.new()
	black.color=Color.BLACK
	black.position=Vector2.ZERO
	black.size=view
	black.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dissolve.add_child(black)
	# 忠告：原来的锚点（左右各 16%、上下各 26%）在代码里落成同样的内缩。
	var inset := Vector2(view.x*0.16,view.y*0.26)
	advice=VBoxContainer.new()
	advice.position=inset
	advice.size=view-inset*2.0
	advice.add_theme_constant_override("separation",36)
	advice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dissolve.add_child(advice)
	var title := _make_label(ADVICE_TITLE,Vector2.ZERO,advice.size.x,38,Color(0.86,0.08,0.08))
	advice.add_child(title)
	var body := _make_label(ADVICE_BODY,Vector2.ZERO,advice.size.x,30,Color(0.92,0.92,0.92))
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	body.add_theme_constant_override("line_spacing",14)
	body.add_theme_constant_override("shadow_offset_x",2)
	body.add_theme_constant_override("shadow_offset_y",2)
	advice.add_child(body)
	# 这里原来还有一行"任意键跳过"。用户要求前端不再显示它——跳过功能保留在
	# `_unhandled_input()` 里（忠告阶段按任意键直接进 PV），只是不给玩家提示。
	# PV
	video_frame=AspectRatioContainer.new()
	video_frame.position=Vector2.ZERO
	video_frame.size=view
	video_frame.ratio=1.76470588235294
	video_frame.stretch_mode=AspectRatioContainer.STRETCH_FIT
	video_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dissolve.add_child(video_frame)
	video=VideoStreamPlayer.new()
	video.expand=true
	video.visible=false
	video.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(VIDEO_PATH):
		video.stream=load(VIDEO_PATH)
	video.finished.connect(_on_video_finished)
	video_frame.add_child(video)

# --- 水滴着色器预热（"把转场做成编译着色器的一部分"） --------------------------

## 现在就把水滴的 `ShaderMaterial` 建好，并把它挂在一张满屏白贴图上先画出来。
## Godot 的着色器管线是**第一次真正绘制时**才编译的：不预热的话，玩家点击那一刻才编译，
## 弱机上就是那几秒卡顿里的第一口。这张贴图是 `dissolve` 的第一个子节点，排在 `black`
## 之前，被那块不透明黑底完全盖住——玩家看不见它，但 GPU 已经把这条管线建好了。
## 材质本体留着，点击进游戏时由 `_start_transition()` 直接复用（不再 `ShaderMaterial.new()`）。
func _shader_warm_setup() -> void:
	var shader = load(DISSOLVE_SHADER)
	if shader==null:
		return   # 没有着色器就退回 `_start_transition()` 的兜底（直接收尾，不卡玩家）
	dissolve_material=ShaderMaterial.new()
	dissolve_material.shader=shader
	var image := Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	warm_plate=TextureRect.new()
	warm_plate.texture=ImageTexture.create_from_image(image)
	warm_plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	warm_plate.stretch_mode=TextureRect.STRETCH_SCALE
	warm_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	warm_plate.material=dissolve_material
	dissolve.add_child(warm_plate)
	_park_warm_plate.call_deferred()

## 让它真的画两帧（第一帧建管线、第二帧确认稳定），然后再收成不可见：材质留着复用，
## 但不必每帧白画一层满屏 quad。
func _park_warm_plate() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	shader_warm=true
	if warm_plate!=null:
		warm_plate.visible=false

func play_advice() -> void:
	phase=Phase.ADVICE
	advice.modulate.a=0.0
	var tween := create_tween()
	tween.tween_property(advice,"modulate:a",1.0,0.8)
	tween.tween_interval(ADVICE_HOLD_SECONDS)
	await tween.finished
	if phase!=Phase.ADVICE:
		return
	# 忠告是**静态**画面（`a` 已经停在 1.0，什么都不动）：预热（线程加载 + `main.tscn` 的
	# `_ready()`）如果还没跑完，就在这里多停一会儿——静止画面里多等几秒玩家察觉不到，
	# 放到后面的 PV 上就是视频卡住。
	await _hold_for_prewarm()
	if phase!=Phase.ADVICE:
		return
	# 淡出必须用**新的** tween：上面那条跑完就被回收了，再往上加步骤会报"无效 Tween"。
	var fade_out := create_tween()
	fade_out.tween_property(advice,"modulate:a",0.0,0.8)
	await fade_out.finished
	if phase!=Phase.ADVICE:
		return
	_after_advice()

## 等预热收尾（只在"已经发出预热请求"且"玩家还在看忠告"时等）。超时可宽，但**必须**
## 有上限：到点直接 `_finish_prewarm()` 放行，让闸门打开——宁可点击退回一次同步加载，
## 也不能把玩家永久锁在忠告画面上。
func _hold_for_prewarm() -> void:
	if not prewarm_armed or prewarm_done:
		return
	var started := Time.get_ticks_msec()
	var deadline := started+int(PREWARM_HOLD_MAX_SECONDS*1000.0)
	while phase==Phase.ADVICE and not prewarm_done and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var held := Time.get_ticks_msec()-started
	if phase==Phase.ADVICE and not prewarm_done:
		_finish_prewarm()   # 到点放行（点击那一刻会退回同步加载，但至少能进游戏）
	if held>100:
		print("[prewarm] advice screen held %dms so the load never lands on the PV" % held)

# --- 环境自检 -----------------------------------------------------------------

func _scan_env() -> void:
	# 导出成 exe 之后资源都在 PCK 里，没有"导入"这回事，也没有编辑器二进制可用。
	if not OS.has_feature("editor"):
		env_report={"ok":true,"need_import":false,"total_assets":0,"pending":[],
			"pending_count":0,"exported":true}
		_maybe_prewarm_early()
		return
	env_report=Env.scan()
	_maybe_prewarm_early()

## 自检一确认"不用导入"就**马上**开始预热：此刻玩家还在看健康忠告（静态文字），
## 把 `main.tscn` 的线程加载 + `_ready()` 那段卡顿藏在忠告里，比藏在跳动的 PV 后面干净。
## ⚠️ 绝不能更早：类缓存过期时 `load(main.tscn)` 会解析失败（硬约束③）——自检就是判它。
func _maybe_prewarm_early() -> void:
	if env_report.is_empty():
		return
	if not bool(env_report.get("ok",true)):
		return
	if bool(env_report.get("need_import",false)):
		return
	_begin_prewarm()

func _after_advice() -> void:
	if env_report.is_empty():
		_scan_env()
	if not bool(env_report.get("ok",true)):
		_show_blocked("有脚本重复声明了同一个全局类名，导入修不好。",_duplicate_detail())
		return
	if bool(env_report.get("need_import",false)):
		_begin_compile()
		return
	_start_video()

func _duplicate_detail() -> String:
	var duplicates: Dictionary = env_report.get("duplicates",{})
	var lines := PackedStringArray()
	for name in duplicates:
		lines.append("%s ← %s" % [name,", ".join(duplicates[name])])
	return "\n".join(lines)

# --- 普通路径：忠告 → PV →「点击任意键开始游戏」→ 登录页 -----------------------

func _start_video() -> void:
	if phase==Phase.ADVICE:
		phase=Phase.VIDEO
	advice.hide()
	video.show()
	# 循环播放：这一屏现在是"等玩家按键"的待机画面，播完停住会像卡死。
	# 提示文字在 `_show_prompt()` 里已经挂上，所以 `_on_video_finished()` 只是兜底。
	video.loop=true
	if video.stream!=null:
		video.play()
	_show_mute_button()
	_apply_mute()
	# 预热早就该在忠告画面里跑完了（`_maybe_prewarm_early()`）；这里只是兜住"玩家秒跳过
	# 忠告"和"自检较慢"两种情况。闸门逻辑：没准备好就显示"正在准备"，先不给那句
	# "点击任意键"——否则手快的玩家会踩到兜底的同步 `load`，卡顿就又回来了。
	if prewarm_done:
		_show_prompt()
	else:
		_show_preparing()
	_begin_prewarm()

## 预加载主场景（用户说的"提前渲染这个转场"，实测真正的瓶颈是加载本身）：
## 本机实测点击那一刻的耗时是 `load(main.tscn)=5268ms + add_child 跑 _ready=4524ms`，
## 而转场本身（抓图 8ms + 盖板 + 淡入）只有约 12ms。所以把这两段挪到待机期间：
##   ① `load` 走后台线程（`load_threaded_request`）——那 5.3s 的脚本图解析完全不占主线程；
##   ② `instantiate + add_child`（会触发 main.gd 的 `_ready()`，约 4.5s）留在主线程，
##      但发生在玩家还在看忠告/PV 的时候——那里卡一下，远好过点击后卡 10 秒。
## 挂到 root 后它在启动器层（layer=100）下面，被完全盖住看不见；`main.gd` 的 `_ready()`
## 只 `set_music_volume` 不 `play`（标题音乐要到 `go_camp` 才起），所以提前挂上不会和 PV 抢声音。
## 点击时 `_start_transition(true)` 只做 `current_scene` 顶替 + 淡入 + 擦除。
func _begin_prewarm() -> void:
	if prewarm_armed:
		return
	prewarm_armed=true
	prewarm_started_ms=Time.get_ticks_msec()
	# 诊断：`true` = 赶在忠告画面里起跑（那段卡顿玩家看不见）；`false` = 已经进了 PV
	# 才起跑（玩家会看到视频顿一下）——后者说明自检太慢，要回头看 `launcher_env.scan()`。
	print("[prewarm] begin (advice screen still up: %s)" % (phase==Phase.ADVICE))
	_prewarm()

func _prewarm() -> void:
	if not ResourceLoader.exists(MAIN_SCENE_PATH):
		_finish_prewarm()
		return
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
	if status==ResourceLoader.THREAD_LOAD_LOADED:
		_prewarm_attach(ResourceLoader.load_threaded_get(MAIN_SCENE_PATH))
		_finish_prewarm()
		return
	# INVALID_RESOURCE 只代表"从没请求过"（不是错误）；IN_PROGRESS 代表已经在导。
	if status!=ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)!=OK:
			# 线程加载起不来（平台/引擎限制）：退化成同步加载，同样放在待机期间。
			await get_tree().process_frame
			if dissolving:
				return
			_prewarm_attach(load(MAIN_SCENE_PATH))
			_finish_prewarm()
			return
	while ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if dissolving:
			return   # 玩家抢先点了：交给 `_start_transition` 收尾，这里不再挂第二份
	if ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)==ResourceLoader.THREAD_LOAD_LOADED:
		_prewarm_attach(ResourceLoader.load_threaded_get(MAIN_SCENE_PATH))
	_finish_prewarm()

func _prewarm_attach(scene: PackedScene) -> void:
	if dissolving or login_ready or scene==null:
		return
	var instance := scene.instantiate()
	if instance==null:
		return
	# 挂到 root：它在启动器层（layer=100）下面，被启动器那块不透明黑底完全盖住，看不见。
	# `add_child` 会同步跑 main.gd 的 `_ready()`（约 4.5s，主线程、无法分帧）——这正是
	# 为什么它必须发生在待机期间而不是点击时。同步初始化后立即禁用处理：否则待机期间玩家
	# 随便按一下键，底下的登录页也会收到 `_input`（点击更会误触下面的按钮）。
	get_tree().root.add_child(instance)
	# _ready() establishes the scene's processing policy (main uses ALWAYS so
	# paused menus stay interactive). Save it before suspending the prewarm.
	login_process_mode=instance.process_mode
	instance.process_mode=Node.PROCESS_MODE_DISABLED
	login_instance=instance
	login_ready=true

func _activate_prewarmed_login() -> void:
	login_instance.process_mode=login_process_mode
	get_tree().current_scene=login_instance

## 预热闸门的唯一出口：**不管成功还是失败都要放行**，否则玩家永远等不到那句
## "点击任意键开始游戏"（表现为"卡在 PV 上按什么都没用"）。
func _finish_prewarm() -> void:
	if prewarm_done:
		return
	prewarm_done=true
	print("[prewarm] ready in %dms (threaded load + _ready, done before the click)"
		% (Time.get_ticks_msec()-prewarm_started_ms))
	if prep_label!=null:
		prep_label.hide()
	if phase==Phase.VIDEO:
		_show_prompt()

## 预热还没跑完时顶替"点击任意键"的那行字：告诉玩家是在准备，不是在等他按键。
func _show_preparing() -> void:
	if prep_label==null:
		prep_label=_make_label("正在准备登录界面~",Vector2(0.0,VIEW.y*0.72),VIEW.x,28,Color("e8d9b4"))
		dissolve.add_child(prep_label)
	prep_label.show()
	if prompt!=null:
		prompt.hide()

func _on_video_finished() -> void:
	# 两条路径现在都是 `loop=true`，所以这里正常情况下不会触发；留着是兜底：
	# 万一哪天改成不循环，播完必须还留着那句提示等玩家按键，而不是自动进游戏。
	if phase==Phase.VIDEO:
		_show_prompt()

func _show_prompt() -> void:
	if prompt==null:
		prompt=_make_label("点击任意键开始游戏",Vector2(0.0,VIEW.y*0.72),VIEW.x,40,Color.WHITE,true)
		prompt.add_theme_color_override("font_outline_color",Color(0.02,0.012,0.03,0.95))
		prompt.add_theme_constant_override("outline_size",7)
		dissolve.add_child(prompt)
	prompt.show()
	if prompt_tween==null:
		prompt_tween=create_tween().set_loops()
		prompt_tween.tween_property(prompt,"modulate:a",0.3,0.75)
		prompt_tween.tween_property(prompt,"modulate:a",1.0,0.75)

# --- 编译路径：PV 循环 + 进度条 + 静音 + 文案轮播 → 重启确认 -------------------

func _begin_compile() -> void:
	phase=Phase.COMPILE
	advice.hide()
	if prompt:
		prompt.hide()
	if blocked_root:
		blocked_root.hide()
	if confirm_root:
		confirm_root.hide()
	_build_compile_ui()
	# 重试路径上这个容器是上一次建好的（`_build_compile_ui()` 会提前 return），
	# 而 `_show_blocked()` 刚把它藏起来了——不在这里显式 show 回来，重试后就是一片黑。
	compile_root.show()
	video.show()
	video.loop=true
	if video.stream!=null:
		video.play()
	_show_mute_button()
	_apply_mute()
	flavor_index=0
	flavor_timer=0.0
	flavor_label.text=FLAVOR[0]
	stage_label.text="正在检查运行环境…"
	bar.set_ratio(0.0)
	bar.set_sub_ratio(0.0)
	if sub_label!=null:
		sub_label.text="正在准备资源清单…"
	# 阶段表必须在拉起子进程**之前**建好：基线取"现在的条目数"，之后只做减法。
	_prepare_phases()
	compile_started=Time.get_ticks_msec()/1000.0
	import_pid=Env.start_import()
	if import_pid<0:
		_show_blocked("无法启动资源导入进程（没找到引擎可执行文件）。")
		return
	poll_timer=POLL_SECONDS

func _process(dt: float) -> void:
	if dissolving:
		_tick_dissolve(dt)
		return
	if phase!=Phase.COMPILE:
		return
	flavor_timer+=dt
	if flavor_timer>=FLAVOR_SECONDS:
		flavor_timer-=FLAVOR_SECONDS
		flavor_index=(flavor_index+1)%FLAVOR.size()
		flavor_label.text=FLAVOR[flavor_index]
	# 兜底超时：先掐掉子进程再报错——不掐的话"重试导入"会拉起第二个编辑器进程，
	# 两个进程同时写 .godot/ 是要出事的。
	if Time.get_ticks_msec()/1000.0-compile_started>IMPORT_TIMEOUT_SECONDS:
		_stop_import()
		_show_blocked("资源导入超时（超过 %d 分钟）。" % int(IMPORT_TIMEOUT_SECONDS/60.0),Env.log_tail())
		return
	poll_timer-=dt
	if poll_timer>0.0:
		return
	poll_timer=POLL_SECONDS
	var running: bool = import_pid>=0 and OS.is_process_running(import_pid)
	# 一次列目录同时喂两条进度条：主条吃总条目数，子条吃"按类型分"的条目数。
	var counts := Env.entry_counts_by_type()
	var entries := 0
	for key in counts:
		entries+=int(counts[key])
	var ratio := 1.0 if not running else Env.progress(env_report,counts)
	bar.set_ratio(ratio)
	stage_label.text="正在导入资源  ·  %d%%" % int(round(ratio*100.0))
	var now := Time.get_ticks_msec()/1000.0
	var elapsed := maxf(0.05,now-_last_poll_at)
	_last_poll_at=now
	_update_sub_progress(counts,entries,elapsed,running)
	if not running:
		_finish_compile()

## 子进度条：把"还缺哪些产物"按类型分组，只显示**当前正在推进**的那一组。
##
## 为什么非要它：实测一次全新 clone 的导入（4138 个资源、11 分钟）里，55 张
## `.ctexarray`（1024×4096×2、HDR BPTC）串行跑了 **6.4 分钟 = 全程 58%**，而它们
## 只占资源总数 **1.3%**——主条在那 6 分钟里从 0% 爬到 1.2%，看着就像死了。
## 子条按阶段走：那 6 分钟里它从 1/55 一格格爬到 55/55，每 7 秒动一次。
## 代价是 0：数据来自主条那一次目录列举，不额外扫盘（逐条 file_exists 要 247ms，
## 绝不能放进 0.35s 的轮询里，那会把 PV 卡成幻灯片）。
func _update_sub_progress(counts: Dictionary, entries: int, elapsed: float, running: bool) -> void:
	if not running:
		bar.set_sub_ratio(1.0)
		if sub_label!=null:
			sub_label.text="资源已就绪"
		return
	var total_done := 0
	var total := 0
	var best := ""
	var best_delta := 0.0
	for phase in phases:
		var key := str(phase["key"])
		var done := maxi(0,int(counts.get(key,0))-int(phase_baseline.get(key,0)))
		done=mini(done,int(phase["total"]))
		var delta := done-int(phase["done"])
		phase["done"]=done
		total_done+=done
		total+=int(phase["total"])
		# "谁在动就显示谁"：引擎的分批顺序不稳定（不同机器/不同缓存状态下会变），
		# 所以不按固定顺序挑，按"这一轮谁长了最多"挑。
		if done<int(phase["total"]) and delta>best_delta:
			best_delta=delta
			best=key
	if not best.is_empty():
		phase_pick=best
	# 速率用条目数算（比资源数稳）：指数平滑，避免单次抖动把 ETA 甩飞。
	if _last_entries>0:
		var instant := maxf(0.0,float(entries-_last_entries)/elapsed)
		_entry_rate=instant if _entry_rate<=0.0 else _entry_rate*0.7+instant*0.3
	_last_entries=entries
	var picked := {}
	for phase in phases:
		if str(phase["key"])==phase_pick:
			picked=phase
			break
	var sub := 1.0
	if not picked.is_empty() and int(picked["done"])<int(picked["total"]):
		sub=float(picked["done"])/maxf(1.0,float(picked["total"]))
	bar.set_sub_ratio(sub)
	if sub_label==null:
		return
	var text := ""
	if not picked.is_empty():
		text="%s  %d/%d" % [str(picked["label"]),int(picked["done"]),int(picked["total"])]
	else:
		text="已导入 %d/%d" % [total_done,total]
	var eta := _eta_seconds(entries)
	if eta>=0.0:
		text+="  ·  "+_eta_text(eta)
	sub_label.text=text

## 预计还要多久（秒）；数据不够（速率≈0）时返回 -1，界面就不显示 ETA。
func _eta_seconds(entries: int) -> float:
	if _entry_rate<=0.5:
		return -1.0
	var expected := float(env_report.get("total_assets",1))*Env.entries_per_asset()
	var left := expected-float(entries)
	if left<=0.0:
		return 0.0
	return left/_entry_rate

func _eta_text(seconds: float) -> String:
	if seconds<=0.5:
		return "即将完成"
	if seconds<60.0:
		return "剩余约 %d 秒" % int(ceil(seconds))
	return "剩余约 %d 分" % int(ceil(seconds/60.0))

## 把"还缺的产物"按扩展名分组成阶段，并记下导入前各类型的条目数基线。
## 数据全来自精确自检已经算好的 `pending`（不再扫盘），一次几百微秒。
func _prepare_phases() -> void:
	phases.clear()
	phase_baseline=Env.entry_counts_by_type()
	phase_pick=""
	_last_entries=0
	for key in phase_baseline:
		_last_entries+=int(phase_baseline[key])
	_entry_rate=0.0
	_last_poll_at=Time.get_ticks_msec()/1000.0
	var totals := {}
	for path in (env_report.get("pending",[]) as Array):
		var key := str(path).get_extension()
		# `.md5` 是旁产物，跟着主产物一起出现，不单独成阶段。
		if key.is_empty() or key=="md5":
			continue
		totals[key]=int(totals.get(key,0))+1
	var order: Array = PHASE_ORDER.duplicate()
	for key in totals:
		if not order.has(key):
			order.append(key)
	for key in order:
		if not totals.has(key):
			continue
		phases.append({"key":key,"label":str(PHASE_LABELS.get(key,key)),
			"total":int(totals[key]),"done":0})

func _finish_compile() -> void:
	import_pid=-1
	# 复查：子进程退出不等于导好了（它可能自己失败）。**先走便宜的那条**——只数一遍
	# 当初缺的那些产物还在不在（几毫秒）；只有当初还缺**类名**时才值得跑 3.7s 的
	# 精确自检（那意味着类缓存要重建，光看产物不够）。
	if not bool(env_report.get("ok",true)):
		_show_blocked("有脚本重复声明了同一个全局类名，导入修不好。",_duplicate_detail())
		return
	if not (env_report.get("missing_classes",[]) as Array).is_empty():
		env_report=Env.scan(true)
		if bool(env_report.get("need_import",false)):
			_show_blocked("资源导入没有完成。",Env.log_tail())
			return
	elif Env.count_pending(env_report.get("pending",[]))>0:
		_show_blocked("资源导入没有完成。",Env.log_tail())
		return
	bar.set_ratio(1.0)
	bar.set_sub_ratio(1.0)
	if sub_label!=null:
		sub_label.text="资源已就绪"
	stage_label.text="资源已就绪"
	phase=Phase.CONFIRM
	_build_confirm_card()

## 重启进游戏：先把画面用同一套水滴擦成黑，擦完 `_end_transition()` 再真的拉起新进程
## （新进程的类缓存是子进程刚重建好的那一份，所以带 `--skip-intro` 直达主场景）。
func _restart_into_game() -> void:
	if restarting:
		return
	restarting=true
	_start_transition(false)

# --- 进游戏 / 出错 -------------------------------------------------------------

func _enter_game(with_transition: bool = true) -> void:
	if transitioning:
		return
	if with_transition:
		_start_transition(true)
		return
	# 预览/截图/测试入口的老路：直接切场景，不加转场。
	transitioning=true
	phase=Phase.ADVICE
	video.stop()
	var scene: PackedScene = load(MAIN_SCENE_PATH)
	if scene==null:
		# 走到这里说明自检结论和实际不一致（例如玩家手删了 .godot）。给人话，别留黑屏。
		transitioning=false
		_show_blocked("主场景加载失败：脚本还没编译好。","请用「游戏启动.cmd」启动一次以重建类缓存。")
		return
	get_tree().call_deferred("change_scene_to_packed",scene)

# --- 水滴转场（进游戏 / 重启前都走它） -----------------------------------------

## **立刻**把目标画面挂到启动器层下面，然后用若干向外扩散的圆把启动器画面擦掉，
## 露出下面那一层；音频同步淡出。到 `TRANSITION_SECONDS` 之后由 `_end_transition()` 收尾。
##
## 为什么不用 `change_scene_to_packed`：那个会把启动器场景直接释放掉，就没有"上层
## 被擦掉、下层露出来"这两层同时在树上的画面了。这里手动做同一件事，只是让两层并存：
##   - 启动器在 `CanvasLayer(layer=100)`，`main.tscn` 的界面在 main.gd 自己建的
##     `CanvasLayer`（默认 layer=1），所以登录页天然在下面等着；
##   - `main.gd` 全程不读 `current_scene`（已逐行核对），手动顶替是安全的。
##
## 为什么溶解的是"一张抓下来的静态图"而不是活的启动器层：本版本（4.7.2 实测）
## `CanvasGroup` 的材质**拿不到整组贴图**——纯直通 `COLOR = texture(TEXTURE, UV)`
## 都会渲染成默认的 1×1 白贴图（表现为"没被擦掉的地方全白"）。抓图这条路的
## `TEXTURE` 是一张真贴图，确定可行；代价是点击那一刻多一次 GPU→CPU 回读。
func _start_transition(reveal_login: bool) -> void:
	if dissolving:
		return
	dissolving=true
	transitioning=true
	var setup_started_ms := Time.get_ticks_msec()
	# 等这一帧画完，把启动器当前画面抓下来（此时还没挂 main.tscn，所以抓到的是启动器）
	await RenderingServer.frame_post_draw
	var snapshot := get_viewport().get_texture().get_image()
	# 把目标画面挂到启动器层下面（登录页"秒加载"，只是先被盖着）
	if reveal_login:
		if login_ready and is_instance_valid(login_instance):
			# 预加载已就绪：点击这一刻只剩抓图 + 盖板 + 淡入，没有任何加载卡顿。
			# 把预加载期间关掉的输入/处理重新打开，再交给它当主场景。
			_activate_prewarmed_login()
			if login_instance.has_method("fade_in_ui"):
				login_instance.fade_in_ui(LOGIN_FADE_SECONDS)
		else:
			# 兜底：玩家手速快到预加载还没跑完（或预加载失败）——退回同步加载。
			var scene: PackedScene = load(MAIN_SCENE_PATH)
			if scene==null:
				dissolving=false
				transitioning=false
				_show_blocked("主场景加载失败：脚本还没编译好。","请用「游戏启动.cmd」启动一次以重建类缓存。")
				return
			var instance := scene.instantiate()
			get_tree().root.add_child(instance)
			get_tree().current_scene=instance
			login_instance=instance
			if instance.has_method("fade_in_ui"):
				instance.fade_in_ui(LOGIN_FADE_SECONDS)
	else:
		# 重启路径：底下没有登录页可露，垫一层纯黑（视口的清屏色不是纯黑）。
		var curtain := ColorRect.new()
		curtain.color=Color.BLACK
		curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(curtain)
	# 复用 `_shader_warm_setup()` 早在启动画面期间就建好、而且在 GPU 上真画过的那个材质：
	# 点击这一刻不再 `ShaderMaterial.new()`——那一句会让引擎现编译管线，正是弱机上
	# "点击后卡几秒"的第一口（用户要求把转场并进"编译着色器"，指的就是它）。
	if snapshot==null or dissolve_material==null:
		# 兜底：抓图/着色器任一失败就直接收尾，别把玩家卡在启动器上。
		dissolve_elapsed=TRANSITION_SECONDS
		_end_transition()
		return
	# ③ 把抓到的画面铺在最上层（不透明，完全盖住启动器），然后把启动器层藏掉：
	#    视频继续放（音频才淡得出来），但不再渲染——于是擦掉的地方露出来的是下面的
	#    登录页，而不是启动器自己。
	transition_overlay=CanvasLayer.new()
	transition_overlay.layer=110
	var plate := TextureRect.new()
	plate.texture=ImageTexture.create_from_image(snapshot)
	plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode=TextureRect.STRETCH_SCALE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	transition_overlay.add_child(plate)
	get_tree().root.add_child(transition_overlay)
	visible=false
	# 声音跟画面一起淡出。静音按钮优先级最高：静音状态下保持静音，不去动它。
	if not _muted():
		var audio := create_tween()
		audio.tween_property(video,"volume_db",-80.0,TRANSITION_SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_roll_drops(rng)
	plate.material=dissolve_material
	_push_dissolve_uniforms()
	dissolve_elapsed=0.0
	dissolve_warmup=true
	# 演算靠 `_process`。显式打开：`_end_transition()` 会把它关掉，重试/二次转场时
	# 必须自己开回来（少这一句的表现是"水滴永远不动、启动器擦不掉"）。
	set_process(true)
	print("[prewarm] click setup %dms (1 frame + snapshot readback + plate; no load, no shader compile)"
		% (Time.get_ticks_msec()-setup_started_ms))

## 摇 4~5 个圆心：全部落在屏幕中心的那个圆内（面积占屏 20%），两两强制最小间距。
## 用拒绝采样；摇满次数还不满足就接受当前这个——宁可稍微近一点，也不能在这里死循环。
func _roll_drops(rng: RandomNumberGenerator) -> void:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x/maxf(view.y,1.0)
	var region := sqrt(DROP_REGION_AREA*aspect/PI)   # 单位：屏幕高度 = 1
	drop_centers.clear()
	drop_radii.clear()
	drop_speed.clear()
	drop_delay.clear()
	var count := rng.randi_range(DROP_COUNT_MIN,DROP_COUNT_MAX)
	for i in count:
		var offset := Vector2.ZERO
		for attempt in 64:
			var angle := rng.randf()*TAU
			# 乘 sqrt(randf()) 才是圆内**均匀**分布；直接用 randf() 会往圆心堆。
			var distance := region*sqrt(rng.randf())
			offset=Vector2(cos(angle),sin(angle))*distance
			var clear := true
			for other in drop_centers:
				if offset.distance_to(other)<region*DROP_MIN_GAP:
					clear=false
					break
			if clear:
				break
		drop_centers.append(offset)
		drop_radii.append(0.0)
		# 每滴快慢/起步略作差别，免得看起来像同一个圆规画出来的
		drop_speed.append(rng.randf_range(0.85,1.15))
		drop_delay.append(rng.randf_range(0.0,0.1))

func _push_dissolve_uniforms() -> void:
	if dissolve_material==null:
		return
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x/maxf(view.y,1.0)
	var centers := PackedVector2Array()
	var radii := PackedFloat32Array()
	for i in 5:
		if i<drop_centers.size():
			var offset: Vector2 = drop_centers[i]
			centers.append(Vector2(0.5+offset.x/aspect,0.5+offset.y))
			radii.append(drop_radii[i])
		else:
			centers.append(Vector2.ZERO)
			radii.append(0.0)
	dissolve_material.set_shader_parameter("count",drop_centers.size())
	dissolve_material.set_shader_parameter("centers",centers)
	dissolve_material.set_shader_parameter("radii",radii)

func _tick_dissolve(dt: float) -> void:
	# 第一帧的 dt 里含着"实例化 main.tscn + 它的 _ready"那一整段卡顿（实测能把 0.9s
	# 的转场一口吃掉，水滴一上来就跳一大步），所以跳过第一帧。
	if dissolve_warmup:
		dissolve_warmup=false
		return
	dissolve_elapsed+=dt
	for i in drop_radii.size():
		var t := maxf(0.0,dissolve_elapsed-drop_delay[i])
		drop_radii[i]=minf(MAX_DROP_RADIUS,t/TRANSITION_SECONDS*drop_speed[i]*MAX_DROP_RADIUS)
	_push_dissolve_uniforms()
	if dissolve_elapsed>=TRANSITION_SECONDS:
		_end_transition()

## 转场收尾：算好的时长一到就把**所有水滴演算**清掉（材质摘掉、数组清空、停掉
## `_process`），再把启动器层和那张抓图一起释放——不留任何每帧开销。
func _end_transition() -> void:
	dissolving=false
	set_process(false)
	# 彻底释放"预热 + 转场"用到的临时对象（用户要求"在转场收尾彻底释放"）：水滴材质、
	# 预热用的那张满屏贴图、抓图盖板、两个文字节点全部断引用；启动器层连同它们的子节点
	# 在下面 `queue_free()` 里一起销毁，不留常驻显存、也不留任何每帧演算。
	dissolve_material=null
	warm_plate=null
	shader_warm=false
	prep_label=null
	prompt=null
	prompt_tween=null
	drop_centers.clear()
	drop_radii.clear()
	drop_speed.clear()
	drop_delay.clear()
	if transition_overlay!=null:
		transition_overlay.queue_free()
		transition_overlay=null
	if restarting:
		# 重启路径：黑屏已经擦出来了，现在才真的拉起新进程。
		OS.create_process(OS.get_executable_path(),PackedStringArray([
			"--path",ProjectSettings.globalize_path("res://"),"--","--skip-intro"]))
		get_tree().quit()
		return
	# 普通路径：登录页已经在下面了，把启动器层连同视频一起释放。
	queue_free()

func _show_blocked(reason: String, detail: String = "") -> void:
	phase=Phase.BLOCKED
	if compile_root:
		compile_root.hide()
	if confirm_root:
		confirm_root.hide()
	if prompt:
		prompt.hide()
	_build_blocked_card(reason,detail)

# --- 输入：只有"没被控件吃掉"的输入才算"任意键" --------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# 走到这里的输入都没有被任何控件消费：右上角静音按钮、卡片上的按钮都是真 Button，
	# 点它们不会顺带触发"任意键开始游戏"（用户点名要避免的那条）。
	if restarting or dissolving or phase==Phase.COMPILE or phase==Phase.BLOCKED:
		return
	var joy: bool = event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_START]
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
	if not (joy or key or click):
		return
	get_viewport().set_input_as_handled()
	match phase:
		Phase.ADVICE: _start_video()
		Phase.VIDEO:
			# 闸门：预热没完成就不放行。`_start_transition()` 的兜底是**同步**
			# `load(main.tscn)`（约 5.3s）+ 它的 `_ready()`（约 4.5s）——那正是用户
			# 抱怨的"点击后卡几秒"。宁可让玩家多等那行"正在准备登录界面~"。
			if prewarm_done:
				_enter_game()
		# 确认卡片上也允许按键/手柄确认，免得手柄玩家卡在这一步；点静音按钮不算
		# （那次点击会被按钮吃掉，根本走不到这里）。
		Phase.CONFIRM: _restart_into_game()
		_: pass

func _has_preview_argument(args: PackedStringArray) -> bool:
	for arg in args:
		if arg.begins_with("--preview-"):
			return true
	return false

# --- 静音（只关 PV 音量，设置存本地） ------------------------------------------

func _graphics():
	return get_node_or_null("/root/GraphicsQuality")

## 启动器是否处于静音（静音设置存 `user://graphics.cfg`，重启也记得）。
func _muted() -> bool:
	var graphics = _graphics()
	return bool(graphics.launcher_mute) if graphics else false

func _apply_mute() -> void:
	var muted := _muted()
	video.volume_db=-80.0 if muted else 0.0
	if mute:
		mute.set_muted(muted)

func _toggle_mute() -> void:
	var graphics = _graphics()
	if graphics==null:
		return
	graphics.set_launcher_mute(not bool(graphics.launcher_mute))
	_apply_mute()

func _show_mute_button() -> void:
	if mute==null:
		mute=MuteButton.new()
		mute.size=Vector2(58,58)
		mute.tooltip_text="静音 PV（只影响启动画面）"
		mute.pressed.connect(_toggle_mute)
		dissolve.add_child(mute)
	# 尺寸/位置由布局真值统一落（大屏上跟着画布放大，不再是左上角一个固定小框）。
	_apply_launcher_layout()
	mute.show()

# --- 界面构件（全部程序化：首次下载时一张贴图都加载不了） ----------------------

func _make_label(text: String, at: Vector2, width: float, font_size: int, color: Color,
		use_bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text=text
	label.position=at
	label.size=Vector2(width,float(font_size)*2.0)
	label.horizontal_alignment=align
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",bold if use_bold else face)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.01,0.008,0.015,0.9))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label

func _make_panel(parent: Node, at: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position=at
	panel.size=dimensions
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.045,0.035,0.06,0.95)
	style.border_color=Color("cbb087")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func _make_button(parent: Node, text: String, at: Vector2, dimensions: Vector2,
		callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text=text
	button.position=at
	button.size=dimensions
	button.focus_mode=Control.FOCUS_NONE
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",bold)
	button.add_theme_font_size_override("font_size",22)
	button.add_theme_color_override("font_color",Color("ede5d8"))
	button.add_theme_color_override("font_hover_color",Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(0.16,0.07,0.12,0.96) if primary else Color(0.08,0.06,0.1,0.94)
	style.border_color=Color("e0c79a") if primary else Color("cbb087")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left=16.0
	style.content_margin_right=16.0
	button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate()
	hover.bg_color=Color(0.26,0.1,0.16,0.98) if primary else Color(0.14,0.1,0.17,0.96)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

## 启动器界面的一次性布局真值（纯函数，`tests/launcher_progress.gd` 钉住比例）。
##
## 基准设计 = 1440×900，但**不能**把它当布局真值：工程是 `stretch=canvas_items` +
## `aspect=expand`，画布会随窗口比例变宽（实测 1920×1080 的窗口里画布是 1600×900，
## 2560×1600 是 1467×900）。写死 1440 的后果就是"PV 铺满、进度条和静音按钮却缩在
## 左上角那个 1440 宽的框里"——2026-10-19 用户在大屏机器上撞到的正是这个。
##
## 所以：`scale` 只跟**宽度**走（大屏上条子仍然占屏 52.8%），纵向用画布比例
## （0.47 / 0.53），任何宽高比都不会跑位。
static func launcher_layout(canvas: Vector2) -> Dictionary:
	var s := clampf(canvas.x/1440.0,0.7,2.6)
	var bar_size := BAR_SIZE*s
	return {
		"scale":s,
		"bar_size":bar_size,
		"bar_pos":Vector2((canvas.x-bar_size.x)*0.5,canvas.y*0.53),
		"flavor_y":canvas.y*0.47,
		"flavor_size":maxi(14,int(round(24.0*s))),
		"stage_y":canvas.y*0.53+bar_size.y+8.0*s,
		"stage_size":maxi(12,int(round(18.0*s))),
		"sub_y":canvas.y*0.53+bar_size.y+34.0*s,
		"sub_size":maxi(11,int(round(15.0*s))),
		"mute_size":Vector2(58.0*s,58.0*s),
		"mute_pos":Vector2(canvas.x-88.0*s,30.0*s),
	}

## 画布尺寸 = 窗口经 `canvas_items` 拉伸后的设计空间（**不是**窗口像素）。
func _canvas() -> Vector2:
	var viewport := get_viewport()
	if viewport==null:
		return VIEW
	return viewport.get_visible_rect().size

## 按当前画布重排启动器的所有程序化控件；窗口尺寸一变就再跑一次。
## 只在第一次调用时 connect `size_changed`——这样不用改 `_ready()`，也不会重复连。
func _apply_launcher_layout() -> void:
	var viewport := get_viewport()
	if viewport!=null and not viewport.size_changed.is_connected(_apply_launcher_layout):
		viewport.size_changed.connect(_apply_launcher_layout)
	var canvas := _canvas()
	var layout := launcher_layout(canvas)
	var s := float(layout["scale"])
	if dissolve!=null:
		dissolve.size=canvas
	if black!=null:
		black.size=canvas
	if video_frame!=null:
		video_frame.position=Vector2.ZERO
		video_frame.size=canvas
	if advice!=null:
		var inset := Vector2(canvas.x*0.16,canvas.y*0.26)
		advice.position=inset
		advice.size=canvas-inset*2.0
		# 忠告标题/正文也是程序化建的：宽度跟容器走，字号跟 `scale` 走，
		# 否则大屏上忠告会变成居中一小撮。
		if advice.get_child_count()>=2:
			var title: Label = advice.get_child(0)
			var body: Label = advice.get_child(1)
			title.size.x=advice.size.x
			title.add_theme_font_size_override("font_size",maxi(20,int(round(38.0*s))))
			body.size.x=advice.size.x
			body.size.y=maxf(80.0,advice.size.y-90.0)
			body.add_theme_font_size_override("font_size",maxi(16,int(round(30.0*s))))
	if compile_root!=null:
		compile_root.size=canvas
	if shade!=null:
		shade.size=canvas
	if flavor_label!=null:
		flavor_label.position=Vector2(0.0,float(layout["flavor_y"]))
		flavor_label.size=Vector2(canvas.x,float(layout["flavor_size"])*2.0)
		flavor_label.add_theme_font_size_override("font_size",int(layout["flavor_size"]))
	if bar!=null:
		# 用 `scale` 而不是把 size 改大：条子的内部分层（11/25/6/8）都在 760×62 这套
		# 基准里，整体缩放才能保证两行条在任何屏幕上比例一致、不糊不错位。
		bar.size=BAR_SIZE
		bar.scale=Vector2(s,s)
		bar.position=Vector2(layout["bar_pos"])
	for pair in [[stage_label,"stage_y","stage_size"],[sub_label,"sub_y","sub_size"]]:
		var label: Label = pair[0]
		if label==null:
			continue
		label.position=Vector2(0.0,float(layout[pair[1]]))
		label.size=Vector2(canvas.x,float(layout[pair[2]])*2.0)
		label.add_theme_font_size_override("font_size",int(layout[pair[2]]))
	if mute!=null:
		mute.size=Vector2(layout["mute_size"])
		mute.position=Vector2(layout["mute_pos"])
	if prompt!=null:
		prompt.position=Vector2(0.0,canvas.y*0.72)
		prompt.size=Vector2(canvas.x,80.0)
		prompt.add_theme_font_size_override("font_size",maxi(22,int(round(40.0*s))))
	for card in [confirm_root,blocked_root]:
		if card==null:
			continue
		var panel: Control = card
		panel.scale=Vector2(s,s)
		panel.position=(canvas-panel.size*s)*0.5

func _build_compile_ui() -> void:
	if compile_root:
		return
	var canvas := _canvas()
	compile_root=Control.new()
	compile_root.position=Vector2.ZERO
	compile_root.size=canvas
	compile_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dissolve.add_child(compile_root)
	# 压暗 PV：不然进度条和文案在亮画面上读不清
	shade=ColorRect.new()
	shade.color=Color(0.02,0.015,0.03,0.55)
	shade.position=Vector2.ZERO
	shade.size=canvas
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	compile_root.add_child(shade)
	# 进度条前端那行世界观文案（用户要求：固定一行、循环换）
	flavor_label=_make_label(FLAVOR[0],Vector2(0.0,canvas.y*0.47),canvas.x,24,Color("e8d9b4"))
	compile_root.add_child(flavor_label)
	bar=Bar.new()
	bar.size=BAR_SIZE
	# 主条与子条共用一圈描金框：布局常量一半在 `launcher_bar.gd`，对不上就会溢出。
	assert(BAR_SIZE.y>=Bar.needed_height(), "BAR_SIZE 装不下主条+子条，改布局常量要对账")
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	compile_root.add_child(bar)
	stage_label=_make_label("正在检查运行环境…",Vector2(0.0,canvas.y*0.53),canvas.x,18,Color("969aaa"))
	compile_root.add_child(stage_label)
	# 子进度条下面那行小字（阶段 + 进度 + 剩余时间）。用户要求：主条不动的时候，
	# 玩家得能看见"确实在动"，所以这行必须比主条的百分比更细。
	sub_label=_make_label("正在准备资源清单…",Vector2(0.0,canvas.y*0.53),canvas.x,15,Color("7d818f"))
	compile_root.add_child(sub_label)
	# 位置/字号全部交给布局真值（含窗口尺寸变化的第一次落位）。
	_apply_launcher_layout()

func _build_confirm_card() -> void:
	if confirm_root:
		return
	var dimensions := Vector2(720,272)
	var panel := _make_panel(dissolve,Vector2.ZERO,dimensions)
	confirm_root=panel
	panel.add_child(_make_label("资源编译完成",Vector2(0.0,30.0),dimensions.x,30,Color("cbb087"),true))
	panel.add_child(_make_label(
		"首次启动（或更新后）需要把资源编译一遍。\n现在需要重启一次游戏才能正式进入。",
		Vector2(0.0,84.0),dimensions.x,20,Color("ede5d8")))
	_make_button(panel,"立即重启并进入游戏",Vector2((dimensions.x-360.0)*0.5,192.0),
		Vector2(360,54),_restart_into_game,true)
	_apply_launcher_layout()

func _build_blocked_card(reason: String, detail: String) -> void:
	if blocked_root:
		blocked_root.queue_free()
	var dimensions := Vector2(900,420)
	var panel := _make_panel(dissolve,Vector2.ZERO,dimensions)
	blocked_root=panel
	panel.add_child(_make_label("无法进入游戏",Vector2(0.0,26.0),dimensions.x,30,Color("d2405c"),true))
	panel.add_child(_make_label(reason,Vector2(40.0,82.0),dimensions.x-80.0,21,Color("ede5d8")))
	var body := _make_label(detail if not detail.is_empty() else "没有更多信息。",
		Vector2(40.0,126.0),dimensions.x-80.0,16,Color("969aaa"),false,HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.size=Vector2(dimensions.x-80.0,200.0)
	body.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	panel.add_child(body)
	_make_button(panel,"重试导入",Vector2(60.0,340.0),Vector2(260,54),_retry_compile)
	_make_button(panel,"退出游戏",Vector2(dimensions.x-320.0,340.0),Vector2(260,54),_quit_game)
	_apply_launcher_layout()

func _retry_compile() -> void:
	if blocked_root:
		blocked_root.queue_free()
		blocked_root=null
	_stop_import()
	_begin_compile()

## 掐掉导入子进程（超时/重试前必须做：两个编辑器进程同时写 .godot/ 会互相踩）。
func _stop_import() -> void:
	if import_pid>=0 and OS.is_process_running(import_pid):
		OS.kill(import_pid)
	import_pid=-1

func _quit_game() -> void:
	get_tree().quit()
