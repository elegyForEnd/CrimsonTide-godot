extends SceneTree
func _initialize() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot").replace("run/main_scene=\"res://scenes/boot.tscn\"","run/main_scene=\"res://inventory-loader.tscn\"")
	var file := FileAccess.open("res://build/inventory-launcher-project.godot",FileAccess.WRITE); file.store_string(project); file.close()
	file=FileAccess.open("res://build/inventory-loader.tscn",FileAccess.WRITE)
	file.store_string("[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://scripts/story_patch_boot.gd\" id=\"1\"]\n[node name=\"InventoryBootstrap\" type=\"Node\"]\nscript=ExtResource(\"1\")\n"); file.close()
	var pack := PCKPacker.new(); var path := "res://dist/CrimsonTide-Inventory-Launcher.pck"
	var err := pack.pck_start(ProjectSettings.globalize_path(path))
	if err!=OK: quit(1); return
	var files := {"project.godot":"res://build/inventory-launcher-project.godot","inventory-loader.tscn":"res://build/inventory-loader.tscn","scripts/story_patch_boot.gd":"res://scripts/story_patch_boot.gd","scripts/graphics_quality.gd":"res://scripts/graphics_quality.gd","resources/audio_bus.tres":"res://resources/audio_bus.tres",".godot/global_script_class_cache.cfg":"res://.godot/global_script_class_cache.cfg",".godot/uid_cache.bin":"res://.godot/uid_cache.bin"}
	files["assets/icon.svg"]="res://assets/icon.svg"
	for target in files:
		if pack.add_file(target,ProjectSettings.globalize_path(files[target]))!=OK: quit(1); return
	if pack.flush()!=OK: quit(1); return
	print("INVENTORY_LAUNCHER_READY "+path); quit()
