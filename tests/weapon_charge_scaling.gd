extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Build=preload("res://scripts/rogue_build.gd")
const Field=preload("res://scripts/rogue_field.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func clear(p: Dictionary) -> void:
	for key in ["attack","swing_time","cast_time","reload","dodge_time","flask_time","height"]: p[key]=0.0
	p.erase("weapon_hold"); p.erase("build_pending_art")
	p.mana=1000.0; p.ammo=20; p.pending_strike=false
func run() -> void:
	var s := TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729)
	s.set_physics_process(false); s.enemies.clear(); s.raid.phase="rogue_combat"
	var p: Dictionary=s.players[1]; p.rogue_selection={}; p.build_talents={}
	p.equipped={"weapon":{},"gear":[]}
	for weapon in range(600,648):
		p.weapon=weapon
		var move := Hold.parameters(s,p)
		var previous := 0.0
		for progress in [.1,.5,1.0,2.0]:
			clear(p)
			var seconds := Hold.TAP_TIME+(float(move.hold_time)-Hold.TAP_TIME)*float(progress)
			Hold.begin(s,p); Hold.tick(s,p,{},seconds)
			check(is_equal_approx(Hold.fraction(seconds,move.hold_time),minf(1.0,progress)),"Progress and cap %d" % weapon)
			Hold.release(s,p)
			check(p.has("build_pending_art"),"Partial charge releases designed move %d" % weapon)
			if p.has("build_pending_art"):
				var actual: float=p.build_pending_art.damage
				check(is_equal_approx(actual,s.weapon_damage(p)*Hold.damage_at(seconds,move)),"Host damage follows progress %d" % weapon)
				check(actual>=previous,"Damage monotonic %d" % weapon)
				previous=actual
	clear(p); p.weapon=612
	var base := Hold.parameters(s,p)
	p.build_talents={"T011":3,"T058":3}
	var improved := Hold.parameters(s,p)
	check(improved.hold_time<base.hold_time and improved.damage>base.damage,"Heavy talent damage and universal speed")
	Hold.begin(s,p); Hold.tick(s,p,{},.3)
	check(Build.conditional_defense(s,p)>=.11,"Heavy talent protects while holding")
	var snap := float(p.weapon_hold.full_time)
	p.build_talents={}
	Hold.tick(s,p,{},snap-.3)
	check(p.weapon_hold.ready,"Charge completion uses initial duration snapshot")
	clear(p); p.weapon=624
	base=Hold.parameters(s,p); p.build_talents={"T018":3}
	check(Hold.parameters(s,p).hold_time<base.hold_time,"Ranged charge speed talent")
	p.weapon=600
	check(is_equal_approx(Hold.parameters(s,p).hold_time,Hold.profile(600).hold_time),"Ranged speed excludes melee")
	p.equipped.gear=[{"build_id":"E023"}]
	check(Hold.parameters(s,p).damage>Hold.profile(600).damage,"Equipment charge bonus")
	p.equipped.weapon={"rogue_id":13}
	check(Hold.parameters(s,p).hold_time<Hold.profile(600).hold_time,"Engraving charge speed")
	p.weapon=612; p.equipped.weapon={"instance_id":"test"}; p.build_forge_bound="test"; p.build_forge_level=4; p.build_core="WC004"
	check(is_equal_approx(Build.charge_stats(p).damage,.22),"Core and gear add to charge pool")
	var animation_frames := CharacterFrames.new()
	var changing := 0
	var full_surfaces := 0
	for hero in 4:
		for weapon in range(600,648):
			var actor := p.duplicate(true)
			actor.hero=hero; actor.weapon=weapon; actor.swing_time=0.0; actor.cast_time=0.0
			actor.weapon_hold={"shown":true,"time":.19,"full_time":.85}
			var early := animation_frames.charge_frame(actor)
			actor.weapon_hold.time=.85
			var full := animation_frames.charge_frame(actor)
			var key := animation_frames.weapon_atlases.atlas_key(hero,weapon)
			var atlas: Dictionary=animation_frames.weapon_atlases.manifest.get(key,{})
			var contact := int(atlas.get("contact_frames",{}).get("art",2))
			var sites := preload("res://scripts/weapon_held_glow.gd").charge_sites(full)
			if sites.size()>2 and sites.front().distance_to(sites.back())>5: full_surfaces+=1
			for site in sites:
				var rect: Rect2=full.rect
				var local: Vector2=site+CharacterMetrics.FOOT_OFFSET
				check(rect.has_point(local),"Whole weapon sample remains in sprite %d/%d" % [hero,weapon])

			check(early.get("charge_pose",false) and full.get("charge_pose",false),"Charge pose selected %d/%d" % [hero,weapon])
			check(int(full.get("frame",0))<contact,"Holding never plays contact %d/%d" % [hero,weapon])
			for pose in [early,full]:
				if not pose.get("weapon_atlas",false): continue
				var anchor := preload("res://scripts/weapon_held_glow.gd").charge_anchor(pose)+CharacterMetrics.FOOT_OFFSET
				var rect: Rect2=pose.rect
				check(rect.has_point(anchor),"Charge light inside packed pose %d/%d" % [hero,weapon])
				if rect.has_point(anchor):
					var image: Image=pose.texture.get_image()
					var pixel := Vector2i((anchor-rect.position)/rect.size*Vector2(image.get_size()))
					check(image.get_pixelv(pixel).a>.7,"Charge light on opaque surface %d/%d" % [hero,weapon])
			if int(early.get("frame",0))!=int(full.get("frame",0)): changing+=1
	check(full_surfaces==192,"Every reviewed full-charge weapon has distributed sampling")
	print("Distributed charge surfaces: ",full_surfaces,"/192")
	for weapon in range(600,648):
		var identity := preload("res://scripts/weapon_vfx.gd").charge_profile(weapon)
		check(identity.color.s>.15 and str(identity.particle).begins_with("charge_"),"Weapon material charge identity %d" % weapon)
		check(bool(identity.staff)==(Catalog.weapon_family(weapon)==3),"Staff uses head gathering %d" % weapon)
	check(changing>100,"Weapon charge anticipation advances rather than static frame")
	var field := Field.new(); field.session=s; field.frames=CharacterFrames.new()
	clear(p); p.weapon=600; p.motion="run"; p.aim=Vector2.RIGHT; p.weapon_hold={"shown":true,"time":.3}; field.move_phases[1]=1.0
	var pose := field.frames.held_motion_frame(p,"run",1.0,p.dodge_time)
	var socket := field.weapon_effect_socket(1)
	var expected: Vector2=p.p-field.camera_offset()+CharacterMetrics.FOOT_OFFSET*field.HERO_SCALE+preload("res://scripts/weapon_held_glow.gd").charge_anchor(pose)*field.HERO_SCALE
	check(socket.tip.distance_to(expected)<.01,"Moving mount uses actual run pose")
	p.p+=Vector2(140,75); field.camera_x+=50
	var moved := field.weapon_effect_socket(1)
	check((moved.tip-socket.tip).distance_to(Vector2(90,75))<.01,"Mount follows movement and camera")
	var fx := FX.new(); root.add_child(fx)
	fx.socket_provider=field.weapon_effect_socket
	fx.event({"kind":"hold_charge","p":p.p,"id":1,"weapon_index":600,"hold_time":.5})
	fx.advance(.1)
	check(fx.effects[0].p.distance_to(moved.tip)<.01,"Live charge position updated")
	check(not fx.particles.particles.is_empty(),"Charge spawns surrounding particles")
	check(fx.particles.particles.all(func(particle): return str(particle.style).begins_with("charge")),"Charge particles are light dots, no flakes")
	p.p+=Vector2(80,40); fx.advance(.1)
	check(fx.effects[0].p.distance_to(field.weapon_effect_socket(1).tip)<.01,"Light follows next movement")
	fx.event({"kind":"hold_cancel","p":p.p,"id":1,"weapon_index":600})
	check(fx.effects.is_empty(),"Cancellation clears following light")
	fx.advance(.14)
	check(fx.particles.particles.is_empty(),"Cancelled gathering fades and clears")
	field.free(); fx.queue_free(); s.queue_free(); await process_frame
	print("CHARGE SCALING: %d checks; %d failures" % [checks,failures]); quit(1 if failures else 0)
