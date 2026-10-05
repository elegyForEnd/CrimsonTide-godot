extends SceneTree
const Art = preload("res://scripts/boss_effect_art.gd")
const VFX = preload("res://scripts/boss_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	var paths: Dictionary={}
	for key in Art.KEYS:
		for role in Art.ROLES:
			var tex: Texture2D=Art.texture(key,role)
			check(tex!=null,"Complete boss art: "+key+"_"+role)
			if tex==null: continue
			check(not tex is AtlasTexture,"Standalone image: "+key+"_"+role)
			check(tex.get_width()>=1024 and tex.get_height()>=1024,"Native HD art")
			check(not paths.has(tex.resource_path),"No shared reskin source")
			paths[tex.resource_path]=true
			var im := tex.get_image()
			check(im.detect_alpha()!=Image.ALPHA_NONE and im.get_pixel(0,0).a==0,"True transparent margins")
	check(paths.size()==68,"Seventeen bosses each have four original effects")
	var special := [{"dragon_boss":true},{"wild_boss":true,"wild_kind":0},{"wild_boss":true,"wild_kind":1},{"wild_boss":true,"wild_kind":2},{"hidden_final":true},{"final_form":true},{"mini_kind":0},{"mini_kind":1}]
	var expected := ["dragon","earth","storm","abyss","hidden","moon","mirror","ember"]
	for i in special.size():
		special[i]["boss_kind"]=2
		check(Art.identity(special[i])==expected[i],"Exact special identity overrides shared theme")
	var fx := VFX.new()
	for aim in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		for shape in ["ring","gap_ring","arc"]:
			var spec := {"shape":shape,"radius":240.0,"inner":130.0,"gap":.7,"arc":1.05,"aim":aim}
			var points: Array=fx.ring_points(spec)
			check(not points.is_empty(),"Visible annular release")
			for point in points:
				var bound: float=point.size*sqrt(2.0)*.5
				check(point.p.length()-bound>spec.inner and point.p.length()+bound<spec.radius,"Whole sprite keeps safe center clear")
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					var p: Vector2=point.p+(corner*point.size*.5).rotated(point.angle)
					if shape=="gap_ring": check(absf(aim.angle_to(p))>spec.gap,"Transparent dodge gap has no sprite quad")
					elif shape=="arc": check(absf(aim.angle_to(p))<spec.arc,"Arc stays in its angular hazard")
	fx.energy.free()
	fx.cinematic.free()
	fx.damage_visual.free()
	fx.free()
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.set_physics_process(false)
	for floor_index in 5:
		var e := {"id":900+floor_index,"p":s.players[1].p+Vector2(120,0),"facing":1.0,"hp":2000.0,"max_hp":2000.0}
		s.roguelike.combat.setup_boss(e,floor_index)
		check(Art.identity(e)==Art.ROGUE[floor_index],"Guardian has an independent identity")
		for skill in 5:
			s.roguelike.combat.reset()
			s.roguelike.combat.begin_skill(s,e,skill,s.players[1])
			for zone in s.roguelike.combat.effects: check(zone.rogue_guardian and zone.floor==floor_index,"Boss zone snapshot retains identity")
		s.bullets.clear()
		s.roguelike.combat.bolt(s,e,Vector2.RIGHT,100,1)
		check(s.bullets[0].rogue_guardian,"Boss projectile retains identity")
	s.queue_free()
	await process_frame
	print("BOSS REDESIGN ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
