extends SceneTree
const Glow=preload("res://scripts/weapon_held_glow.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
var failures := 0
func _initialize() -> void:
	for weapon in range(600,648):
		var pose := {"weapon_atlas":true,"weapon_identity":weapon,"state":"idle","socket":Vector2(24,-65),"standing_height":140}
		for time in [0.0,.6,1.2,2.4]:
			var accents := Glow.samples(pose,time)
			check(not accents.is_empty(),"Missing held accent %d" % weapon)
			for accent in accents:
				check(accent.texture!=null,"Missing texture %d" % weapon)
				check(accent.tint.a>=0 and accent.tint.a<=.32,"Too bright %d" % weapon)
				var ink := Art.mechanic_ink(accent.source)
				var scale: Vector2=accent.rect.size/accent.texture.get_size()
				check((ink.size*scale).length()<21,"Oversized held accent %d" % weapon)
				var center: Vector2=accent.rect.position+ink.get_center()*scale
				check(center.distance_to(CharacterMetrics.FOOT_OFFSET+pose.socket)<8,"Detached held accent %d" % weapon)
		pose.state="attack"
		check(Glow.samples(pose,1).is_empty(),"Attack duplicates held effect %d" % weapon)
		pose.state="art"
		check(Glow.samples(pose,1).is_empty(),"Art duplicates held effect %d" % weapon)
	check(Glow.samples({},0).is_empty(),"Unequipped pose glows")
	print("HELD GLOW: 48 weapons, brightness/size/attachment/action checks; %d failures" % failures)
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
