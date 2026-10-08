extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var art = preload("res://scripts/rogue_art.gd").new()
	var region_paths: Dictionary={}
	for floor_index in 5:
		for area in range(1,6):
			var background: Texture2D=art.region_background(floor_index,area)
			check(background!=null,"Every region loads its own background: %d/%d" % [floor_index+1,area])
			if background: region_paths[background.resource_path]=true
	check(region_paths.size()==25,"All 25 areas use distinct background resources")
	check(art.monster_frames.size()==20 and art.item_icons.size()==16 and art.prop_icons.size()==12,"All generated assets available")
	for key in art.region_manifest:
		for entry in art.region_manifest[key]:
			check(entry.x>entry.cell_x and entry.y>entry.cell_y and entry.x+entry.w<entry.cell_x+entry.cell_w and entry.y+entry.h<entry.cell_y+entry.cell_h,"Transparent padding surrounds every asset: "+key)
	# The dump is a build artifact that nothing in the project reads (ROGUELIKE.md:106 only
	# documents it), so it lives in the gitignored build/ dir: res://assets/ is not writable in
	# every environment (a sandboxed host refuses it and FileAccess.open returns null), and the
	# old null deref aborted the run before the terrain half and the summary line ever ran.
	DirAccess.make_dir_recursive_absolute("res://build")
	var manifest_file := FileAccess.open("res://build/atlas-regions.json",FileAccess.WRITE)
	if manifest_file==null:
		check(false,"atlas-regions dump opens for writing (FileAccess error %d)" % FileAccess.get_open_error())
	else:
		manifest_file.store_string(JSON.stringify(art.region_manifest,"\t"))
		manifest_file.close()
	var Map = preload("res://scripts/rogue_map.gd")
	for floor_index in 5:
		for area in [1,3,5]:
			var map=Map.new()
			map.generate(1729+floor_index*100+area)
			map.configure(floor_index,area,true)
			# Sample the actual collision map, not an implementation mirror.
			var spawn: Vector2=map.safe_point(Vector2(330,map.lane_center(330)),20)
			var frontier: Array[Vector2]=[spawn]
			var visited: Dictionary={Vector2i(spawn):true}
			var reached := false
			while not frontier.is_empty():
				var at: Vector2=frontier.pop_back()
				if at.x>map.width-260: reached=true; break
				for step in [Vector2(20,0),Vector2(-20,0),Vector2(0,20),Vector2(0,-20)]:
					var next: Vector2=at+step
					var cell := Vector2i(next)
					if visited.has(cell) or map.blocked(next,20) or map.on_lava(next): continue
					visited[cell]=true
					frontier.append(next)
			check(reached,"Exit reachable while avoiding obstacles and lava: %d/%d" % [floor_index,area])
	print("ROGUE ART / TERRAIN ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
