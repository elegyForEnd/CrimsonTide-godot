extends SceneTree
const Art=preload("res://scripts/weapon_image_art.gd")
const Library=preload("res://scripts/vfx_library.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var identities := {}
	var weapons: Array=[]
	for index in 21: weapons.append(index)
	for index in range(600,648): weapons.append(index)
	for index in weapons:
		check(Art.available(index),"Every concrete weapon has a generated square primary image")
		var texture := Art.texture(index,0)
		if texture==null: continue
		check(not texture is AtlasTexture and texture.get_width()==texture.get_height(),"Weapon art is one independent square, never a strip")
		check(texture.get_width()>=1024,"Weapon art retains original HD pixels")
		check(texture.resource_path.begins_with(Art.BASE),"Generated art is installed in the project")
		if index>=600: identities[texture.resource_path]=true
		for stage in 3:
			var phase: String=["release","return","finisher"][stage]
			check(Library.texture(Library.weapon_key(index,phase))!=null,"Every combo phase resolves a painted primary")
			if stage>0 and index!=600 and index!=1: check(Art.overlay(index,stage)!=null,"Counter-cut and finisher add a distinct painted combo layer")
	check(identities.size()==48,"48 run weapons use 48 different primary PNGs")
	check(Art.texture(600,0)!=Art.texture(600,1) and Art.texture(600,1)!=Art.texture(600,2),"Crimson sword uses three separately generated square images")
	for core in range(1,13):
		var texture := Art.core_texture(core)
		check(texture!=null,"Actual core %d has its own painted trigger image" % core)
		if texture: check(texture.get_width()==texture.get_height() and not texture is AtlasTexture,"Core effects use independent square art")
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(Art.BASE+"manifest.json"))
	check(manifest is Dictionary and manifest.assets.size()==74,"All 74 originals are tracked with prompts and hashes")
	if manifest is Dictionary:
		for entry in manifest.assets.values():
			check(entry.size[0]==entry.size[1] and entry.frames.size()==1,"Source metadata contains no multi-panel or long-strip assets")
	print("WEAPON SQUARE ART ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
