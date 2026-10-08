extends SceneTree
const Library=preload("res://scripts/weapon_atlas_frames.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var library := Library.new()
	var images := {}
	for hero in 4:
		for weapon in range(600,648):
			for state in ["attack","art"]:
				var entry: Dictionary=library.manifest["%d/%d" % [hero,weapon]].states[state][2]
				var file: String=entry.file
				if not images.has(file): images[file]=load(Library.BASE+file).get_image()
				var image: Image=images[file]
				var point := Vector2i(roundi(float(entry.socket[0])+entry.region[0]),roundi(float(entry.socket[1])+entry.region[1]))
				var ink := false
				for dy in range(-2,3):
					for dx in range(-2,3):
						var pixel := point+Vector2i(dx,dy)
						if pixel.x>=0 and pixel.y>=0 and pixel.x<image.get_width() and pixel.y<image.get_height(): ink=ink or image.get_pixelv(pixel).a>.35
				check(ink,"Mount detached from original pixels %d/%d/%s" % [hero,weapon,state])
				var pose := library.frame(hero,weapon,state,2,100)
				check(Vector2(pose.socket).distance_to(pose.grip)>1,"Missing blade direction %d/%d/%s" % [hero,weapon,state])
				# Painted contact mapping is valid under any released aim and mirror.
				var role := preload("res://scripts/weapon_mechanics.gd").normal_role(weapon)
				var source := Art.release_source(weapon,role,0)
				var contact := Art.mechanic_contact(role,Vector2(120,100),source)
				for side in [-1,1]:
					var tip := Vector2(pose.socket)*Vector2(side,1)
					var axis := (Vector2(pose.socket)-Vector2(pose.grip))*Vector2(side,1)
					var angle := axis.angle()
					var mirror := Vector2(1,side)
					var transform := Transform2D(angle,mirror,0,tip-(contact*mirror).rotated(angle))
					check((transform*contact).distance_to(tip)<.01,"Mirrored contact shifted %d/%d/%s" % [hero,weapon,state])
			library.poses.clear()
	print("WEAPON MOUNTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
