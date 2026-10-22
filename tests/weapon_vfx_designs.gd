extends SceneTree
## Reference-independent production behavior, including actual event geometry.
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Motion=preload("res://scripts/weapon_motion_design.gd")
const Reference606=preload("res://scripts/weapon_606_reference_vfx.gd")
const ReferenceBatch=preload("res://scripts/weapon_batch01_vfx.gd")
const Flights=preload("res://scripts/weapon_projectile_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=6
	world.add_child(camera); camera.position=Vector3(0,7,5); camera.look_at(Vector3.ZERO)
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	var socket := {"p":Vector2(320,240)}
	fx.socket_provider=func(_id): return {"tip":socket.p+Vector2(70,-15),"stroke_pivot":socket.p,"grip":socket.p,"active":true}
	for weapon in range(600,648)+range(21):
		check(Motion.CURVES.has(Motion.identity(weapon)),"Every weapon has an authored design")
		for action in ["normal","heavy","art"]:
			var move: Dictionary=preload("res://scripts/weapon_hold_attack.gd").profile(weapon) if action=="heavy" else WeaponArts.of(weapon)
			var event := {"kind":"strike","weapon_index":weapon,"p":Vector2(100,200),"aim":Vector2.RIGHT,"reach":160,"id":1,"vfx_action":action,"charged":action=="heavy"}
			if action!="normal": event.attack_kind=move.kind; event.reach=move.reach; event.width=move.get("width",30)
			var original := var_to_bytes(event)
			fx.event(event); fx.advance(.07)
			var release=fx.effects.back()
			check(var_to_bytes(event)==original,"Rendering cannot mutate authoritative attacks")
			var reference_design: bool=release.authored is Reference606 or release.authored is ReferenceBatch
			check((reference_design or release.authored is Motion) and release.bound==null,"Production constructs dynamic surfaces from isolated material components")
			var arrays: Array=release.ribbon.mesh.surface_get_arrays(0)
			check(arrays[Mesh.ARRAY_VERTEX].size()>0 and arrays[Mesh.ARRAY_VERTEX].size()<800,"Bounded nonempty native geometry")
			var captured: Vector3=release.authored.root if reference_design else release.authored.captured
			var axis: Vector3=release.authored.forward if reference_design else release.authored.axis
			socket.p+=Vector2(7,-3); camera.position.x+=.005; fx.advance(.03)
			check((release.authored.root==captured and release.authored.forward==axis) if reference_design else (release.authored.captured==captured and release.authored.axis==axis),"Actor and camera cannot drag an emitted attack")
			fx.advance(2); check(fx.effects.is_empty(),"All layers expire")
			fx.reset()
		fx.event({"kind":"impact","weapon_index":weapon,"p":Vector2(220,200),"aim":Vector2.RIGHT,"damage":0,"id":2})
		check(fx.effects.is_empty(),"Zero damage cannot invent contact")
		fx.event({"kind":"impact","weapon_index":weapon,"p":Vector2(220,200),"aim":Vector2.RIGHT,"damage":10,"id":2,"enemy_id":3})
		fx.advance(.04)
		check(fx.effects.size()==1 and fx.effects.back().debris.visible,"A real hit owns its material response")
		check(not fx.effects.back().ribbon.visible,"Contact cannot duplicate the whole release")
		fx.reset()
	for aim in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		fx.event({"kind":"strike","weapon_index":601,"p":Vector2.ZERO,"aim":aim,"reach":180,"id":1})
		var release=fx.effects.back()
		check(camera.unproject_position(release.to_global(release.origin)).distance_to(socket.p)<.1,"Actual screen socket is honored in all aim directions")
		fx.reset()
	fx.event({"kind":"spell_burst","weapon_index":637,"p":Vector2(900,100),"aim":Vector2.RIGHT,"radius":100,"id":1})
	check(absf(fx.effects.back().origin.x-9.0)<.001,"Ground burst appears at its real target, not the caster socket")
	fx.reset()
	var flights=Flights.new(); flights.camera=camera; world.add_child(flights)
	for weapon in range(624,648):
		var bullet := {"fx_id":1,"weapon_index":weapon,"p":Vector2.ZERO,"v":Vector2(500,0),"height":55}
		flights.observe([bullet],0); bullet.p=Vector2(30,0); flights.observe([bullet],.06); flights.advance(.06)
		var flight: Dictionary=flights.flights[1]
		check(flight.native_body and (flight.body.visible or flight.silhouette.visible),"Flight has one world-space painted or sculpted head")
		check(flight.body.visible!=flight.silhouette.visible and not flight.core.visible,"Only one projectile head is visible; no duplicate white core")
		check(flight.p.is_equal_approx(Vector3(.3,.55,0)),"Body follows real simulation position")
		flights.reset()
	var source := FileAccess.get_file_as_string("res://scripts/weapon_hybrid_material.gd")
	check(not source.contains("res://art/") and source.contains("Art.mechanic_texture"),"Hybrid materials use authored component textures rather than a full reference screenshot")
	world.queue_free(); await process_frame
	print("WEAPON VFX DESIGN BEHAVIOR ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
