extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var screen=preload("res://scripts/story_screen.gd").new(); root.add_child(screen)
	var c=screen.campaign; c.state=c.new_state(); c.save_enabled=false; c.inventory.initialize(); c.loot_rng.seed=7004
	c.state.zone="1:1"; c.state.stage=1; c.state.pending={}; c.hero_at=c.spawn_at(); screen.set_active(true); screen.world.build()
	for i in 3: await process_frame
	screen.set_process(false); screen.set_physics_process(false)
	var fx=screen.world.combat_fx; fx.reset()
	var item: Dictionary=c.inventory.make_loot(0,6,4,c.loot_rng,"blade")
	c.combat_event.emit({"kind":"weapon_drop","p":c.hero_at,"weapon_index":int(item.weapon_index),"name":item.name,"quality":4})
	check(fx.drops.size()==1 and fx.drops[0].name==item.name,"drop VFX retains actual unique name instead of base weapon name")
	for pair in [["plate",3],["ruby",2],["gem_rime",0]]:
		c.combat_event.emit({"kind":"equipment_drop","p":c.hero_at+Vector2(150*fx.drops.size(),0),"base":pair[0],"name":c.inventory.BASES[pair[0]].name,"quality":pair[1]})
	check(fx.drops.size()==4,"armor, charm and gem use shared acquisition feedback")
	for i in 3: await process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		check(root.get_texture().get_image().save_png("res://output/rpg-equipment-drops.png")==OK,"real chapter renders unique and nonweapon drop effects")
	screen.free(); await process_frame
	print("RPG_EQUIPMENT_DROPS %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
