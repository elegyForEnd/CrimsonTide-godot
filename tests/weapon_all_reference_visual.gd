extends SceneTree
const Art=preload("res://scripts/weapon_batch_art.gd")
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func pixels(image: Image) -> int:
	var bytes := image.get_data(); var count := 0
	for at in range(3,bytes.size(),4):
		if int(bytes[at])>12: count+=1
	return count
func capture(view: SubViewport) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	var view := SubViewport.new(); view.size=Vector2i(480,360); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8; camera.position=Vector3(0,6,9); camera.look_at(Vector3(0,.5,0)); camera.make_current()
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var registered := 0; var unique := {}
	for weapon in range(600,648):
		if weapon in [606,607,608,612,614,617]: continue
		check(Art.enabled(weapon),"Every remaining weapon has registered original artwork: "+str(weapon))
		if not Art.enabled(weapon): continue
		registered+=1
		var family := Catalog.weapon_family(weapon)
		for action in ["normal","heavy","art"]:
			fx.reset()
			var event := {"kind":"strike","weapon_index":weapon,"p":Vector2(-150,0),"aim":Vector2.RIGHT,"id":1,"reach":240,"vfx_action":action}
			if action=="art" and family==3:
				var move := WeaponArts.of(weapon)
				if move.kind in ["beam","burst"]:
					event.kind="spell_beam" if move.kind=="beam" else "spell_burst"
					event.reach=520; event.radius=130; event.spell=move.spell
			fx.event(event); fx.advance(.065)
			var effect=fx.effects.back()
			check(effect.authored!=null and effect.authored.actual_shape!=null,"Runtime uses actual-shaped source")
			if effect.authored==null or effect.authored.actual_shape==null: continue
			var row: Dictionary=effect.authored.actual_shape.row
			var signature := str(row.file)+str(row.frame_rects)
			check(not unique.has(signature),"Every action samples its own independent painted silhouette")
			unique[signature]=true
			check(pixels(await capture(view))>8,"Peak generates real pixels: %d/%s" % [weapon,action])
			fx.advance(1.6)
			check(fx.effects.is_empty(),"All presentation layers expire")
		if family in [0,3]:
			var art=Art.of(weapon)
			check(not art.metadata("projectile").is_empty() and not art.metadata("projectile_art").is_empty(),"Ranged weapon owns independent normal and charged/finisher payloads")
		if family==3 and WeaponArts.of(weapon).kind in ["beam","burst"]:
			var spell_shapes := []
			for selected in ["heavy","art"]:
				fx.reset()
				var move := WeaponArts.of(weapon)
				fx.event({"kind":"spell_beam" if move.kind=="beam" else "spell_burst","weapon_index":weapon,"p":Vector2(-150,0),"aim":Vector2.RIGHT,"id":1,"reach":520,"radius":130,"vfx_action":selected,"charged":selected=="heavy","spell":move.spell})
				fx.advance(.075)
				var row: Dictionary=fx.effects.back().authored.actual_shape.row
				spell_shapes.append(str(row.file)+str(row.frame_rects))
				check(pixels(await capture(view))>8,"Real charged/art spell body produces pixels")
			check(spell_shapes[0]!=spell_shapes[1],"Charged spell and ornate art sample different source shapes")
	check(registered==42 and unique.size()==126,"All 42 remaining weapons and 126 distinct primary samples are covered")
	world.queue_free(); view.queue_free(); await process_frame
	print("ALL REFERENCE VISUAL ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
