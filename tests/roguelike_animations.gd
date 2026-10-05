extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var art=preload("res://scripts/rogue_art.gd").new()
	for floor_index in 5:
		for variant in 8:
			check(art.packed_sheets.has("minion-hd-%d-%d.png" % [floor_index,variant]),"All 40 generated HD minion sheets are active")
			var size := Vector2.ZERO
			for frame in 16:
				var entry: Dictionary=art.minion_animation(floor_index,variant,frame)
				check(entry.texture!=null,"Each minion has 4 idle, 4 walk and two 4-frame attacks")
				if frame==0: size=entry.texture.get_size()
				check(entry.texture.get_size()==size,"Minion scale is constant between animation poses")
		for frame in 48:
			check(art.boss_animation(floor_index,frame).texture!=null,"Boss has 4 idle + 4 walk + five 8-frame skill animations")
		for skill in 5:
			var key := "boss-hd-%d-skill-%d.png" % [floor_index,skill]
			check(art.packed_sheets.has(key) and art.packed_sheets[key].frames.size()==8,"Every boss skill has exactly eight generated frames")
			var regions: Dictionary={}
			for frame in 8: regions[str(art.boss_animation(floor_index,8+skill*8+frame).texture.region)]=true
			check(regions.size()==8,"Eight boss frames map to eight distinct atlas regions")
		for variant in 8:
			for skill in 2:
				var clip: AudioStream=load("res://assets/audio/rogue/rogue-minion-%d-%d-%d.wav" % [floor_index,variant,skill])
				check(clip!=null and clip.get_length()>.3,"Each minion move has real audio")
		for frame in 4: check(art.spell_animation(floor_index,frame)!=null,"Each floor has four generated VFX frames")
		for move in 5:
			for action in ["charge","release"]:
				var clip: AudioStream=load("res://assets/audio/rogue/rogue-%d-%d-%s.wav" % [floor_index,move,action])
				check(clip!=null and clip.get_length()>0.5,"Individual boss cue contains real audio")
	for key in art.region_manifest:
		if not (key.begins_with("boss-") or key.begins_with("minion-") or key.begins_with("effects-")): continue
		for entry in art.region_manifest[key]:
			check(entry.x-entry.cell_x>=64 and entry.y-entry.cell_y>=64 and entry.cell_x+entry.cell_w-entry.x-entry.w>=64 and entry.cell_y+entry.cell_h-entry.y-entry.h>=64,"Every animation cell has at least 64px transparent padding: "+key)
	var file := FileAccess.open("res://assets/rogue/animations/runtime-regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(art.region_manifest,"\t"))
	print("ROGUE ANIMATION ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
