extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	var library := GeneratedAttacks.new()
	check(library.manifest.size()==19,"All 9 hero and 10 boss attacks installed")
	for key in library.manifest:
		var poses := library.frames(key)
		check(poses.size()==8,"Eight ordered frames: "+key)
		var spec: Dictionary=library.manifest[key]
		var origin := CharacterMetrics.FOOT_OFFSET if str(key).begins_with("heroes/") else Vector2.ZERO
		for pose in poses:
			var texture: Texture2D=pose.texture
			var rect: Rect2=pose.rect
			var scale := rect.size/texture.get_size()
			check(absf(scale.x-scale.y)<0.001,"Uniform scale, no squashing: "+key)
			check((rect.position+Vector2(spec.pivot[0],spec.pivot[1])*scale).distance_to(origin)<0.001,"Fixed ground origin: "+key)
			check(texture.get_image().get_pixel(0,0).a==0,"Transparent canvas: "+key)
			check(rect==poses[0].rect,"Same canvas and scale across an action: "+key)
	var characters := CharacterFrames.new()
	for hero in 3:
		for weapon in range(1,4):
			check(characters.has_generated(hero,weapon)==CharacterFrames.USE_GENERATED_HERO_ANIMATIONS,"Hero animation source follows the selected mode")
			if CharacterFrames.USE_GENERATED_HERO_ANIMATIONS:
				var opening := characters.attack_frame(hero,weapon,0)
				check(is_equal_approx(opening.standing_height,characters.walk_height(hero)),"Attack body matches walking height")
		print("Hero %d walking / attack body height: %.2f" % [hero,characters.walk_height(hero)])
	check(not characters.has_generated(3,1),"Deferred Muyu keeps existing art")
	var bosses := BossFrames.new()
	for key in BossFrames.KEYS+BossFrames.SPECIAL_KEYS:
		var e := {"hp":100,"attack_time":2.0,"attack_total":2.0,"windup":1.0,"attack_marks":[1.0]}
		check(bosses.attack_sprite(key,e).texture.atlas.resource_path.ends_with("000.png"),"Boss action mapped: "+key)
		e.attack_time=1.0
		check(bosses.attack_sprite(key,e).texture.atlas.resource_path.ends_with("004.png"),"Impact frame matches damage timing")
		e.stagger=0.2
		check(bosses.attack_sprite(key,e).is_empty(),"Stagger interrupts the attack art")
	for i in 8:
		var time := i*0.1+0.01
		check(GeneratedAttacks.timeline_frame(time,0.8,0.4)==i,"All frames reached in order")
	check(GeneratedAttacks.timeline_frame(1.0,2.0,1.0)==4,"Damage occurs at impact frame")
	var combo := {"hp":100,"attack_total":2.45,"attack_time":1.80,"attack_marks":[0.65,1.10,2.05]}
	for mark in combo.attack_marks:
		combo.attack_time=combo.attack_total-mark
		check(bosses.attack_sprite("thorn-huntsman",combo).texture.atlas.resource_path.ends_with("004.png"),"Each combo strike has its own impact")
	print("GENERATED ATTACKS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
