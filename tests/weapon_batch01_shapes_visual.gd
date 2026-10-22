extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Hold=preload("res://scripts/weapon_hold_attack.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func capture(view: SubViewport) -> Image:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func difference(a: Image,b: Image) -> int:
	var x := a.get_data(); var y := b.get_data(); var total := 0
	for i in x.size(): total+=absi(int(x[i])-int(y[i]))
	return total
func outside_peak(probe: Image,peak: Image) -> int:
	var a := probe.get_data(); var b := peak.get_data(); var count := 0
	for i in range(3,a.size(),4):
		if int(a[i])>48 and int(a[i])>int(b[i])+5: count+=1
	return count
func run() -> void:
	var view := SubViewport.new(); view.size=Vector2i(480,360); view.own_world_3d=true; view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var world := Node3D.new(); view.add_child(world)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4.8
	world.add_child(camera); camera.position=Vector3(0,5,8); camera.look_at(Vector3(0,.5,0)); camera.make_current()
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var grip := camera.unproject_position(Vector3(-.8,.62,0))
	var tip := camera.unproject_position(Vector3(-.2,.62,0))
	fx.socket_provider=func(_id): return {"tip":tip,"stroke_tip":tip,"grip":grip,"stroke_pivot":grip,"active":true}
	var empty := await capture(view)
	var originals := {}
	for weapon in [607,608,612,614,617]:
		for action in ["normal","heavy","art"]:
			fx.reset()
			var move: Dictionary=Hold.profile(weapon) if action=="heavy" else WeaponArts.of(weapon)
			var preparation := {"kind":"windup","p":Vector2(-80,0),"aim":Vector2.RIGHT,"weapon_index":weapon,"reach":180,"windup":.20,"id":1,"vfx_action":action}
			if action!="normal": preparation.attack_kind=move.kind
			fx.event(preparation); fx.advance(.17)
			var gathering=fx.charges[1]
			check(gathering.authored.pre_sweep!=null and gathering.authored.pre_sweep.visible,"Shape unfolds during the end of anticipation: %d/%s" % [weapon,action])
			check(not gathering.authored.contact_paint.visible,"Anticipation does not invent a target impact")
			check(difference(await capture(view),empty)>100,"Anticipation sweep produces real pixels")
			var strike := preparation.duplicate(); strike.kind="strike"; strike.erase("windup")
			var input := var_to_bytes(strike)
			fx.event(strike); fx.advance(.012)
			var release=fx.effects.back()
			check(var_to_bytes(strike)==input,"Visual preparation does not mutate authoritative events")
			check(fx.charges.is_empty() and release.data.shape_prepared,"Prepared stroke transfers to release without overlapping duplicate sweeps")
			check(release.authored.actual_shape!=null,"Every action uses actual-shaped artwork")
			var row: Dictionary=release.authored.actual_shape.row
			check(not originals.has(str(row.file)),"Normal/heavy/art each have an independently drawn primary shape")
			originals[str(row.file)]=true
			check(release.body_material.get_shader_parameter("atlas")!=null,"Runtime stage atlas is imported and loaded")
			var geometry := var_to_bytes(release.ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
			for child in release.get_children():
				if child is MeshInstance3D: child.hide()
			release.ribbon.show()
			release.body_material.set_shader_parameter("phase",1.0)
			release.body_material.set_shader_parameter("reveal",1.0)
			release.body_material.set_shader_parameter("tail_start",0.0)
			var peak := await capture(view)
			check(difference(peak,empty)>100,"Peak silhouette is visible")
			for phase in [.40,1.45,2.35]:
				release.body_material.set_shader_parameter("phase",phase)
				release.body_material.set_shader_parameter("reveal",.65 if phase<1 else 1.0)
				var stage := await capture(view)
				check(outside_peak(stage,peak)==0,"Stage transition never emits a second displaced silhouette")
				check(difference(stage,peak)>40,"Stages evolve instead of holding the peak picture")
			fx.advance(.001)
			var before_contact: float=release.age
			fx.event({"kind":"impact","p":Vector2(75,0),"aim":Vector2.RIGHT,"weapon_index":weapon,"damage":20,"id":1,"enemy_id":3,"vfx_action":action})
			check(is_equal_approx(release.age,before_contact),"Actual contact does not jump a prepared visual timeline")
			fx.advance(.055)
			check(var_to_bytes(release.ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])==geometry,"Registered hand/tip canvas stays fixed through material stage transitions")
			var hit=fx.effects.back()
			check(hit.kind=="impact" and hit.authored.contact_smoke.visible,"Real hit supplies delayed independently moving smoke")
			check(difference(await capture(view),empty)>200,"Coordinated release and contact render together")
			fx.advance(1.5)
			check(fx.effects.is_empty() and difference(await capture(view),empty)==0,"All layers dissipate without residual pictures")
		fx.event({"kind":"hold_charge","p":Vector2(-80,0),"aim":Vector2.RIGHT,"weapon_index":weapon,"hold_time":.65,"id":1})
		fx.advance(.8)
		check(fx.charges[1].authored.pre_sweep==null,"Holding charge never prematurely emits the actual strike")
		fx.event({"kind":"hold_cancel","id":1})
		check(fx.effects.is_empty() and difference(await capture(view),empty)==0,"Cancel clears all preparation layers")
	check(originals.size()==15,"Five weapons have fifteen distinct primary action artworks")
	world.queue_free(); view.queue_free(); await process_frame
	print("BATCH01 ACTUAL SHAPES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
