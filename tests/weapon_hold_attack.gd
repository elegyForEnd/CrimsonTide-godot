extends SceneTree
const Hold=preload("res://scripts/weapon_hold_attack.gd")
const Actions=preload("res://scripts/rogue_actions.gd")
const FX=preload("res://scripts/stylized_vfx.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func clear_action(p: Dictionary) -> void:
	for key in ["attack","swing_time","cast_time","reload","dodge_time","hitstop","attack_buffer"]: p[key]=0.0
	for key in ["weapon_hold","build_pending_art","build_pending_art_tail"]: p.erase(key)
	p.pending_strike=false; p.ammo=10; p.mana=1000; p.art_cd=3.0
func run() -> void:
	for rogue in [false,true]:
		var s := TideSession.new(); root.add_child(s)
		s.solo({"hero":0,"mode":"roguelike" if rogue else "expedition"})
		s.launch(false,1729); s.set_physics_process(false); s.enemies.clear()
		var p: Dictionary=s.players[1]
		if rogue: p.rogue_selection={}; s.raid.phase="rogue_combat"
		var events: Array=[]
		s.combat_event.connect(func(data): events.append(data.duplicate(true)))
		for weapon in range(600,648):
			p.weapon=weapon; p.aim=Vector2.UP; clear_action(p); events.clear(); s.bullets.clear()
			s.perform(1,"attack_press")
			check(not p.pending_strike and p.ammo==10,"Press must not fire %d" % weapon)
			Hold.tick(s,p,{"fire":true},.05); s.perform(1,"attack_release")
			check(p.pending_strike or events.any(func(e): return e.kind=="strike"),"Tap starts ordinary attack %d" % weapon)
			check(not p.has("weapon_hold") and p.art_cd==3.0,"Tap clears gesture, preserves art %d" % weapon)
			clear_action(p); events.clear(); s.bullets.clear()
			var move := Hold.profile(weapon)
			s.perform(1,"attack_press"); Hold.tick(s,p,{"fire":true},float(move.hold_time)+.01)
			check(p.weapon_hold.ready and events.any(func(e): return e.kind=="hold_ready"),"Full charge readable %d" % weapon)
			check(s.bullets.is_empty() and not p.pending_strike and p.mana==1000,"Holding cannot auto fire or spend %d" % weapon)
			s.perform(1,"attack_release",{"aim":Vector2.DOWN})
			if rogue: Actions.tick(s,p,.13)
			var strikes := events.filter(func(e): return e.kind=="strike")
			check(strikes.size()==1 and strikes[0].get("charged",false),"Exactly one charged release %d" % weapon)
			if not strikes.is_empty(): check(strikes[0].aim==Vector2.DOWN and strikes[0].attack_kind==move.kind,"Release uses latest aim and designed shape %d" % weapon)
			check(p.art_cd==3.0,"Charge independent of right art cooldown %d" % weapon)
			if Catalog.weapon_family(weapon)==0:
				check(p.ammo==9 and s.bullets.size()==int(move.count),"Charged ranged ammo and projectile count %d" % weapon)
				check(s.bullets[0].remaining==int(move.pierce),"Charged shot piercing %d" % weapon)
			if move.kind=="volley":
				check(not s.bullets.is_empty() and s.bullets.all(func(b): return b.get("charged",false)),"Charged flight keeps its own painting tag %d" % weapon)
			if move.kind in ["beam","burst"]:
				var payloads := events.filter(func(e): return e.kind in ["spell_beam","spell_burst"])
				check(payloads.size()==1 and payloads[0].get("charged",false),"Charged payload tag reaches renderer %d" % weapon)
			if Catalog.weapon_family(weapon)!=0: check(p.mana<1000,"Charge costs mana %d" % weapon)
			var count := strikes.size(); s.perform(1,"attack_release")
			check(events.filter(func(e): return e.kind=="strike").size()==count,"Duplicate release cannot fire %d" % weapon)
		for reason in ["blocked","swap","dodge","dead"]:
			p.status="active"; p.weapon=600; clear_action(p); events.clear()
			Hold.begin(s,p); Hold.tick(s,p,{"fire":true},.3)
			if reason=="swap": p.weapon=601
			if reason=="dodge": p.dodge_time=.2
			if reason=="dead": p.status="dead"
			Hold.tick(s,p,{"fire_blocked":reason=="blocked"},.02)
			check(not p.has("weapon_hold"),"Cancels on "+reason)
			Hold.release(s,p)
			check(not events.any(func(e): return e.kind=="strike"),"Cancelled gesture cannot release "+reason)
		s.queue_free(); await process_frame
	var fx := FX.new(); root.add_child(fx)
	fx.socket_provider=func(_id): return {"tip":Vector2(90,100),"aim":Vector2.UP}
	fx.event({"kind":"hold_charge","p":Vector2(80,130),"weapon_index":600,"id":1,"hold_time":.5})
	fx.advance(.51)
	check(fx.effects.size()==1 and fx.effects[0].has("hold_time"),"Persistent charge light")
	fx.event({"kind":"hold_cancel","p":Vector2(80,130),"weapon_index":600,"id":1})
	check(fx.effects.is_empty() and fx.particles.emitters.is_empty(),"Cancel removes light and gathering")
	for weapon in [630,639]:
		fx.reset()
		fx.event({"kind":"hold_charge","p":Vector2(80,130),"weapon_index":weapon,"id":1,"hold_time":.5})
		check(fx.particles.emitters.is_empty(),"Clean charge has no flake emitter %d" % weapon)
		fx.event({"kind":"hold_ready","p":Vector2(80,130),"weapon_index":weapon,"id":1})
		check(fx.effects[0].has("ready_at") and fx.particles.particles.is_empty(),"Clean ready uses light pulse %d" % weapon)
		fx.event({"kind":"strike","p":Vector2(80,130),"weapon_index":weapon,"weapon":Catalog.weapon_family(weapon),"id":1,"charged":true,"attack_kind":"volley","reach":650})
		check(fx.shards.is_empty() and fx.particles.particles.is_empty(),"Clean release cannot add flake debris %d" % weapon)
	fx.queue_free(); await process_frame
	print("WEAPON HOLD: %d checks; %d failures" % [checks,failures]); quit(1 if failures else 0)
