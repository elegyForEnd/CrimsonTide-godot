extends SceneTree
## Whitelist whole-portrait UI only; unpublished Boss work never enters the patch.
func add(pack: PCKPacker, target: String, source: String) -> bool:
	var temporary := "res://build/vn-full-pack-"+target.sha256_text()+".bin"
	var input := FileAccess.open(source,FileAccess.READ)
	if input==null:push_error("Missing source "+source);return false
	var output := FileAccess.open(temporary,FileAccess.WRITE);output.store_buffer(input.get_buffer(input.get_length()));output.close()
	return pack.add_file(target,ProjectSettings.globalize_path(temporary))==OK
func _initialize() -> void:
	var patch := PCKPacker.new()
	if patch.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-VN-Full-v14.pck"))!=OK:quit(1);return
	if not ProjectSettings.load_resource_pack("res://build/vn-full-compiled.pck",true):quit(1);return
	for name in ["story_dialogue_ui","story_portrait_art","story_portrait_view","story_portrait_preview","vn_full_gallery"]:
		var path: String="scripts/"+str(name)+".gd"
		var config := ConfigFile.new()
		if config.load("res://"+path+".remap")!=OK:quit(1);return
		var compiled: String=config.get_value("remap","path","")
		if not compiled.ends_with(".gdc") or not add(patch,path+".remap","res://"+path+".remap") or not add(patch,compiled.trim_prefix("res://"),compiled):quit(1);return
	var path := "assets/story/vn-full-v3/manifest.json"
	if not add(patch,path,"res://"+path):quit(1);return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+path))
	if not manifest.get("complete",false):push_error("Whole portrait production is incomplete");quit(1);return
	var count := 0
	for hero in manifest.heroes.values():
		if not hero.ready:quit(1);return
		for poses in hero.portraits.values():
			for expressions in poses.values():
				for source in expressions.values():
					var config := ConfigFile.new()
					if config.load(source+".import")!=OK:quit(1);return
					var imported: String=config.get_value("remap","path","")
					if not add(patch,source.trim_prefix("res://")+".import",source+".import") or not add(patch,imported.trim_prefix("res://"),imported):quit(1);return
					count+=1
	if count!=216:push_error("Expected216 full portraits");quit(1);return
	if patch.flush()!=OK:quit(1);return
	var project := FileAccess.get_file_as_string("res://project.godot").replace("run/main_scene=\"res://scenes/boot.tscn\"","run/main_scene=\"res://vn-full-loader.tscn\"")
	var file := FileAccess.open("res://build/vn-full-launcher-project.godot",FileAccess.WRITE);file.store_string(project);file.close()
	file=FileAccess.open("res://build/vn-full-loader.tscn",FileAccess.WRITE)
	file.store_string("[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://scripts/vn_full_patch_boot.gd\" id=\"1\"]\n[node name=\"VNFullBootstrap\" type=\"Node\"]\nscript=ExtResource(\"1\")\n");file.close()
	var launcher := PCKPacker.new()
	if launcher.pck_start(ProjectSettings.globalize_path("res://dist/CrimsonTide-VN-Full-Launcher.pck"))!=OK:quit(1);return
	var files := {"project.godot":"res://build/vn-full-launcher-project.godot","vn-full-loader.tscn":"res://build/vn-full-loader.tscn","scripts/vn_full_patch_boot.gd":"res://scripts/vn_full_patch_boot.gd","scripts/graphics_quality.gd":"res://scripts/graphics_quality.gd","resources/audio_bus.tres":"res://resources/audio_bus.tres","assets/icon.svg":"res://assets/icon.svg",".godot/global_script_class_cache.cfg":"res://.godot/global_script_class_cache.cfg",".godot/uid_cache.bin":"res://.godot/uid_cache.bin"}
	for target in files:
		if not add(launcher,target,files[target]):quit(1);return
	if launcher.flush()!=OK:quit(1);return
	print("VN_FULL_PACK_READY scripts=5 full_portraits=",count);quit()
