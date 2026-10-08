extends SceneTree
## Exercise the real mechanic renderer, not a reconstructed alignment formula.
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(420,420)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fx := FX.new()
	viewport.add_child(fx)
	fx.transform=Transform2D(Vector2(1.1,.12),Vector2(-.08,.72),Vector2(9,17))
	fx.socket_provider=func(_id): return {"tip":Vector2(210,210),"aim":Vector2.RIGHT,"active":true}
	for pair in [[600,""],[603,""],[612,""],[621,""],[622,""],[601,""],[19,"cone"]]:
		for combo in 3:
			for direction in 8:
				var aim := Vector2.from_angle(direction*PI/4)
				fx.socket_provider=func(_id): return {"tip":Vector2(210,210),"aim":aim,"active":true}
				fx.reset()
				var data := {"kind":"strike","p":Vector2(200,240),"aim":aim,"weapon":Catalog.weapon_family(pair[0]),"weapon_index":pair[0],"combo":combo,"reach":80,"id":1}
				if pair[1]!="": data["attack_kind"]=pair[1]
				fx.event(data)
				fx.particles.reset(); fx.shards.clear()
				for step in [.025,.055,.045]:
					fx.advance(step)
					await process_frame; await RenderingServer.frame_post_draw
					var img := viewport.get_texture().get_image()
					var contact := 0.0
					for y in range(208,213):
						for x in range(208,213): contact=maxf(contact,img.get_pixel(x,y).a)
					check(contact>.25,"Visible blade touches socket throughout release: weapon%d combo%d direction%d age%.3f"%[pair[0],combo,direction,fx.effects[0].age])
	viewport.queue_free(); await process_frame
	var p := {"weapon":600,"swing_total":.5,"swing_time":.43,"build_strike_windup":.05}
	check(CharacterFrames.attack_pose_frame(p)==2,"Hasted release selects contact pose using actual windup")
	p={"weapon":612,"swing_total":.62,"swing_time":.12,"build_strike_windup":.5}
	check(CharacterFrames.attack_pose_frame(p)==2,"Heavy art release remains in the contact pose after its longer windup")
	print("MECHANIC CONTACT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
