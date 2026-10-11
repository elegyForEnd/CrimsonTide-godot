extends SceneTree
const Finish=preload("res://scripts/combat_finish.gd")
const Lights=preload("res://scripts/combat_light_pool.gd")
const Campaign=preload("res://scripts/story_campaign.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func run() -> void:
	var finish=Finish.new(); root.add_child(finish)
	var lights=Lights.new(); root.add_child(lights)
	finish.lights=lights.pulse
	lights.height_at=func(_p): return 170.0
	finish.event({"kind":"impact","p":Vector2(100,200),"damage":0})
	check(finish.contacts.is_empty(),"Zero-damage feedback never fabricates a hit")
	var impact={"kind":"impact","p":Vector2(100,200),"damage":30,"id":1,"enemy_id":7,"weapon_index":638}
	finish.event(impact); finish.event(impact)
	check(finish.contacts.size()==1 and finish.contacts[0].cell==3,"Repeated frozen contact is coalesced and uses frost artwork")
	check(lights.flashes.size()==1 and is_equal_approx(lights.pool[0].position.y,2.35),"Light respects real terrain elevation")
	finish.advance(.08); finish.event(impact)
	check(finish.contacts.size()==2,"Later independent hit remains visible")
	for i in 200:
		var hit=impact.duplicate(); hit.enemy_id=i+100; hit.weapon_index=600+i%48; finish.event(hit)
	check(finish.contacts.size()==Finish.MAX_CONTACTS,"Contact budget bounded under mass combat")
	check(lights.flashes.size()==Lights.CAPACITY,"Transient lights capped and shadow-free")
	check(lights.pool.all(func(light): return not light.shadow_enabled and light.light_bake_mode==Light3D.BAKE_DISABLED),"Flashes cannot modify baked GI or cast expensive shadows")
	finish.advance(2); lights.advance(2)
	check(finish.contacts.is_empty() and finish.marks.is_empty() and lights.flashes.is_empty(),"Contacts, dedup keys and light pool expire completely")
	finish.reset()
	var bullets: Array=[{"fx_id":31,"p":Vector2(10,10),"weapon_index":637,"height":20}]
	for i in 5:
		bullets[0].p.x+=8; finish.advance(.02); finish.observe(bullets,.02)
	check(finish.trails[31].points.size()==5,"Wake samples the same actual projectile over time")
	var count: int=finish.trails[31].points.size()
	var copy: Array=bytes_to_var(var_to_bytes(bullets))
	finish.advance(.02); finish.observe(copy,.02)
	check(finish.trails.size()==1 and finish.trails[31].points.size()==count+1,"Snapshot replacement preserves wake identity")
	copy[0].p=Vector2(2000,10); finish.advance(.02); finish.observe(copy,.02)
	check(finish.trails[31].points.size()==1,"Teleport never draws a long false connecting beam")
	finish.advance(.2); finish.observe([],.2)
	check(finish.trails.is_empty(),"Removed projectile has only a short residual wake")
	for i in 130: finish.observe([{"fx_id":i,"p":Vector2.ZERO,"weapon_index":625}],.02)
	check(finish.trails.size()<=Finish.MAX_TRAILS,"Wake budget is bounded independently of contacts")
	finish.reset(); check(finish.trails.is_empty() and finish.contacts.is_empty(),"Map reset clears all residual layers")
	var s := TideSession.new(); root.add_child(s)
	for mode in ["campaign","roguelike"]:
		s.solo({"hero":0,"mode":mode}); s.launch(false,20261011); s.set_physics_process(false)
		var p: Dictionary=s.players[1]; p.weapon=637; p.strike_aim=Vector2.RIGHT; p.combo=0
		s.bullets.clear(); s.enemies.clear()
		if mode=="roguelike":
			p.build_strike_context=preload("res://scripts/rogue_build.gd").context(s,p,"attack")
			preload("res://scripts/rogue_actions.gd").normal(s,p)
		else: s.release_strike(p)
		check(not s.bullets.is_empty(),mode+" actual release still creates its original projectile")
		check(s.bullets.all(func(b): return b.has("fx_id")),mode+" projectiles carry stable presentation IDs")
		var before: Array=s.bullets.duplicate(true)
		finish.observe(s.bullets,.02)
		check(s.bullets==before,mode+" renderer cannot mutate actual projectile rules")
		finish.reset()
	var c=Campaign.new(); c.save_enabled=false; c.state=c.new_state(); c.enter(1,1)
	var events: Array=[]; c.combat_event.connect(func(e): events.append(e.duplicate(true)))
	var enemy := {"id":"fx-test","p":c.hero_at+Vector2(85,0),"hp":99999.0,"maxhp":99999.0,"flash":0.0,"boss":false}
	c.enemies=[enemy]
	var hp: float=enemy.hp; var damage: float=c.damage()
	check(c.attack(Vector2.RIGHT),"Story real attack accepted")
	check(is_equal_approx(hp-float(enemy.hp),damage),"Story visual signal leaves the original damage unchanged")
	check(events.any(func(e): return e.kind=="story_attack") and events.any(func(e): return e.kind=="impact"),"Story attack and true contact produce separate actual events")
	check(not c.attack(Vector2.RIGHT),"Cooldown still rejects repeated attack")
	check(events.size()==2,"Rejected attack cannot replay contact or cast")
	finish.queue_free(); lights.queue_free(); s.queue_free(); await process_frame; await process_frame
	print("COMBAT FINISH ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
