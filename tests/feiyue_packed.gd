extends SceneTree

func _initialize() -> void:
	var executable := ProjectSettings.globalize_path("res://dist/CrimsonTide-feiyue-3d.exe")
	if not ProjectSettings.load_resource_pack(executable):
		push_error("Cannot load embedded Windows resource pack")
		quit(1)
		return
	var library := GeneratedAttacks.new("res://assets/combat/feiyue-3d/manifest.json")
	var count := 0
	for key in library.manifest:
		var entry: Dictionary=library.manifest[key]
		if entry.get("motion_license","")!="CC0 1.0" or str(entry.get("motion_source","")).is_empty():
			push_error("Windows pack contains outdated motion manifest: "+key)
			quit(1)
			return
		var poses := library.frames(key)
		for pose in poses:
			if pose.texture.get_image().is_empty():
				push_error("Missing exported sprite: "+key)
				quit(1)
				return
			count+=1
	print("FEIYUE WINDOWS PACK: %d sprites loaded from embedded resource pack" % count)
	quit(0 if count==80 else 1)
