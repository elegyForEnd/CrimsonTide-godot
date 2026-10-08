extends SceneTree
const Events = preload("res://scripts/rogue_events.gd")
const Curses = preload("res://scripts/rogue_curses.gd")
const Rooms = preload("res://scripts/rogue_rooms.gd")
const RoomUi = preload("res://scripts/rogue_room_ui.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,42424)
	var p: Dictionary=s.players[1]
	var rl=s.roguelike
	# Exercise all 25 outcomes, including the previously unasserted forge/mana/flask deltas.
	for event in Events.table():
		for i in event.options.size():
			p.rogue_curses=[]; p.rogue_selection={}; p.build_reward_queue=[]
			p.build_forge_points=0; p.build_attribute_points=0
			p.rogue_gold=1000; p.hp=p.max_hp*.8; p.mana=p.max_mana*.1; p.flask=60.0
			var delta := Events.resolve(str(event.id),i)
			var hp_before: float=p.hp
			var mana_before: float=p.mana
			s.raid.pending_event={"id":event.id,"offer":Events.options_view(event),"revision":s.raid.revision}
			check(Events.apply(s,p,i),"Option commits: %s/%d" % [event.id,i])
			check(p.rogue_gold==1000+int(delta.get("gold",0)),"Exact gold")
			check(is_equal_approx(p.hp,clampf(hp_before+p.max_hp*float(delta.get("hp_ratio",0)),1,p.max_hp)),"Exact life")
			check(is_equal_approx(p.mana,clampf(mana_before+p.max_mana*float(delta.get("mana_ratio",0)),0,p.max_mana)),"Exact mana")
			check(p.build_forge_points==int(delta.get("forge_points",0)),"Forge points usable by build")
			check(p.build_attribute_points==int(delta.get("attribute_points",0)),"Attribute points usable by build")
			check(not Events.apply(s,p,i),"No duplicate payment")
	p.rogue_selection={}; p.build_reward_queue=[]; p.rogue_curses=["CU01"]
	check(not Events.available(s,p,"EV01",2),"Duplicate curse cannot grant free equipment")
	p.flask=10.0
	check(not Events.available(s,p,"EV04",1),"Cannot skip the flask cost")
	p.rogue_curses=["CU06"]; p.hp=p.max_hp*.1
	var before: float=p.hp
	Events.commit(s,p,{"hp_ratio":.5})
	check(is_equal_approx(p.hp-before,p.max_hp*.35),"Event healing respects dry curse")
	p.rogue_curses=["CU07"]; p.flask=70.0
	Events.commit(s,p,{"flask":25.0})
	check(p.flask==75.0,"Event flask respects broken bottle capacity")
	p.rogue_curses=[]; p.rogue_selection={}; p.build_reward_queue=[]
	s.enemies.clear(); rl.combat.reset()
	s.raid.room="mirror"; s.raid.phase="rogue_exit"; s.raid.mirror_state={}
	p.rogue_mirror_used=false; p.hp=p.max_hp; p.invuln=0.0
	var cleared: int=s.raid.cleared
	var gold: int=p.rogue_gold
	rl.choose(s,p,"rogue_mirror",{"revision":s.raid.revision})
	check(s.enemies.size()==1 and s.enemies[0].get("rogue_mirror",false),"Accept spawns an actual mirror")
	check(s.raid.phase=="rogue_combat" and p.rogue_mirror_used,"Combat starts and consumes attempt")
	check(not RoomUi.panel_open("mirror",s.raid),"The service panel closes during combat")
	var e: Dictionary=s.enemies[0]
	check(e.hero==p.hero and e.weapon==p.weapon,"Mirror copies hero and weapon")
	var state: int=s.rng.state
	rl.choose(s,p,"rogue_mirror",{"revision":s.raid.revision})
	check(s.raid.mirror_state.active and p.rogue_gold==gold and s.rng.state==state,"Second click cannot roll or pay")
	# Move to a clear location, exercise real enemy update and actual damage geometry.
	e.p=rl.spawn_point(s,p.p+Vector2(60,0)); p.p=e.p+Vector2(30,0); e.cd=0.0
	rl.combat.update(s,e,.01)
	check(e.attack_time>0 and not rl.combat.effects.is_empty(),"Mirror attacks have a warning")
	before=p.hp
	rl.combat.tick(s,.95)
	check(p.hp<before,"Released mirror attack damages the player")
	s.damage_enemy(e,99999,int(p.id),Vector2.RIGHT,0)
	check(e.hp<=0,"Player can kill mirror using normal damage pipeline")
	s.enemies.clear()
	rl.tick(s,.01)
	check(s.raid.mirror_state.settled and s.raid.mirror_state.win,"Defeating mirror settles victory")
	check(p.rogue_gold>gold and p.rogue_ash_run>0,"Victory pays currencies")
	check(s.raid.cleared==cleared,"Mirror does not pay base room twice")
	gold=p.rogue_gold; rl.finish_mirror(s,true)
	check(p.rogue_gold==gold,"Victory pays exactly once")
	# A fresh challenge with a downed owner loses and removes its attacks.
	p.rogue_selection={}; p.build_reward_queue=[]; p.rogue_mirror_used=false
	s.raid.mirror_state={}; s.raid.phase="rogue_exit"
	rl.mirror_action(s,p)
	p.status="down"; rl.tick(s,.01)
	check(s.raid.mirror_state.settled and not s.raid.mirror_state.win,"Downed challenger loses")
	check(s.enemies.is_empty() and rl.combat.effects.is_empty() and p.rogue_gold==gold,"Loss cleans encounter with no reward")
	p.status="active"
	# Dedicated room state is cleared by the normal entry path.
	s.raid.pending_event={"id":"EV01","revision":s.raid.revision}
	rl.enter(s)
	check(s.raid.mirror_state.is_empty(),"Mirror state cannot leak into next room")
	print("ROGUE EVENT COMPLETION: %d checks, %d failures" % [checks,failures])
	s.queue_free()
	quit(1 if failures else 0)
