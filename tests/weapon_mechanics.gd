extends SceneTree
const M=preload("res://scripts/weapon_mechanics.gd")
const Art=preload("res://scripts/weapon_image_art.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const Build=preload("res://scripts/rogue_build.gd")
var checks := 0
var failures := 0
var events: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var cases := {601:"motion_thrust",602:"motion_spin",603:"motion_double_slash",614:"motion_heavy_spin",615:"motion_heavy_spin",619:"motion_heavy_spin",15:"motion_quake",625:"release_bow",624:"muzzle_fire",638:"cast_ice",637:"cast_fire",646:"cast_soul"}
	for id in cases: check(M.normal_role(id)==cases[id],"Known actual normal action must use its own role: %d" % id)
	for id in [625,626,628,632,634,16]: check(M.projectile_role(id,"arrow")=="projectile_arrow","Bow/crossbow fires an arrow, not its release effect")
	for id in [624,627,629,630,631,633,635,0]: check(M.projectile_role(id,"star")=="projectile_bullet","Firearms retain actual bullet silhouette even with legacy default spell")
	check(M.projectile_role(638,"scatter")=="projectile_needle","Ice staff volley keeps five ice needles, never fire feathers")
	check(M.projectile_role(642,"scatter")=="projectile_feather","Actual five fire feathers are individual projectiles")
	check(M.projectile_role(637,"meteor")=="projectile_meteor" and M.burst_role(637,"meteor")=="burst_fire","Meteor flight and impact use separate roles")
	check(M.normal_role(614)!=M.normal_role(15),"Run circular sword and campaign quake retain their different actual moves")
	check(M.normal_role(621)=="motion_narrow_sweep" and M.strike_role(621,{"attack_kind":"cone"})=="motion_heavy_slash","Halberd normal 70-degree fan differs from its actual wider cone art")
	var s := TideSession.new(); root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,1729); s.set_physics_process(false); s.enemies.clear()
	s.combat_event.connect(func(data): events.append(data.duplicate(true)))
	var p: Dictionary=s.players[1]
	var fx := FX.new(); root.add_child(fx)
	fx.socket_provider=func(_id): return {"tip":Vector2(260,200),"aim":Vector2.RIGHT,"active":true}
	var roles := {}
	for route in 4:
		fx.reset()
		fx.event({"kind":"strike","p":Vector2.ZERO,"aim":Vector2.RIGHT,"weapon":0,"weapon_index":625,"combo_route":route,"combo":2})
		check(not fx.effects.any(func(effect): return effect.kind=="route"),"Ranged derived routes do not invent sword arcs or ice crystals")
	for index in range(600,648):
		p.rogue_stash.clear()
		check(s.roguelike.equip(s,p,Build.Content.make_weapon(index-600,0)) and p.weapon==index,"Probe equips the actual concrete weapon")
		p.combo=0; p.aim=Vector2.RIGHT; p.strike_aim=Vector2.RIGHT; p.height=0; p.build_next_route=-1; p.build_next_hero=-1
		p.build_strike_context=Build.context(s,p,"attack")
		s.bullets.clear(); events.clear(); Actions.normal(s,p)
		var strikes: Array=events.filter(func(data): return data.kind=="strike")
		check(strikes.size()==1,"One normal release event per actual attack")
		fx.reset(); fx.event(strikes[0])
		var role: String=fx.effects[0].art_role; roles[role]=true
		check(Art.mechanic_texture(role)!=null,"Actual release role has generated square art")
		if M.body_centered(role): check(fx.effects[0].p==p.p,"Full circle follows captured body center, not blade tip")
		if Catalog.weapon_family(index) in [0,3] and Catalog.weapon(index).get("spell","")!="prism":
			var expected := 5 if Catalog.weapon(index).get("spell","")=="scatter" else 1
			check(s.bullets.size()==expected,"Normal sprite count equals actual simulated projectile count: %d" % index)
			for bullet in s.bullets:
				var projectile: String=M.projectile_role(index,bullet.spell)
				check(Art.mechanic_texture(projectile)!=null,"Every actual projectile uses a dedicated flight sprite")
				check(projectile!=role,"Flight sprite is different from muzzle/cast flash")
		var move := WeaponArts.of(index)
		var ctx := Build.context(s,p,"art")
		s.bullets.clear(); events.clear()
		Actions.resolve_art(s,p,{"move":move,"ctx":ctx,"aim":Vector2.RIGHT,"damage":10},1)
		strikes=events.filter(func(data): return data.kind=="strike")
		check(strikes[0].attack_kind==move.kind,"Art event carries actual resolved geometry")
		fx.reset(); fx.event(strikes[0])
		check(Art.mechanic_texture(fx.effects[0].art_role)!=null,"Art's release has its own correct role")
		if move.kind=="volley": check(s.bullets.size()==int(move.count),"Volley shows exactly the actual projectile count")
		for data in events:
			if data.kind=="spell_burst":
				check(is_equal_approx(float(data.radius),float(move.radius)),"Burst event sends actual damage radius")
				fx.event(data); check(fx.effects.back().p==data.p,"Burst is placed at actual target, not at caster")
			if data.kind=="spell_beam": check(is_equal_approx(float(data.width),float(move.width)),"Beam event sends actual damage width")
	check(roles.size()>=10,"Normal weapons cover at least ten distinct actual effect roles")
	# Verify every campaign normal and art also resolves, without save-index remapping.
	for index in 21:
		check(Art.mechanic_texture(M.normal_role(index))!=null,"Campaign normal has mechanic art")
		check(Art.mechanic_texture(M.strike_role(index,{"attack_kind":WeaponArts.of(index).kind}))!=null,"Campaign art has mechanic art")
	fx.queue_free(); s.queue_free(); await process_frame; await process_frame
	print("WEAPON MECHANICS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
