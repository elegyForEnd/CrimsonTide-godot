extends Node
## Local presentation settings never enter the campaign or network simulation.
const PATH := "user://graphics.cfg"
var quality := 0
var upscale := 0
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
	config.load(PATH)
	quality=clampi(int(config.get_value("graphics","quality",0)),0,2)
	upscale=clampi(int(config.get_value("graphics","upscale",0)),0,2)
	if quality==2 and RenderingServer.get_current_rendering_method()=="forward_plus" and not Engine.is_editor_hint() and DisplayServer.get_name()!="headless":
		var arguments := PackedStringArray()
		if OS.has_feature("editor"): arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
		arguments.append_array(["--rendering-method","gl_compatibility","--"])
		arguments.append_array(OS.get_cmdline_user_args())
		if OS.create_instance(arguments)>=0: get_tree().quit(); return
	apply()
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
	config.save(PATH); apply()
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
