extends SceneTree
var checks := 0
var failures := 0
var events: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	s.combat_event.connect(func(data): events.append(data))
	var c=s.roguelike.combat
	var names: Dictionary={}
	var moves: Dictionary={}
	for floor_index in 5:
		for variant in 8:
			for index in 2:
				s.enemies.clear(); s.bullets.clear(); c.reset(); events.clear()
				s.roguelike.spawn_minion(s,Vector2(730,580),floor_index,variant,false)
				var e: Dictionary=s.enemies[0]
				s.roguelike.spawn_minion(s,Vector2(840,580),floor_index,0,false)
				var recipient: Dictionary=s.enemies[1]
				recipient.hp=recipient.max_hp*.5
				recipient["summon_owner"]=e.id
				names[e.rogue_name]=true
				var skill: Dictionary=c.minions.skill(e,index)
				moves[skill.name]=true
				e.minion_skill=index; e.support_target=recipient.id
				e.attack_point=Vector2(820,580); e.attack_aim=Vector2.RIGHT
				c.minions.release(s,c,e)
				var observed: bool=not c.effects.is_empty() or not c.missiles.is_empty() or not c.summons.is_empty() or not s.bullets.is_empty() or not events.is_empty() or e.guard_time>0
				check(observed,"Every one of 80 moves has actual gameplay output: "+skill.name)
				if skill.kind in ["heal","repair","sacrifice_heal"]:
					check(recipient.hp>recipient.max_hp*.5 and recipient.hp<=recipient.max_hp,"Healing changes real HP and respects cap")
				if skill.kind=="shield":
					var hp: float=recipient.hp
					s.damage_enemy(recipient,2,1,Vector2.ZERO,0)
					check(recipient.hp==hp,"Shield absorbs actual damage")
				if skill.kind=="summon":
					c.tick(s,.01)
					check(s.enemies.size()==3 and s.enemies.back().get("rogue_summoned",false),"Summon creates an actual monster")
					check(s.enemies.back().max_hp<e.max_hp,"Summon is fragile")
					e.hp=0; c.tick(s,.01)
					check(s.enemies.back().hp==0,"Summon dissolves when owner dies")
	check(names.size()==40 and moves.size()==80,"40 species and 80 named individual moves")
	# Authoritative missile flight, throw arcs, impact damage, and cleanup.
	s.enemies.clear(); c.reset(); s.bullets.clear()
	s.roguelike.spawn_minion(s,Vector2(730,580),0,5,false)
	var e: Dictionary=s.enemies[0]
	var p: Dictionary=s.players[1]
	p.p=Vector2(820,580); p.invuln=0
	var hp: float=p.hp
	c.missile(e,"throw",e.p,p.p,0,.85,12)
	c.tick(s,.4)
	check(c.missiles[0].visual_height>70,"Thrown item has visible airborne arc")
	check(p.hp==hp,"Throw cannot hit before it lands")
	c.tick(s,.5)
	check(c.missiles.is_empty() and p.hp<hp,"Landing explosion does actual damage")
	c.reset(); p.invuln=0
	c.missile(e,"mist",e.p,p.p,0,.2,0)
	c.tick(s,.3)
	check(p.rogue_slow==.25,"Mist applies actual movement penalty")
	c.reset(); c.tick(s,.01)
	check(p.rogue_slow==0,"Leaving/clearing mist removes movement penalty")
	# Damage interruption prevents healing release, rather than only hiding VFX.
	s.enemies.clear(); c.reset()
	s.roguelike.spawn_minion(s,Vector2(730,580),0,4,false)
	e=s.enemies[0]
	s.roguelike.spawn_minion(s,Vector2(820,580),0,0,false)
	var ally: Dictionary=s.enemies[1]
	ally.hp=ally.max_hp*.5
	e.cd=0; e.in_attack_range=true; p.p=Vector2(800,580)
	c.update(s,e,.01)
	check(e.attack_time>0 and e.minion_skill==0,"Healer prioritizes injured ally")
	s.damage_enemy(e,1,1,Vector2.ZERO,0)
	c.update(s,e,1.4)
	check(ally.hp==ally.max_hp*.5,"Hit interrupts healing before real HP changes")
	s.queue_free()
	await process_frame
	print("ROGUE MINION SKILLS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
