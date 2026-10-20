extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.position=Vector3(0,8,7); camera.look_at(Vector3.ZERO)
	var fx=Combat.new(); fx.camera=camera; fx.height_at=func(_p): return 120.0
	world.add_child(fx)
	var signatures := {}
	var weapons := range(600,648); weapons.append_array(range(21))
	for weapon in weapons:
		var data := {"kind":"strike","p":Vector2(100,200),"aim":Vector2.RIGHT,"weapon_index":weapon,"reach":float(Catalog.weapon(weapon).reach),"id":1,"combo":1,"height":35.0}
		var original := var_to_bytes(data)
		check(fx.event(data),"Every weapon uses the 3D route")
		check(var_to_bytes(data)==original,"Presentation never mutates authoritative data")
		var release=fx.effects.back()
		fx.advance(.055)
		check(release.ribbon is MeshInstance3D and release.ribbon.mesh is ArrayMesh,"Real spatial triangle mesh exists")
		check(release.smoke is MeshInstance3D and release.debris is MeshInstance3D,"Independent density and particle meshes")
		check(release.ground.is_equal_approx(Vector3(1,1.2,2)),"Terrain sampled in actual world coordinates")
		check(release.origin.y>=1.55,"Air height retained")
		var a: Array=release.ribbon.mesh.surface_get_arrays(0)
		check(a[Mesh.ARRAY_VERTEX] is PackedVector3Array,"Vertices are three-dimensional")
		check(a[Mesh.ARRAY_VERTEX].size()<=7*28*4,"Geometry budget bounded per release, including seven ground fissures")
		var before := var_to_bytes(a)
		release.rebuild()
		check(var_to_bytes(release.ribbon.mesh.surface_get_arrays(0))==before,"Event-time seeking is deterministic")
		var moving_before := var_to_bytes(release.bound.trail.mesh.surface_get_arrays(0)) if release.bound!=null else before
		release.advance(.04)
		var moving_after := var_to_bytes(release.bound.trail.mesh.surface_get_arrays(0)) if release.bound!=null else var_to_bytes(release.ribbon.mesh.surface_get_arrays(0))
		check(moving_after!=moving_before,"Spatial trail changes while the original painting retains its shape")
		if weapon>=600: signatures[weapon]=hash(var_to_bytes(release.ribbon.mesh.surface_get_arrays(0)))
		fx.reset()
	check(signatures.values().size()==48 and unique(signatures.values())==48,"All 48 releases have distinct geometry/timing/color signatures")
	for weapon in weapons:
		for charged in [false,true]:
			var move := preload("res://scripts/weapon_hold_attack.gd").profile(weapon) if charged else WeaponArts.of(weapon)
			for direction in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
				var data := {"kind":"strike","weapon_index":weapon,"p":Vector2.ZERO,"aim":direction,"reach":move.reach,"attack_kind":move.kind,"combo":2,"charged":charged,"id":1,"width":move.get("width",30)}
				fx.event(data); fx.advance(.075)
				var release=fx.effects.back()
				check(release.ribbon.visible and release.reach>0,"All normal/charged arts generate native geometry at every cardinal aim")
				check(release.aim.dot(Vector3(direction.x,0,direction.y))>.999,"Mouse direction owns world trajectory")
				var captured: Vector3=release.origin
				fx.camera.position.x+=.01; fx.advance(0)
				check(release.origin==captured,"Camera changes never drag released geometry")
				fx.reset()
	var hit := {"kind":"impact","p":Vector2.ZERO,"aim":Vector2.RIGHT,"damage":0,"weapon_index":606,"id":1,"enemy_id":8}
	fx.event(hit); check(fx.effects.is_empty(),"Zero damage never creates an impact")
	hit.damage=20; fx.event(hit); fx.event(hit)
	check(fx.effects.size()==1,"Duplicate real hit coalesced")
	fx.advance(.06)
	check(fx.effects[0].debris.visible and not fx.effects[0].ribbon.visible,"Real contact has detached material fragments without replaying the attack body")
	fx.reset()
	for i in 130: fx.event({"kind":"strike","p":Vector2(i,0),"aim":Vector2.RIGHT,"weapon_index":600+i%48,"reach":150,"id":i})
	check(fx.effects.size()==Combat.MAX_EFFECTS and fx.get_child_count()==Combat.MAX_EFFECTS,"Mass combat stays within live node budget even before deferred frees")
	fx.advance(3)
	check(fx.effects.is_empty() and fx.get_child_count()==0,"Expired effects leave no world children")
	fx.event({"kind":"windup","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon_index":637,"id":4,"windup":.8})
	fx.advance(.12); check(fx.charges.has(4) and fx.effects[0].ribbon.visible,"Charge has its own 3D gathering particles")
	fx.event({"kind":"strike","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon_index":637,"id":4,"reach":180,"charged":true})
	check(fx.charges.is_empty() and fx.effects.size()==1 and fx.effects[0].charged,"Release replaces charge and preserves charged presentation")
	fx.reset(); check(fx.get_child_count()==0,"Reset immediately detaches every world effect")
	world.queue_free(); await process_frame
	print("WEAPON WORLD VFX ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
func unique(values: Array) -> int:
	var seen := {}
	for value in values: seen[value]=true
	return seen.size()
