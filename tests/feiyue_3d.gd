extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	var library := CharacterFrames.new()
	if not CharacterFrames.USE_FEIYUE_3D:
		check(not library.has_rendered_hero(0),"Feiyue sprite rollback is active")
		check(library.feiyue==null,"Inactive 3D assets are not loaded")
		for row in 3:
			check(library.movement[0][row].size()==4,"Original movement sprite sheet restored")
			for pose in library.attacks[0][row]:
				check(not pose.texture.atlas.resource_path.contains("/feiyue-3d/"),"Previous attack sprites restored")
		print("FEIYUE SPRITE ROLLBACK: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	check(library.has_rendered_hero(0),"Feiyue uses rendered character")
	check(not library.has_rendered_hero(1),"Other heroes retain their existing art")
	for row in 3:
		check(library.attacks[0][row].size()==8,"Eight attack poses")
		check(library.movement[0][row].size()==8,"Eight movement poses")
		check(library.movement[1][row].size()==4,"Other heroes retain four movement poses")
	for mode in ["walk","run"]:
		for index in 8:
			var pose := library.motion_frame(0,mode,index*0.5,0.0)
			check(pose.texture.atlas.resource_path.ends_with("%s/%03d.png" % [mode,index]),"All movement poses reached in order")
		check(library.motion_frame(0,mode,4.0,0.0).texture.atlas.resource_path.ends_with("000.png"),"Movement wraps at the existing cadence")
	for index in 8:
		var remaining := TideSession.DODGE_DURATION*(1.0-(index+0.1)/8.0)
		check(library.motion_frame(0,"dodge",0.0,remaining).texture.atlas.resource_path.ends_with("dodge/%03d.png" % index),"All dodge poses reached")
	for weapon in 4:
		var frames: Array=library.feiyue_idle[weapon]
		check(frames.size()==8,"Eight idle poses for each loadout")
		for index in 8:
			check(library.idle_frame(0,weapon,index).texture.atlas.resource_path.contains("/feiyue-3d/"),"Idle draws the rendered character")
	for key in library.feiyue.manifest:
		var poses := library.feiyue.frames(key)
		for pose in poses:
			var ratio: Vector2=pose.rect.size/pose.texture.get_size()
			var ground: Vector2=pose.rect.position+Vector2(pose.landmark.x,pose.landmark.y)*ratio
			check(ground.distance_to(CharacterMetrics.FOOT_OFFSET)<0.001,"Stable origin across every clip")
			check(is_equal_approx(pose.standing_height,library.walk_height(0)),"Shared body scale across every clip")
	for weapon in range(1,4):
		var frame := GeneratedAttacks.timeline_frame(0.4,0.8,0.4)
		check(library.attack_frame(0,weapon,frame).texture.atlas.resource_path.ends_with("004.png"),"Rendered impact matches gameplay hit")
	print("FEIYUE 3D: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
