extends SceneTree

func _initialize() -> void:
	var entries: Array=[]
	var Map=preload("res://scripts/rogue_map.gd")
	for floor_index in 5:
		for kind in ["a1","a2","a3","a4","a5","a6","a7","shop","treasure","talent","curse","event","forge","gamble","mirror"]:
			var area: int=int(kind.substr(1)) if kind.begins_with("a") else 1
			var room: String="" if area<=5 and kind.begins_with("a") else "combat" if kind.begins_with("a") else kind
			# Combat rows 2 and 4 select the dedicated a6 and a7 artwork.
			if kind=="a6": area=2
			elif kind=="a7": area=4
			var map=Map.new()
			map.generate(1729)
			map.configure(floor_index,area,kind.begins_with("a"),room)
			var points: Array=[]
			for p in map.floor_polygon: points.append([p.x/map.width,p.y/map.extent.y])
			entries.append({"key":"f%d-%s" % [floor_index+1,kind],"texture":Map.texture_path(Map.region_key(floor_index,area,room)),"outline":points,"holes":map.region.get("ground_holes",[]),"exits":map.region.exits})
	DirAccess.make_dir_recursive_absolute("res://build/fork-audit")
	var file=FileAccess.open("res://build/fork-audit/geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(entries,"\t"))
	print("EXPORTED ",entries.size()," CURRENT MAP FORKS")
	quit()
