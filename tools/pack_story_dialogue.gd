extends SceneTree
## Explicit patch whitelist excludes unfinished Boss presentation and model assets.
func add(pack: PCKPacker, target: String, source: String) -> bool:
	# PCKPacker requires a physical source; mounted-pack paths must be extracted.
	var temporary := "res://build/dialogue-pack-"+target.sha256_text()+".bin"
	var input := FileAccess.open(source,FileAccess.READ)
	if input==null: push_error("Missing pack source: "+source); quit(1); return false
	var output := FileAccess.open(temporary,FileAccess.WRITE)
	output.store_buffer(input.get_buffer(input.get_length())); output.close()
	if pack.add_file(target,ProjectSettings.globalize_path(temporary))!=OK: push_error("pack failed: "+source); quit(1); return false
	return true
func _initialize() -> void:
	var patch := PCKPacker.new()
	if patch.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-Dialogue-v12.pck"))!=OK: quit(1); return
	if not ProjectSettings.load_resource_pack("res://build/dialogue-compiled.pck",true): quit(1); return
	for path in ["scripts/story_screen.gd","scripts/story_dialogue_ui.gd","scripts/story_dialogue_data.gd"]:
		var config := ConfigFile.new()
		if config.load("res://"+path+".remap")!=OK: quit(1); return
		var compiled: String=config.get_value("remap","path","")
		if not compiled.ends_with(".gdc"): push_error("Missing compiled script: "+path); quit(1); return
		if not add(patch,path+".remap","res://"+path+".remap"): return
		if not add(patch,compiled.trim_prefix("res://"),compiled): return
		print("DIALOGUE_COMPILED_SCRIPT ",path," -> ",compiled)
	if patch.flush()!=OK: quit(1); return
	var project := FileAccess.get_file_as_string("res://project.godot").replace("run/main_scene=\"res://scenes/boot.tscn\"","run/main_scene=\"res://dialogue-loader.tscn\"")
	var file := FileAccess.open("res://build/dialogue-launcher-project.godot",FileAccess.WRITE); file.store_string(project); file.close()
	file=FileAccess.open("res://build/dialogue-loader.tscn",FileAccess.WRITE)
	file.store_string("[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://scripts/dialogue_patch_boot.gd\" id=\"1\"]\n[node name=\"DialogueBootstrap\" type=\"Node\"]\nscript=ExtResource(\"1\")\n"); file.close()
	var pack := PCKPacker.new()
	if pack.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-Dialogue-Launcher.pck"))!=OK: quit(1); return
	var files := {"project.godot":"res://build/dialogue-launcher-project.godot","dialogue-loader.tscn":"res://build/dialogue-loader.tscn","scripts/dialogue_patch_boot.gd":"res://scripts/dialogue_patch_boot.gd","scripts/graphics_quality.gd":"res://scripts/graphics_quality.gd","resources/audio_bus.tres":"res://resources/audio_bus.tres","assets/icon.svg":"res://assets/icon.svg",".godot/global_script_class_cache.cfg":"res://.godot/global_script_class_cache.cfg",".godot/uid_cache.bin":"res://.godot/uid_cache.bin"}
	for target in files:
		if not add(pack,target,files[target]): return
	if pack.flush()!=OK: quit(1); return
	print("DIALOGUE_PACKS_READY"); quit()
