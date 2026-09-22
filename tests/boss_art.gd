extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(text)
func _initialize() -> void:
	var art := BossFrames.new()
	for kind in 3:
		check(art.sheets[kind].get_size()==Vector2(2048,1536),"Dedicated atlas dimensions")
		check(art.portraits[kind]!=null and art.headers[kind]!=null,"Portrait and generated header loaded")
		var im := art.sheets[kind].get_image()
		for frame in 12:
			var region := im.get_region(Rect2i(BossFrames.region(frame)))
			check(region.get_used_rect().size.x>40,"Every animation frame contains artwork")
	var e := {"hp":100,"id":1,"windup":1.15,"attack_total":2.1,"attack_time":2.1}
	for sample in [[2.1,4],[1.5,5],[0.9,6],[0.4,7]]:
		e.attack_time=sample[0]
		check(BossFrames.pose(e,0)==sample[1],"Animation follows attack timeline")
	e.attack_time=0
	e.flash=0.1
	check(BossFrames.pose(e,0)==10,"Hurt pose")
	e.hp=0
	check(BossFrames.pose(e,0)==11,"Defeated pose")
	print("BOSS ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
