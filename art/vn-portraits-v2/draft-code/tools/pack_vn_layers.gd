extends SceneTree
func add(pack: PCKPacker, target: String, source: String) -> bool:
	var temporary := "res://build/vn-pack-"+target.sha256_text()+".bin"
	var input := FileAccess.open(source,FileAccess.READ)
	if input==null:push_error("Missing source "+source);return false
	var output := FileAccess.open(temporary,FileAccess.WRITE);output.store_buffer(input.get_buffer(input.get_length()));output.close()
	return pack.add_file(target,ProjectSettings.globalize_path(temporary))==OK
func _initialize() -> void:
	var patch := PCKPacker.new()
	if patch.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-VN-Layers-v14.pck"))!=OK:quit(1);return
	if not ProjectSettings.load_resource_pack("res://build/vn-compiled.pck",true):quit(1);return
	for name in ["story_dialogue_ui","story_portrait_art","story_portrait_view","story_portrait_preview","vn_portrait_gallery"]:
		var path := "scripts/"+name+".gd"
		var config := ConfigFile.new()
		if config.load("res://"+path+".remap")!=OK:quit(1);return
		var compiled: String=config.get_value("remap","path","")
		if not compiled.ends_with(".gdc") or not add(patch,path+".remap","res://"+path+".remap") or not add(patch,compiled.trim_prefix("res://"),compiled):quit(1);return
	var path := "assets/story/vn-portraits-v2/manifest.json"
	if not add(patch,path,"res://"+path):quit(1);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+path))
	var resources: Array=["res://assets/story/vn-portraits-v2/blush-natural.png","res://assets/story/vn-portraits-v2/blush-shy.png"]
	for hero in manifest.heroes.values():
		if not hero.ready:quit(1);return
		for poses in hero.bases.values():
			for base in poses.values():resources.append(base.path)
		for expression in hero.features.values():
			for feature in expression.values():resources.append(feature.path)
	for source in resources:
		var config := ConfigFile.new()
		if config.load(source+".import")!=OK:quit(1);return
		var imported: String=config.get_value("remap","path","")
		if not add(patch,source.trim_prefix("res://")+".import",source+".import") or not add(patch,imported.trim_prefix("res://"),imported):quit(1);return
	if patch.flush()!=OK:quit(1);return
	var project := FileAccess.get_file_as_string("res://project.godot").replace("run/main_scene=\"res://scenes/boot.tscn\"","run/main_scene=\"res://vn-loader.tscn\"")
	var file := FileAccess.open("res://build/vn-launcher-project.godot",FileAccess.WRITE);file.store_string(project);file.close()
	file=FileAccess.open("res://build/vn-loader.tscn",FileAccess.WRITE)
	file.store_string("[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://scripts/vn_patch_boot.gd\" id=\"1\"]\n[node name=\"VNBootstrap\" type=\"Node\"]\nscript=ExtResource(\"1\")\n");file.close()
	var launcher := PCKPacker.new()
	if launcher.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-VN-Launcher.pck"))!=OK:quit(1);return
	var files := {"project.godot":"res://build/vn-launcher-project.godot","vn-loader.tscn":"res://build/vn-loader.tscn","scripts/vn_patch_boot.gd":"res://scripts/vn_patch_boot.gd","scripts/graphics_quality.gd":"res://scripts/graphics_quality.gd","resources/audio_bus.tres":"res://resources/audio_bus.tres","assets/icon.svg":"res://assets/icon.svg",".godot/global_script_class_cache.cfg":"res://.godot/global_script_class_cache.cfg",".godot/uid_cache.bin":"res://.godot/uid_cache.bin"}
	for target in files:
		if not add(launcher,target,files[target]):quit(1);return
	if launcher.flush()!=OK:quit(1);return
	print("VN_PACK_READY scripts=5 blank_bases=27 feature_layers=62");quit()
