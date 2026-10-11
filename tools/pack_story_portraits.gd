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
	if patch.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-Portraits-v13.pck"))!=OK: quit(1); return
	if not ProjectSettings.load_resource_pack("res://build/portrait-compiled.pck",true): quit(1); return
	for path in ["scripts/story_screen.gd","scripts/story_dialogue_ui.gd","scripts/story_dialogue_data.gd","scripts/story_portrait_art.gd","scripts/story_portrait_view.gd","scripts/story_portrait_preview.gd"]:
		var config := ConfigFile.new()
		if config.load("res://"+path+".remap")!=OK: quit(1); return
		var compiled: String=config.get_value("remap","path","")
		if not compiled.ends_with(".gdc"): push_error("Missing compiled script: "+path); quit(1); return
		if not add(patch,path+".remap","res://"+path+".remap"): return
		if not add(patch,compiled.trim_prefix("res://"),compiled): return
		print("PORTRAIT_COMPILED_SCRIPT ",path," -> ",compiled)
	var manifest_path := "assets/story/portraits/manifest.json"
	if not add(patch,manifest_path,"res://"+manifest_path): return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+manifest_path))
	for hero in manifest.heroes.values():
		if not hero.ready: push_error("Incomplete portrait production"); quit(1); return
		for source in hero.bodies.values()+hero.faces.values():
			var path: String=str(source).trim_prefix("res://")
			var config := ConfigFile.new()
			if config.load(source+".import")!=OK: quit(1); return
			var imported: String=config.get_value("remap","path","")
			if not add(patch,path+".import",source+".import"): return
			if not add(patch,imported.trim_prefix("res://"),imported): return
	if patch.flush()!=OK: quit(1); return
	var project := FileAccess.get_file_as_string("res://project.godot").replace("run/main_scene=\"res://scenes/boot.tscn\"","run/main_scene=\"res://portrait-loader.tscn\"")
	var file := FileAccess.open("res://build/portrait-launcher-project.godot",FileAccess.WRITE); file.store_string(project); file.close()
	file=FileAccess.open("res://build/portrait-loader.tscn",FileAccess.WRITE)
	file.store_string("[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://scripts/portrait_patch_boot.gd\" id=\"1\"]\n[node name=\"PortraitBootstrap\" type=\"Node\"]\nscript=ExtResource(\"1\")\n"); file.close()
	var pack := PCKPacker.new()
	if pack.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-Portraits-Launcher.pck"))!=OK: quit(1); return
	var files := {"project.godot":"res://build/portrait-launcher-project.godot","portrait-loader.tscn":"res://build/portrait-loader.tscn","scripts/portrait_patch_boot.gd":"res://scripts/portrait_patch_boot.gd","scripts/graphics_quality.gd":"res://scripts/graphics_quality.gd","resources/audio_bus.tres":"res://resources/audio_bus.tres","assets/icon.svg":"res://assets/icon.svg",".godot/global_script_class_cache.cfg":"res://.godot/global_script_class_cache.cfg",".godot/uid_cache.bin":"res://.godot/uid_cache.bin"}
	for target in files:
		if not add(pack,target,files[target]): return
	if pack.flush()!=OK: quit(1); return
	print("PORTRAIT_PACKS_READY"); quit()
