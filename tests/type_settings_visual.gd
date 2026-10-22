extends SceneTree
## 故事暂停菜单里「打字音效」开关与音量滑杆的真实鼠标回归。
## 要真窗口，所以命名 `*_visual`。
##
## 钉住四件事：
##   ① 复选框能点（上一版「开/关」按钮报点不动，不能再靠 `pressed.emit()` 自证）；
##   ② 复选框只改 `type_sound`，不碰 `type_volume`；
##   ③ 音量滑杆真的改 `type_volume`（左右两端都点一次）；
##   ④ 「阅读速度」整块已下移，不再压住「从王冠回答前重新选择」按钮。
var screen
var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TYPE SETTINGS FAIL: "+text)

func named(parent: Node, name: String) -> Node:
	if parent.name==name: return parent
	for child in parent.get_children():
		var found:=named(child,name)
		if found: return found
	return null

func by_text(parent: Node, text: String) -> Node:
	if parent is Label and parent.text==text: return parent
	if parent is Button and parent.text==text: return parent
	for child in parent.get_children():
		var found:=by_text(child,text)
		if found: return found
	return null

## 不经过 OS 鼠标：直接把画布坐标的点击送进 Viewport，避开本机 warp_mouse 标定偏差，
## 但仍然走 Godot 真正的 GUI 命中/`_gui_input` 路径（Button 收不到就是收不到）。
func button_event(design: Vector2, down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	event.position=design
	event.global_position=design
	screen.get_viewport().push_input(event)
	await process_frame

func click(design: Vector2) -> void:
	await button_event(design,true)
	await button_event(design,false)

func hover(design: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=design
	event.global_position=design
	screen.get_viewport().push_input(event)
	await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	screen=preload("res://scripts/story_screen.gd").new()
	root.add_child(screen)
	screen.campaign.state=screen.campaign.new_state()
	screen.campaign.save_enabled=false
	screen.world.build()
	screen.set_active(true)
	screen.show_menu()
	for i in 3: await process_frame

	var enable: Button=named(screen.overlay,"TypeSoundCheck")
	var volume: HSlider=named(screen.overlay,"TypeVolumeSlider")
	check(enable!=null,"sound toggle exists")
	check(volume!=null,"volume slider exists")
	if enable==null or volume==null:
		quit(1); return
	check(enable.text.begins_with("✓") and bool(screen.campaign.state.settings.type_sound),"default is enabled")
	check(is_equal_approx(float(screen.campaign.state.settings.type_volume),50.0),"default volume is medium 50%")

	# The toggle uses the same gothic material; hover/pressed are code modulates, not second textures.
	var hover_style: StyleBoxTexture=enable.get_theme_stylebox("hover")
	check(hover_style is StyleBoxTexture and hover_style.modulate_color.r<0.85,"hover style is code-dimmed")
	check(hover_style.modulate_color.g<hover_style.modulate_color.r*0.7,"hover keeps the warm dark-red hue")
	var pressed_style: StyleBoxTexture=enable.get_theme_stylebox("pressed")
	check(pressed_style is StyleBoxTexture and pressed_style.modulate_color.r<0.7,"pressed style is darker than normal")
	var plain_button:=by_text(screen.overlay,"继续游戏")
	if plain_button:
		var plain_hover: StyleBoxTexture=plain_button.get_theme_stylebox("hover")
		check(plain_hover is StyleBoxTexture and plain_hover.modulate_color.g<plain_hover.modulate_color.r*0.7,"every story button shares the same dark-red hover")
	else:
		check(false,"plain story button is present for the shared-hover check")
	var center:=enable.get_global_rect().get_center()
	await hover(center)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://build/typewriter-toggle-hover.png")
	# Press: real press must scale the button, then release must restore it.
	await button_event(center,true)
	await create_timer(0.09).timeout
	check(enable.scale.x<0.99,"pressing scales the toggle down")
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://build/typewriter-toggle-pressed.png")
	await button_event(center,false)
	await create_timer(0.24).timeout
	check(enable.scale.x>0.99,"releasing restores the toggle scale")
	check(not bool(screen.campaign.state.settings.type_sound),"click unchecks the sound")
	check(enable.text.begins_with("□"),"unchecked toggle shows an empty box")
	check(is_equal_approx(float(screen.campaign.state.settings.type_volume),50.0),"unchecking leaves the volume alone")
	await click(center)
	check(bool(screen.campaign.state.settings.type_sound),"click re-enables the sound")
	check(enable.text.begins_with("✓"),"checked toggle shows a tick")
	check(is_equal_approx(float(screen.campaign.state.settings.type_volume),50.0),"re-enabling leaves the volume alone")

	# slider: click near the left and right ends of the track.
	var rect:=volume.get_global_rect()
	await click(Vector2(rect.position.x+rect.size.x*0.18,rect.position.y+rect.size.y*0.5))
	check(float(screen.campaign.state.settings.type_volume)<50.0,"clicking the low end lowers the volume")
	await click(Vector2(rect.position.x+rect.size.x*0.82,rect.position.y+rect.size.y*0.5))
	check(float(screen.campaign.state.settings.type_volume)>50.0,"clicking the high end raises the volume")

	# layout: reading speed must sit below the button above it.
	var speed_label:=by_text(screen.overlay,"阅读速度")
	var restore_button:=by_text(screen.overlay,"从王冠回答前重新选择")
	check(speed_label!=null and restore_button!=null,"reading-speed block is present")
	if speed_label and restore_button:
		var top: float=speed_label.get_global_rect().position.y
		var above: float=restore_button.get_global_rect().position.y+restore_button.get_global_rect().size.y
		check(top>=above+8.0,"reading speed moved below the restore button")

	# leave the screenshot at the intended defaults, with the pointer away.
	enable.text="✓ 启用"
	screen.campaign.state.settings.type_sound=true
	volume.value=50
	screen.campaign.state.settings.type_volume=50.0
	await hover(Vector2(8,8))
	for i in 2: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://build/typewriter-settings.png")
	check(FileAccess.file_exists("res://build/typewriter-settings.png"),"settings screenshot is written")
	print("TYPE_SETTINGS_VISUAL %d checks, %d failures" % [checks,failures])
	screen.queue_free()
	await process_frame
	quit(1 if failures else 0)
