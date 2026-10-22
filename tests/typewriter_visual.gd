extends SceneTree
## 真实窗口截图：CG 台词半显、全显，以及故事暂停菜单里的“打字音效”开关。
## 运行（不要加 --headless）：
##   Godot_v4.7.2-stable_win64_console.exe --path . --script tests/typewriter_visual.gd
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	RenderingServer.force_draw(false)
	var image: Image=root.get_texture().get_image()
	var path: String="res://build/"+name+".png"
	var error:=image.save_png(path)
	check(error==OK,"capture "+name)

func run() -> void:
	root.size=Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var screen=preload("res://scripts/story_screen.gd").new()
	root.add_child(screen)
	var sound:=TideSound.new()
	root.add_child(sound)
	sound.ambience.stop()
	screen.sound=sound
	screen.campaign.state=screen.campaign.new_state()
	screen.campaign.save_enabled=false
	screen.world.build()
	screen.set_active(true)
	var scene: Dictionary=screen.campaign.content.scenes["06-05"]
	var best_page:=0
	var best_length:=0
	for i in scene.pages.size():
		var length:=str(scene.pages[i].get("text","")).length()
		if str(scene.pages[i].get("cg",""))!="" and length>best_length:
			best_length=length; best_page=i
	var event: Dictionary=scene.duplicate(true)
	event.kind="scene"; event.page=best_page
	screen.play_replay(event)
	for i in 3: await process_frame
	var d=screen.dialogue
	check(is_instance_valid(d),"CG replay creates an ADV")
	d.set_process(false)
	var total: int=int(d.typer.total)
	var speed: float=float(screen.campaign.state.settings.speed)
	check(total>4,"the captured CG page is long enough to observe typing")
	d._tick_type(0.07+2.2/speed)
	check(d.typer.revealed>0 and d.typer.revealed<d.typer.total,"the captured page is genuinely mid-reveal")
	check(d.body.visible_characters==d.typer.revealed,"visible characters follow the typewriter")
	check(sound.last_type_ms>0,"the real ADV reaches TideSound.play_type")
	var type_playing:=false
	for voice in sound.type_voices:
		if voice.playing: type_playing=true
	check(type_playing,"a typewriter voice is actually playing")
	var partial: int=int(d.typer.revealed)
	await process_frame
	shot("typewriter-cg-partial")
	d._tick_type(30.0)
	check(d.typer.finished and d.body.visible_characters==-1,"finishing reveals the whole page")
	await process_frame
	shot("typewriter-cg-full")
	d.skip_scene()
	for i in 2: await process_frame
	screen.show_menu()
	for i in 3: await process_frame
	shot("typewriter-settings")
	check(FileAccess.file_exists("res://build/typewriter-cg-partial.png"),"partial screenshot is on disk")
	check(FileAccess.file_exists("res://build/typewriter-cg-full.png"),"full screenshot is on disk")
	check(FileAccess.file_exists("res://build/typewriter-settings.png"),"settings screenshot is on disk")
	print("TYPEWRITER_VISUAL %d checks, %d failures, partial=%d glyphs, total=%d" % [checks,failures,partial,total])
	screen.queue_free()
	sound.queue_free()
	await process_frame
	quit(1 if failures else 0)
