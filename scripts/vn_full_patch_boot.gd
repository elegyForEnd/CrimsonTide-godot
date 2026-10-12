extends Node
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Combat-v11.pck","CrimsonTide-Dialogue-v12.pck","CrimsonTide-Portraits-v13.pck","CrimsonTide-VN-Full-v14.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var notice := Label.new();notice.text="无法读取 "+file+"，请保留配套资源包。";add_child(notice);push_error(notice.text);return
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("VN_FULL_PATCH_READY revision=3")
	if "--vn-full-gallery" in OS.get_cmdline_user_args():
		get_tree().root.size=Vector2i(1440,900);get_tree().root.content_scale_size=Vector2i(1440,900)
		add_child(load("res://scripts/vn_full_gallery.gd").new())
	elif "--preview-portraits" in OS.get_cmdline_user_args():
		var app=load("res://scenes/main.tscn").instantiate();add_child(app)
		var preview=load("res://scripts/story_portrait_preview.gd").new();preview.app=app;add_child(preview)
	else:get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
