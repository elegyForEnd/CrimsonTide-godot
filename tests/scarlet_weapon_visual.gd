extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	var c=screen.campaign
	c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); screen.set_active(true)
	c.state.zone="1:1"; c.state.stage=1; c.state.pending={}; c.hero_at=c.spawn_at()
	screen.world.build()
	for i in 3: await process_frame
	screen.set_process(false); screen.set_physics_process(false)
	var fx=screen.world.combat_fx
	for weapon in range(600,648):
		var family:=Catalog.weapon_family(weapon)
		var hero:=1 if family==3 else 2 if family==0 else 0
		c.state.hero=hero; c.state.pending={}; c.action_time=0; c.attack_cd=0; c.pending_strike.clear()
		var item: Dictionary=c.inventory.make(["sword","staff","dagger"][hero],3,1)
		item.weapon_index=weapon; item.name=Catalog.weapon_name(weapon)
		c.state.equipment[hero].blade=item; c.inventory.sync_gear()
		c.action_weapon=weapon; c.action_total=float(Catalog.weapon(weapon).rate); c.action_windup=float(Catalog.weapon(weapon).windup)
		c.action_time=c.action_total-c.action_windup; c.facing=Vector2.RIGHT
		screen.world.sync(0)
		var socket: Dictionary=screen.world.original.weapon_effect_socket(hero)
		check(not socket.is_empty() and socket.weapon_identity==weapon,"socket uses concrete weapon %d" % weapon)
		fx.reset()
		c.combat_event.emit({"kind":"attack","hero":hero,"p":c.hero_at,"direction":Vector2.RIGHT,"radius":float(Catalog.weapon(weapon).reach)*c.terrain().speed_scale(),"special":0,"weapon_index":weapon})
		screen.world.sync(.06)
		check(not fx.weapon_world.effects.is_empty(),"native world combat effect emitted %d" % weapon)
		check(fx.primary.effects.is_empty(),"weapon %d does not duplicate a Canvas painting" % weapon)
		c.combat_event.emit({"kind":"weapon_drop","p":c.hero_at,"weapon_index":weapon,"quality":1})
		for i in 2: await process_frame
		if weapon in [600,615,625,639]:
			if DisplayServer.get_name()!="headless":
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png("res://output/scarlet-weapon-%d.png" % weapon)
	for hero in 3:
		c.state.hero=hero; c.action_time=0
		for special in [1,2]:
			c.combat_event.emit({"kind":"attack","hero":hero,"p":c.hero_at,"direction":Vector2.LEFT,"radius":500.0,"special":special,"weapon_index":c.equipped_weapon()})
			screen.world.sync(.05); await process_frame
	check(fx.drops.size()>0,"weapon acquisition presentation remains visible")
	screen.queue_free(); await process_frame
	print("SCARLET_WEAPON_VISUAL %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
