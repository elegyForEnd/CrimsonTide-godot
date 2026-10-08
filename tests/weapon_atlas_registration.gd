extends SceneTree
const Library=preload("res://scripts/weapon_atlas_frames.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var library := Library.new()
	check(library.count(0,600,"attack")==4,"Crimson sword uses exactly four attack keys")
	check(library.count(0,1,"attack")==4,"Same-name campaign alias shares the concrete sword")
	check(library.atlas_key(0,600)!=library.atlas_key(0,608),"Different concrete weapons never share an atlas implicitly")
	check(not library.manifest.has("0/sword"),"Stopped type-shared draft is not loaded")
	var frames := CharacterFrames.new()
	var height := frames.walk_height(0)
	for key: String in library.manifest:
		var atlas: Dictionary=library.manifest[key]
		var weapon := int(key.split("/")[1])
		var hero := int(key.split("/")[0])
		for state: String in atlas.states:
			if state not in ["attack","art"]: continue
			# This test checks hand-reviewed support landmarks. The complete
			# automatic registration matrix is covered by weapon_raw_integration.
			if not atlas.get("anchor_review",{}).get("support_points",{}).has(state): continue
			check(atlas.states[state].size()==4,"Each authored attack/action has four meaningful keys")
			var registered := Vector2.ZERO
			for i in 4:
				var pose := library.frame(hero,weapon,state,i,height)
				var entry: Dictionary=atlas.states[state][i]
				var texture: AtlasTexture=pose.texture
				var original := texture.atlas.get_image()
				var region := Rect2i(texture.region)
				var border_clear := true
				for x in range(region.position.x,region.end.x):
					if original.get_pixel(x,region.position.y).a>.4 or original.get_pixel(x,region.end.y-1).a>.4: border_clear=false
				for y in range(region.position.y,region.end.y):
					if original.get_pixel(region.position.x,y).a>.4 or original.get_pixel(region.end.x-1,y).a>.4: border_clear=false
				check(border_clear,"Each frame has a clear transparent border")
				check(pose.weapon_identity==weapon,"Concrete weapon identity survives frame selection")
				check(pose.standing_height==height,"No per-frame body resizing")
				var scale := height/float(atlas.get("clip_heights",{}).get(state,atlas.page_heights[entry.file]))
				var point: Array=atlas.anchor_review.support_points[state][i]
				var source := Vector2(point[0],point[1])
				check(original.get_pixelv(Vector2i(source)).a>.5,"Support point is on the actual painted boot")
				var support: Vector2=pose.rect.position+(source-Vector2(entry.region[0],entry.region[1]))*scale
				if i==0: registered=support
				check(support.distance_to(registered)<.001,"Planted rear boot stays registered")
			var p := {"hero":hero,"weapon":weapon,"swing_total":.42,"swing_time":.42,"cast_time":0.0,"build_strike_windup":.10}
			var previous := -1
			for tick in 421:
				var elapsed := tick*.001
				p.swing_time=.42-elapsed
				var index := library.attack_index(p,state)
				check(index>=previous and index<4,"Four-key timeline stays chronological")
				check(index<2 if elapsed<.10-.00001 else index>=2,"Hit key follows the real windup")
				previous=index
			check(previous==3,"Timeline reaches recovery")
	print("WEAPON ATLAS REGISTRATION %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

