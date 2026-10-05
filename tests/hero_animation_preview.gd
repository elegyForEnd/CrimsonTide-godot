extends SceneTree

func _initialize() -> void:
	var library := CharacterFrames.new()
	var failures := 0
	if not CharacterFrames.USE_GENERATED_HERO_ANIMATIONS:
		for hero in Catalog.HEROES.size():
			for row in 3:
				for group in [library.attacks,library.movement]:
					if group[hero][row].size()!=4: failures+=1
					for pose in group[hero][row]:
						var expected := "attack-clean" if group==library.attacks else "movement"
						if pose.texture.atlas.resource_path != "res://assets/combat/%s-%d.png" % [expected,hero]: failures+=1
		print("ORIGINAL HERO ATLAS: all heroes use original four-frame actions; failures=",failures)
		quit(1 if failures else 0)
		return
	for spec in [[0,"walk",8],[1,"walk",4],[2,"walk",4]]:
		var hero: int=spec[0]
		var poses: Array=library.movement[hero][0]
		if poses.size()!=int(spec[2]): failures+=1
		for frame in poses.size():
			var pose := library.motion_frame(hero,"walk",float(frame)*4.0/poses.size(),0.0)
			if not pose.texture.atlas.resource_path.ends_with("hero-%d/walk/%03d.png" % [hero,frame]): failures+=1
			if not pose.texture.atlas.resource_path.contains("hero-animation-preview"): failures+=1
	for frame in 8:
		if not library.attack_frame(0,1,frame).texture.atlas.resource_path.ends_with("hero-0/sword/%03d.png" % frame): failures+=1
		if not library.attack_frame(0,1,frame).texture.atlas.resource_path.contains("hero-animation-preview"): failures+=1
	if library.movement[0][1].size()!=4 or library.movement[0][2].size()!=4: failures+=1
	var sword: Dictionary=library.animation_preview.manifest["heroes/hero-0/sword"]
	# These impact poses have a lower front shoe; regression would anchor it
	# instead of the rear shoe and make the whole character jump sideways.
	var hit: Array=sword.source_anchors[4]
	var follow: Array=sword.source_anchors[5]
	if Vector2(hit[0],hit[1]).distance_to(Vector2(204,1040))>0.01: failures+=1
	if Vector2(follow[0],follow[1]).distance_to(Vector2(197,1046))>0.01: failures+=1
	var walk: Dictionary=library.animation_preview.manifest["heroes/hero-0/walk"]
	for anchor in walk.source_anchors:
		if Vector2(anchor[0],anchor[1]).distance_to(Vector2(735,1166))>0.01: failures+=1
	print("HERO ANIMATION PREVIEW: paths, all motion frames and attack frames verified; failures=",failures)
	quit(1 if failures else 0)
