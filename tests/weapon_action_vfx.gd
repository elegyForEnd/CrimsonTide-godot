extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Profiles=preload("res://scripts/weapon_effect_profiles.gd")
const Flights=preload("res://scripts/weapon_projectile_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,6,8); camera.look_at(Vector3.ZERO)
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var flights=Flights.new(); flights.camera=camera; world.add_child(flights)
	for weapon in range(600,648)+range(21):
		var topology := {}; var shapes := {}; var colors := {}
		for action in ["normal","heavy","art"]:
			var event := {"kind":"strike","weapon_index":weapon,"p":Vector2.ZERO,"aim":Vector2.RIGHT,"reach":180.0,"id":1,"combo":0,"vfx_action":action,"charged":action=="heavy"}
			var original := var_to_bytes(event)
			fx.event(event); fx.advance(.055)
			var release=fx.effects.back()
			check(release.action==action and release.profile.action==action,"Each attack retains its own action descriptor")
			var arrays: Array=release.ribbon.mesh.surface_get_arrays(0)
			topology[action]=arrays[Mesh.ARRAY_VERTEX].size()
			shapes[action]=hash(var_to_bytes(arrays[Mesh.ARRAY_VERTEX]))
			if release.authored!=null and release.authored.get_script()==preload("res://scripts/weapon_batch01_vfx.gd") and release.authored.actual_shape!=null:
				# Independently painted silhouettes may intentionally share one
				# registered quad. Include the actual sampled artwork in identity.
				var row: Dictionary=release.authored.actual_shape.row
				shapes[action]=hash(var_to_bytes([arrays[Mesh.ARRAY_VERTEX],row.file,row.frame_rects]))
			colors[action]=release.color
			check(event.reach==180 and var_to_bytes(event)==original,"VFX does not change damage reach or authoritative events")
			fx.reset()
		check(topology.values().all(func(count): return count>0 and count<=7*28*4),"All actions respect one shared complexity budget: "+str(weapon))
		check(shapes.normal!=shapes.heavy and shapes.heavy!=shapes.art,"All three actions have different moving geometry")
		check(colors.normal==colors.heavy and colors.heavy==colors.art,"A weapon retains its unified material palette")
		fx.event({"kind":"hold_charge","weapon_index":weapon,"p":Vector2.ZERO,"aim":Vector2.RIGHT,"hold_time":.6,"id":1})
		fx.advance(.08)
		var charge=fx.charges[1]
		check(charge.kind=="charge" and charge.action=="heavy" and charge.ribbon.visible,"Every weapon has visible world-space heavy gathering")
		var early := hash(var_to_bytes(charge.ribbon.mesh.surface_get_arrays(0)))
		fx.advance(.5); fx.event({"kind":"hold_ready","id":1}); fx.advance(.02)
		check(charge.data.ready and hash(var_to_bytes(charge.ribbon.mesh.surface_get_arrays(0)))!=early,"Full charge changes gathering and emits a ready pulse")
		fx.advance(35)
		check(fx.charges.has(1) and charge.ribbon.visible,"Holding a full charge does not expire before release")
		fx.event({"kind":"hold_cancel","id":1})
		check(fx.charges.is_empty() and fx.get_child_count()==0,"Cancel immediately removes all charge geometry")
		fx.reset()
		var shot := {"fx_id":weapon,"weapon_index":weapon,"p":Vector2.ZERO,"height":55.0,"v":Vector2.RIGHT,"build_context":{"kind":"art","charged":true}}
		flights.observe([shot],.02)
		check(flights.flights[weapon].action=="heavy","Released charged payload keeps its identity even with art-shaped mechanics")
		var flight: Dictionary=flights.flights[weapon]
		check(is_equal_approx(flight.body.basis.x.length(),flight.paint_size.x*flights.body_gain) and is_equal_approx(flight.body.basis.y.length(),flight.paint_size.y*flights.body_gain),"Projectile preserves painted aspect in its local axes")
		flights.reset()
	var authored := {}
	var primary_paths := {}
	for weapon in range(600,648):
		var spec := Profiles.profile(weapon)
		var key := var_to_str(spec.signature)
		check(not authored.has(key),"Each weapon has its own authored silhouette recipe: "+str(weapon))
		authored[key]=true
		fx.event({"kind":"strike","weapon_index":weapon,"p":Vector2.ZERO,"aim":Vector2.RIGHT,"reach":180.0,"id":1,"vfx_action":"normal"})
		var instance=fx.effects.back()
		var samples := PackedVector3Array()
		for sample in 11: samples.append(instance.path(float(sample)/10))
		var curve_key := hash(var_to_bytes(samples))
		check(not primary_paths.has(curve_key),"Main body choreography is unique even without color, textures or ornaments: "+str(weapon))
		primary_paths[curve_key]=true
		fx.reset()
	for weapon in [615,619]:
		for action in ["normal","heavy","art"]:
			fx.event({"kind":"strike","weapon_index":weapon,"p":Vector2.ZERO,"aim":Vector2.RIGHT,"reach":180.0,"id":1,"vfx_action":action,"charged":action=="heavy"})
			var hammer=fx.effects.back()
			var before=preload("res://scripts/weapon_vfx_mesh_3d.gd").new()
			hammer.draw_ground_break(before,before)
			check(before.vertices.is_empty(),"Hammer ground fault cannot appear before the landing")
			fx.advance(hammer.emission_time+.06)
			var cracks=preload("res://scripts/weapon_vfx_mesh_3d.gd").new()
			var stones=preload("res://scripts/weapon_vfx_mesh_3d.gd").new()
			hammer.draw_ground_break(cracks,stones)
			check(not cracks.vertices.is_empty() and not stones.vertices.is_empty(),"Hammer landing emits fissures and airborne slabs")
			for point in cracks.vertices: check(absf(point.y-hammer.ground.y-.025)<.001,"Cracks lie on the ground rather than facing the camera")
			fx.reset()
	check(Profiles.action_of({"build_context":{"kind":"art"}})=="art","Delayed art payload retains art identity")
	check(Profiles.action_of({"attack_kind":"circle","charged":true})=="heavy","Charge classification takes precedence over inherited art mechanics")
	world.queue_free(); await process_frame
	print("WEAPON ACTION VFX ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
