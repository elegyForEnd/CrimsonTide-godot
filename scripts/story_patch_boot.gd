extends Node
## Small release bootstrap: mount verified v9 assets, then the v10 code/art patch.
func _ready() -> void:
	var folder := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"): folder=ProjectSettings.globalize_path("res://").path_join("dist")
	for file in ["CrimsonTide-ForwardPlus-v9.exe","CrimsonTide-Inventory-v10.pck"]:
		if not ProjectSettings.load_resource_pack(folder.path_join(file),true):
			var error := Label.new(); error.text="Cannot load "+file+". Keep the v9 game and inventory patch together."; add_child(error); push_error(error.text); return
	if not FileAccess.file_exists("res://assets/story/items/control-regions.json"):
		push_error("Inventory patch resources missing"); get_tree().quit(1); return
	# Engine initialization precedes base-pack mounting, so restore the game's buses now.
	AudioServer.set_bus_layout(load("res://resources/audio_bus.tres"))
	print("INVENTORY_PATCH_READY revision=1")
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot.tscn")
