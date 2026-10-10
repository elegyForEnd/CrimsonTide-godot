@tool
extends EditorPlugin
func descendants(node: Node) -> Array:
	var found: Array=[]
	for child in node.get_children(true):
		found.append(child); found.append_array(descendants(child))
	return found
func _enter_tree() -> void:
	if "--bake-opening" in OS.get_cmdline_user_args(): call_deferred("bake_opening")
func bake_opening() -> void:
	var requested := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bake-scene="): requested=arg.trim_prefix("--bake-scene=")
	for i in 60: await get_tree().process_frame
	# Scene restoration and EXR imports can replace the edited root. Wait for
	# filesystem work to settle, and don't reopen a scene already restored.
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().create_timer(.25).timeout
	var current := EditorInterface.get_edited_scene_root()
	if not requested.is_empty() and (current==null or current.scene_file_path!=requested): EditorInterface.open_scene_from_path(requested)
	for i in 180:
		await get_tree().process_frame
		var edited := EditorInterface.get_edited_scene_root()
		if edited!=null and edited.is_inside_tree() and (requested.is_empty() or edited.scene_file_path==requested): break
	var scene := EditorInterface.get_edited_scene_root()
	if scene==null: push_error("BAKE_BATCH no open scene"); return
	for i in 12: await get_tree().create_timer(.1).timeout
	if EditorInterface.get_edited_scene_root()!=scene or not scene.is_inside_tree():
		push_error("BAKE_BATCH failed: scene restoration is not stable"); return
	var gi: LightmapGI=scene.get_node("BakedIndirectLight")
	EditorInterface.set_main_screen_editor("3D")
	EditorInterface.edit_node(gi)
	for i in 10: await get_tree().process_frame
	if not scene.is_inside_tree() or not gi.is_inside_tree() or EditorInterface.get_edited_scene_root()!=scene:
		push_error("BAKE_BATCH failed: edited scene changed before bake"); return
	var bake_path := scene.scene_file_path.get_basename()+".lmbake"
	var previous_time := FileAccess.get_modified_time(bake_path)
	var buttons := EditorInterface.get_base_control().find_children("*","Button",true,false)
	var bake_button: Button
	for button in buttons:
		if "Bake Lightmaps" in button.text or "烘焙光照贴图" in button.text:
			bake_button=button; break
	if bake_button==null:
		for button in buttons:
			if "Bake" in button.text or "烘焙" in button.text: print("BAKE_BUTTON ",button.text)
		push_error("BAKE_BATCH toolbar unavailable"); return
	print("BAKE_BATCH begin ",scene.scene_file_path)
	bake_button.pressed.emit()
	for i in 10: await get_tree().process_frame
	if gi.light_data==null:
		for dialog in descendants(get_tree().root):
			if dialog.get_class()=="EditorFileDialog" and dialog.visible:
				print("BAKE_BATCH save ",dialog.get_class())
				dialog.emit_signal("file_selected",scene.scene_file_path.get_basename()+".lmbake")
				dialog.hide(); break
	for i in 300:
		await get_tree().process_frame
		if gi.light_data!=null and FileAccess.get_modified_time(bake_path)>previous_time: break
	if gi.light_data==null or FileAccess.get_modified_time(bake_path)<=previous_time:
		push_error("BAKE_BATCH failed: bake resource was not updated "+scene.scene_file_path); return
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.save_scene()
	var packed := PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed,scene.scene_file_path.get_basename()+".scn",ResourceSaver.FLAG_COMPRESS)
	print("BAKE_BATCH complete ",gi.light_data.resource_path)
