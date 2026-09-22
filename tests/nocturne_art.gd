extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	for kind in EnemyFrames.FILES.size():
		if kind==4: continue
		var file: String=EnemyFrames.FILES[kind]
		var raw := Image.load_from_file("res://output/imagegen/"+file+"-raw.png")
		check(raw!=null and raw.detect_alpha()!=Image.ALPHA_NONE,"Generated source has real alpha: "+file)
		if file in ["grave-gargoyle","drowned-bell-wraith","lantern-executioner","moon-monolith-colossus","sunken-bell-carcass","blood-coffin-warden"]:
			check(raw.get_size()==Vector2i(4096,3072),"Heavy monster keeps an exact 4K 4:3 master: "+file)
		var sheet := Image.load_from_file("res://assets/enemies/"+file+".png")
		check(sheet!=null and sheet.get_size()==Vector2i(1024,768),"Canonical atlas dimensions: "+file)
		for frame in 12:
			var cell := sheet.get_region(Rect2i((frame%4)*256,(frame/4)*256,256,256))
			var bounds := cell.get_used_rect()
			check(bounds.has_area(),"Frame contains a sprite")
			check(bounds.position.x>=38 and bounds.end.x<=218 and bounds.position.y>=20 and bounds.end.y==210,"No bleed, safe gutters and stable 210px foot anchor")
	check(EnemyFrames.HEIGHTS[14]<190 and EnemyFrames.HEIGHTS[15]<190 and EnemyFrames.HEIGHTS[16]<190,"Large elites remain imposing without covering the combat view")
	print("NOCTURNE ART: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
