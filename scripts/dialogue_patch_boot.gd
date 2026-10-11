extends Node
## Dialogue release stacks on the published v11 combat patch and v9 art base.
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"): folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Combat-v11.pck","CrimsonTide-Dialogue-v12.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var error := Label.new(); error.text="无法读取 "+file+"，请将 v12 运行文件与三个资源包放在同一目录。"; add_child(error); push_error(error.text); return
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("DIALOGUE_PATCH_READY revision=1")
	if "--preview-dialogue" in OS.get_cmdline_user_args():
		var app=load("res://scenes/main.tscn").instantiate(); add_child(app)
		app.profile.path="user://galgame-preview-profile.json"
		app.go_story("user://galgame-preview-campaign.json")
		var screen=app.story_screen
		screen.campaign.save_enabled=false; screen.campaign.state=screen.campaign.new_state(); screen.campaign.enter(1,0)
		screen.campaign.hero_at=screen.campaign.map.npc_at[0]+Vector2(0,90); screen.world.focus=screen.campaign.hero_at
		screen.show_npc(0)
		print("DIALOGUE_PREVIEW_READY pages=",screen.dialogue.pages.size())
		if "--capture-dialogue-release" in OS.get_cmdline_user_args():
			for i in 60: await get_tree().process_frame
			screen.dialogue.reveal_all()
			await RenderingServer.frame_post_draw
			var target := folder.get_base_dir().path_join("build/galgame-native-v12.png")
			var error := get_viewport().get_texture().get_image().save_png(target)
			print("DIALOGUE_RELEASE_CAPTURE ",target," error=",error)
			get_tree().quit(error)
	else: get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
