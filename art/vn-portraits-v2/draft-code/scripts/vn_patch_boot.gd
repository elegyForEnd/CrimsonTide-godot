extends Node
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Combat-v11.pck","CrimsonTide-Dialogue-v12.pck","CrimsonTide-Portraits-v13.pck","CrimsonTide-VN-Layers-v14.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var label := Label.new();label.text="无法读取 "+file+"，请保留配套资源包。";add_child(label);push_error(label.text);return
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("VN_LAYER_PATCH_READY revision=2")
	if "--vn-gallery" in OS.get_cmdline_user_args():
		get_tree().root.size=Vector2i(1440,900);get_tree().root.content_scale_size=Vector2i(1440,900)
		add_child(load("res://scripts/vn_portrait_gallery.gd").new())
	else:get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
