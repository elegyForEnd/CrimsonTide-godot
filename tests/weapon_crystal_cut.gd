extends SceneTree
const Combat=preload("res://scripts/weapon_combat_vfx_3d.gd")
const Trial=preload("res://scripts/weapon_crystal_cut.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=5
	camera.position=Vector3(0,6,7); camera.look_at(Vector3(0,.5,0))
	var fx=Combat.new(); fx.camera=camera; world.add_child(fx)
	for weapon in [600,1]:
		for aim in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
			var event := {"kind":"strike","p":Vector2.ZERO,"weapon_index":weapon,"aim":aim,"reach":130,"id":1,"vfx_action":"art"}
			var bytes := var_to_bytes(event)
			fx.event(event); fx.advance(.025)
			var release=fx.effects.back()
			check(release.authored is Trial,"Only the selected art and its campaign identity use the crystal trial")
			check(release.body_material.get_shader_parameter("painted_texture").resource_path=="res://assets/combat/crystal-cut-v1/ribbon.png","Ribbon consumes the explicitly authorized derived material")
			check(release.debris.material_override.get_shader_parameter("painted_texture").resource_path=="res://assets/combat/crystal-cut-v1/shard.png","Flying shards use an independent transparent texture")
			check(var_to_bytes(event)==bytes,"Presentation cannot change authoritative attack data")
			check(not release.data.has("crystal_contact"),"A miss cannot create a target or a shatter event")
			var at := Vector2(105,-13)
			fx.event({"kind":"impact","p":at,"weapon_index":weapon,"aim":aim,"id":1,"enemy_id":5,"damage":10,"vfx_action":"art"})
			var contact=fx.effects.back()
			var target: Vector3=fx.point(at,55)
			check(Vector3(release.data.crystal_contact).is_equal_approx(target),"Curves converge on the authoritative contact position")
			for lane in 2:
				check(release.authored.arc(1,lane,target).is_equal_approx(target),"Both open arcs end at the actual hit")
			fx.advance(.04)
			check(contact.debris.visible and not contact.ribbon.visible,"Real contact owns crystal shards, without replaying the entire slash")
			var fixed: Vector3=release.authored.captured
			camera.position.x+=.01
			fx.advance(.02)
			check(release.authored.captured==fixed,"Later camera movement cannot drag the emitted slash")
			fx.advance(1)
			check(fx.effects.is_empty(),"All slash, shards and halo nodes expire")
			fx.reset()
	for action in ["normal","heavy"]:
		fx.event({"kind":"strike","p":Vector2.ZERO,"weapon_index":600,"aim":Vector2.RIGHT,"reach":130,"id":1,"vfx_action":action})
		check(not fx.effects.back().authored is Trial,"Other actions retain the previous sample")
		fx.reset()
	world.queue_free(); await process_frame
	print("CRYSTAL CUT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
