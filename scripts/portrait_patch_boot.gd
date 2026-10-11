extends Node
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"): folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Combat-v11.pck","CrimsonTide-Dialogue-v12.pck","CrimsonTide-Portraits-v13.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var label := Label.new();label.text="无法读取 "+file+"，请将运行文件和配套资源包放在同一目录。";add_child(label);push_error(label.text);return
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("PORTRAIT_PATCH_READY revision=1")
	if "--preview-portraits" in OS.get_cmdline_user_args():
		var app=load("res://scenes/main.tscn").instantiate();add_child(app)
		var preview=load("res://scripts/story_portrait_preview.gd").new();preview.app=app;add_child(preview)
	else:get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
