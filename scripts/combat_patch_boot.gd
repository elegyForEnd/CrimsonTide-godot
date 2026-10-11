extends Node
## v11 small runtime mounts existing world assets plus current code/art patch.
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"): folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Combat-v11.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var error := Label.new(); error.text="Cannot load "+file+". Keep v11 runtime, patch and v9 base together."; add_child(error); push_error(error.text); return
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("COMBAT_PATCH_READY revision=2")
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
