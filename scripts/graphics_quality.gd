extends Node
## Local presentation settings never enter the campaign or network simulation.
const PATH := "user://graphics.cfg"
# Window mode/size lives in the save file (profile.gd owns the write), but it has
# to be applied here: this autoload is the earliest script hook in the process, so
# applying it here is what makes the intro PV open in the player's own window
# instead of the project default. See `window_settings.gd`.
const WindowSettings = preload("res://scripts/window_settings.gd")
var quality := 0
var upscale := 0
# 启动器（PV 那段）的静音开关。它属于"本地表现设置"而不是存档内容：不进
# `profile.json`，免得跟着账号云存档同步到别的机器上（玩家在网吧静音一次，
# 回家发现自己游戏没声音是最糟的体验）。键在 `graphics.cfg` 的 `[audio]` 段。
var launcher_mute := false
var config := ConfigFile.new()
var history_ticket := 0
func reset_history() -> void:
	var vp := get_viewport()
	if vp.scaling_3d_mode!=Viewport.SCALING_3D_MODE_FSR2: return
	history_ticket+=1
	# Changing temporal scaling mode destroys the previous FSR context.
	vp.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
	restore_history.call_deferred(history_ticket)
func restore_history(ticket: int) -> void:
	if ticket==history_ticket: apply()
func _ready() -> void:
	# Before anything else, and before the main scene exists: the intro PV must not
	# play in a window the player did not ask for. Headless runs, `--script` test
	# runs and an explicit window flag on the command line are exempt — the rule
	# lives in `window_settings.gd skip_window_control()`.
	WindowSettings.apply_saved()
	config.load(PATH)
	quality=clampi(int(config.get_value("graphics","quality",0)),0,2)
	upscale=clampi(int(config.get_value("graphics","upscale",0)),0,2)
	launcher_mute=bool(config.get_value("audio","launcher_mute",false))
	if quality==2 and RenderingServer.get_current_rendering_method()=="forward_plus" and not Engine.is_editor_hint() and DisplayServer.get_name()!="headless":
		var arguments := launch_arguments()
		arguments.append_array(["--rendering-method","gl_compatibility","--"])
		arguments.append_array(OS.get_cmdline_user_args())
		if OS.create_instance(arguments)>=0: get_tree().quit(); return
	apply()
func launch_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	if OS.has_feature("editor"): arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
	var current := OS.get_cmdline_args()
	for i in current.size()-1:
		if current[i]=="--main-pack": arguments.append_array(["--main-pack",current[i+1]])
	return arguments
func advanced() -> bool:
	return RenderingServer.get_current_rendering_method()=="forward_plus" and quality<2
func apply() -> void:
	var vp := get_viewport()
	if advanced():
		vp.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR2 if upscale==0 else Viewport.SCALING_3D_MODE_FSR if upscale==1 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale=.67 if upscale<2 else 1.0
		vp.msaa_3d=Viewport.MSAA_DISABLED if upscale==0 else Viewport.MSAA_2X
	else:
		vp.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale=1.0; vp.msaa_3d=Viewport.MSAA_2X
	Engine.max_fps=60 if not "--benchmark" in OS.get_cmdline_user_args() else 0
	for node in get_tree().get_nodes_in_group("quality_environment"):
		configure(node.environment)
	for node in get_tree().get_nodes_in_group("quality_fog"): node.visible=advanced() and quality==0
func save() -> void:
	config.set_value("graphics","quality",quality); config.set_value("graphics","upscale",upscale)
	config.set_value("audio","launcher_mute",launcher_mute)
	config.save(PATH); apply()

## 启动器的静音按钮走这里：只写这一个键并立刻落盘，**不**顺带 `apply()`——那会把
## 视口缩放和帧率上限也重算一遍，而这一步发生在主场景还没创建的时候。
func set_launcher_mute(value: bool) -> void:
	launcher_mute=value
	config.set_value("audio","launcher_mute",value)
	config.save(PATH)
func configure(env: Environment) -> void:
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_exposure=1.0
	env.ssao_enabled=advanced(); env.ssao_radius=.45; env.ssao_intensity=.65
	env.ssao_light_affect=.12; env.ssao_ao_channel_affect=.1
	env.ssr_enabled=advanced() and quality==0; env.ssr_max_steps=32
	env.glow_enabled=true; env.glow_intensity=.4; env.glow_bloom=.04
	env.volumetric_fog_enabled=advanced() and quality==0
	env.volumetric_fog_density=0.0; env.volumetric_fog_length=38
	env.volumetric_fog_ambient_inject=.15
	env.volumetric_fog_anisotropy=.3
