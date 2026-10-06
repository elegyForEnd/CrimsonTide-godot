extends SceneTree
const Build=preload("res://scripts/rogue_build.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://weapon-vfx-battle-test.json"
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,1729)
	var s=app.session
	s.set_physics_process(false)
	s.enemies.clear()
	var p: Dictionary=s.players[1]
	p.rogue_selection={}; s.raid.phase="rogue_combat"
	var field=app.rogue_field
	field.visible=true
	await create_timer(.15).timeout
	field.set_process(false); field.combat.set_process(false)
	var received: Array=[]
	s.combat_event.connect(func(data): received.append(data.duplicate(true)))
	for weapon in [600,603,606,613,615,617,631,637,643]:
		p.weapon=weapon; p.combo=2
		p.attack=0; p.cast_time=0; p.swing_time=0; p.dodge_time=0
		p.strike_aim=Vector2.RIGHT; p.aim=Vector2.RIGHT
		p.swing_total=float(Catalog.weapon(weapon).rate)
		p.swing_time=maxf(.06,p.swing_total-float(Catalog.weapon(weapon).windup)-.065)
		p.pending_strike=false
		p["build_strike_context"]=Build.context(s,p,"attack")
		p.build_strike_context.route=2
		field.combat.reset(); s.bullets.clear()
		Actions.normal(s,p)
		check(received.back().kind=="strike" and received.back().weapon_index==weapon and received.back().combo_route==2,"Authoritative strike sends concrete weapon and combo route")
		field.combat.stylized.advance(.065)
		field.queue_redraw(); field.combat.queue_redraw(); field.combat.spell_light.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/weapon-vfx-battle-%d.png" % weapon)
		check(not field.combat.stylized.effects.is_empty(),"Real battle consumes weapon events")
		for effect in field.combat.stylized.effects:
			if effect.has("socket_local"):
				var socket: Dictionary=field.weapon_effect_socket(1)
				check((field.combat.stylized.get_global_transform()*effect.socket_local).distance_to(socket.stroke_tip)<.05,"Released combat geometry captures the real weapon mount")
	# Hero routes are announced once, at confirmed activation, not on a missed swing.
	p.build_forge_level=3; p.build_hero_cd=0
	p.equipped.weapon={"kind":"weapon","weapon":643,"forge_level":3}
	var ctx := Build.context(s,p,"attack"); ctx.hero_route=0
	s.spawn_enemy(p.p+Vector2(70,0),0)
	var enemy: Dictionary=s.enemies.back(); enemy.hp=10000; enemy.max_hp=10000
	Build.hero_effect(s,p,enemy,ctx)
	check(received.any(func(data): return data.kind=="hero_combo" and data.hero_route==0),"Confirmed hero route sends its own presentation event")
	var count := received.size()
	Build.hero_effect(s,p,enemy,ctx)
	check(received.size()==count,"Same hero route cannot duplicate its release event")
	field.combat.reset()
	check(field.combat.stylized.effects.is_empty() and field.combat.stylized.particles.emitters.is_empty(),"Battle transitions clear geometry and emitters")
	app.queue_free(); await process_frame; await process_frame
	print("WEAPON VFX BATTLE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
