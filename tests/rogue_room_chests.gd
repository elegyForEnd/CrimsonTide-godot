extends SceneTree

var checks := 0
var failures := 0
const CHEST_ROOMS := ["combat","elite","boss","treasure"]
const NO_CHEST_ROOMS := ["shop","talent","curse","event","forge","gamble","mirror"]
const Events = preload("res://scripts/rogue_events.gd")

func _initialize() -> void: call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func resolve_choices(s, p: Dictionary) -> void:
	for attempt in 20:
		if p.rogue_selection.is_empty(): return
		var choice: Dictionary=p.rogue_selection
		var action := "rogue_selection_bank" if choice.category in ["talent","core"] else "rogue_selection_take"
		s.perform(p.id,action,{"id":choice.id,"version":choice.version,"index":0})
	check(false,"Personal rewards must finish")

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]
	resolve_choices(s,p)
	for kind in NO_CHEST_ROOMS+CHEST_ROOMS:
		var depth: int=s.roguelike.depth_count(s) if kind=="boss" else 5
		s.raid.area=depth
		s.raid.node=s.roguelike.node_at_depth(s.rogue_graph,depth)
		s.raid.route[depth-1]=kind
		s.roguelike.enter(s)
		check(s.raid.room==kind,"Entered %s for chest audit" % kind)
		s.enemies.clear()
		if kind in CHEST_ROOMS and kind!="treasure": s.roguelike.clear_room(s)
		var cleared: int=s.raid.cleared
		s.roguelike.clear_room(s)
		# Shop clearance is only exercised here to check the common reward guard.
		if kind!="shop": check(s.raid.cleared==cleared,"%s cannot clear twice" % kind)
		if kind in NO_CHEST_ROOMS:
			check(s.raid.reward_chest.is_empty(),"%s has no chest" % kind)
			check(s.raid.reward_drops.is_empty(),"%s has no free chest packets" % kind)
			resolve_choices(s,p)
			check(s.raid.phase=="rogue_exit","%s can leave after its own rewards" % kind)
			if kind=="event":
				var event_id: String=s.raid.pending_event.id
				for index in s.raid.pending_event.offer.size():
					if not Events.available(s,p,event_id,index): continue
					s.perform(p.id,"rogue_event",{"index":index,"revision":s.raid.revision})
					break
				check(s.raid.pending_event.is_empty(),"Event choices remain usable without a chest")
				resolve_choices(s,p)
			# Even a stale or injected chest cannot be claimed in a service room.
			s.raid.reward_chest={"p":p.p,"tier":1,"opened":false}
			s.perform(p.id,"rogue_loot")
			check(not s.raid.reward_chest.opened and s.raid.reward_drops.is_empty(),"%s rejects ineligible chest interaction" % kind)
			s.raid.reward_chest={}
			if kind=="mirror":
				s.roguelike.apply_room_delta(s,p,{"gear_reward":1})
				check(not p.rogue_selection.is_empty() and p.rogue_selection.category=="gear","Mirror action retains its own equipment reward")
				resolve_choices(s,p)
				check(s.raid.reward_chest.is_empty(),"Mirror reward does not create a chest")
			p.p=s.ruins.exit_position(0)
			s.perform(p.id,"rogue_next",{"index":0,"revision":s.raid.revision})
			check(s.raid.area==6,"%s can advance without opening a chest" % kind)
		else:
			check(not s.raid.reward_chest.is_empty(),"%s retains its chest" % kind)
			resolve_choices(s,p)
			p.p=s.raid.reward_chest.p
			s.perform(p.id,"rogue_loot")
			check(s.raid.reward_chest.opened,"%s chest opens" % kind)
			check(s.raid.reward_drops.filter(func(drop): return drop.category in ["weapon","gear"]).size()==2,"%s grants personal weapon and gear packets" % kind)
			var packets: int=s.raid.reward_drops.size()
			s.perform(p.id,"rogue_loot")
			check(s.raid.reward_drops.size()==packets,"%s chest cannot pay twice" % kind)
	s.disconnect_room()
	s.queue_free()
	await process_frame
	print("ROGUE ROOM CHESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
