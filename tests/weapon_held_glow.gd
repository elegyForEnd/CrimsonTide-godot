extends SceneTree
const Glow=preload("res://scripts/weapon_held_glow.gd")
const Atlases=preload("res://scripts/weapon_atlas_frames.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	var atlases := Atlases.new()
	var lit := 0
	var unlit: Array=[]
	for hero in 4:
		for weapon in range(600,648):
			for state in ["idle","walk","run","dodge"]:
				for frame in 4:
					var pose := atlases.frame(hero,weapon,state,frame,140)
					if pose.is_empty(): continue
					var image: Image=pose.texture.get_image()
					var accents := Glow.samples(pose,.6)
					if not accents.is_empty(): lit+=1
					else: unlit.append({"hero":hero,"weapon":weapon,"state":state,"frame":frame})
					if hero==0 and weapon==600: check(not accents.is_empty(),"Crimson sword surface is unlit")
					for accent in accents:
						check(accent.texture is GradientTexture2D and accent.source=="held_surface","Attack painting reused")
						check(accent.tint.a<=.23 and accent.rect.size.length()<15,"Held glow too strong")
						var pixel: Vector2i=Vector2i((accent.center-pose.rect.position)/pose.rect.size*pose.texture.get_size())
						check(image.get_pixelv(pixel).a>.7,"Held light floats off material")
					pose.state="attack"
					check(Glow.samples(pose,1).is_empty(),"Attack duplicates held effect")
	check(Glow.samples({},0).is_empty(),"Unequipped pose glows")
	var file := FileAccess.open("res://build/weapon-full-audit/held-surface-coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"lit":lit,"unlit":unlit,"reason":"No opaque material was found along the authored grip-to-tip segment; skip instead of lighting empty space."},"\t"))
	file.close()
	print("HELD SURFACE: %d checks, %d lit poses, %d failures" % [checks,lit,failures])
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
