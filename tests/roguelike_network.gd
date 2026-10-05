extends SceneTree
const RogueMap = preload("res://scripts/rogue_map.gd")
var s: TideSession
var host_mode := false
var expected := 2
var age := 0.0
var stage := 0
var checks := 0
var failures := 0
var claimed := false
var saw_event := false
var moved := false
var settled := false
var requested_loot := false
var shared_id := -1
func _initialize() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func run() -> void:
	host_mode="--server" in OS.get_cmdline_user_args()
	expected=4 if "--four" in OS.get_cmdline_user_args() else 2
	s=TideSession.new()
	s.name="Session"
	root.add_child(s)
	s.combat_event.connect(func(data: Dictionary):
		if data.get("kind","")=="rogue-boss-charge": saw_event=true)
	s.finished.connect(done)
	var error: Error
	if host_mode: error=s.host({"name":"Host","hero":0,"mode":"roguelike","rogue_rerolls":1,"rogue_weapon":0})
	else: error=s.join("127.0.0.1",{"name":"Client","hero":1,"mode":"roguelike","rogue_rerolls":3,"rogue_weapon":1})
	check(error==OK,"ENet opens")
func _process(dt: float) -> bool:
	age+=dt
	if age>20: check(false,"network timeout at stage %d" % stage); quit(1); return false
	if not s.running:
		if not host_mode and not s.players.is_empty() and not s.players.get(s.my_id(),{}).get("ready",false):
			s.configure({"name":"Client","hero":1,"mode":"roguelike","ready":true,"rogue_rerolls":3,"rogue_weapon":1})
		if host_mode and stage==0 and s.players.size()==expected:
			for p in s.players.values():
				if not p.ready: return false
			check(s.launch(false,1907),"online rogue launches")
			for p in s.players.values():
				s.roguelike.equip(s,p,preload("res://scripts/rogue_equipment.gd").make_gear(2,3))
			for p in s.players.values(): p.invuln=999
			check(s.map_id=="rogue","host uses rogue map")
			check(s.players[1].rogue_rerolls==1 and s.players[1].weapon==0,"host has own purchases")
			for p in s.players.values():
				if p.id!=1: check(p.rogue_rerolls==3 and p.weapon==1,"client has different purchases")
			s.enemies.clear()
			s.roguelike.clear_room(s)
			s.players[1].p=s.raid.reward_chest.p
			s.perform(1,"rogue_loot")
			s.elapsed+=2
			var slot := 0
			for ally in s.players.values():
				var at := Vector2(440+slot*180,s.ruins.lane_center(440+slot*180))
				ally.p=at
				if slot<s.raid.reward_drops.size(): s.raid.reward_drops[slot].p=at
				slot+=1
			s.raid["net_stage"]=1
			stage=1
		return false
	if host_mode:
		if stage==1:
			# Both peers must get a reward; reject duplicate claim by the same peer.
			s.perform(1,"rogue_loot")
			var selection: Dictionary=s.players[1].rogue_selection
			var payload := {"index":1,"id":selection.id,"version":selection.version}
			s.perform(1,"rogue_selection_drop",payload)
			shared_id=s.raid.reward_drops.back().id
			for ally in s.players.values():
				if ally.id!=1:
					s.raid.reward_drops.back().p=ally.p-Vector2(35,0)
					break
			var count: int=s.raid.reward_drops.size()
			s.perform(1,"rogue_selection_drop",payload)
			check(s.raid.reward_drops.size()==count,"duplicate share rejected")
			check(s.raid.phase=="rogue_reward","host claim leaves client reward available")
			stage=2
		elif stage==2:
			if expected==2 and s.raid.reward_claims.size()==2 and s.raid.phase=="rogue_reward":
				preload("res://tests/rogue_reward_flow.gd").claim(s,s.players[1])
			if s.raid.phase!="rogue_exit": return false
			for drop in s.raid.reward_drops:
				if drop.id==shared_id: return false
			check(true,"client picked host's shared reward over ENet")
			check(s.raid.reward_claims.size()==mini(3,expected),"Three shared categories can unlock a four-player party")
			s.players[1].p=s.ruins.exit_position(0)
			s.perform(1,"rogue_next",{"revision":s.raid.revision,"index":0})
			check(s.raid.area==1,"distant teammate blocks room transition")
			for p in s.players.values(): p.p=s.ruins.exit_position(0)
			s.perform(1,"rogue_next",{"revision":s.raid.revision,"index":0})
			check(s.raid.area==2,"group advances together")
			s.raid.floor=2
			s.raid.area=1
			s.roguelike.new_floor(s)
			s.roguelike.enter(s)
			for p in s.players.values(): p.invuln=999
			for e in s.enemies: e.cd=999
			var e: Dictionary=s.enemies[0]
			s.roguelike.combat.missile(e,"throw",Vector2(1000,580),Vector2(1300,580),5.0,1.0,0.0)
			s.roguelike.combat.zone(e,"circle",Vector2(1300,580),80.0,0.0,10.0,0.0)
			s.broadcast_combat({"kind":"rogue-boss-charge","p":e.p,"id":e.id,"floor":1,"duration":1.0})
			s.raid["net_stage"]=2
			stage=3
		elif stage==3:
			for p in s.players.values():
				if p.id!=1 and p.p.x<=500: return false
			check(true,"client input moves authoritative own character")
			for ally in s.players.values(): ally.status="extracted"
			s.roguelike.settle(s)
			stage=4
	else:
		if s.raid.get("net_stage",0)==1 and not claimed:
			check(s.roguelike.active(s) and s.ruins is RogueMap,"client enters rogue map")
			check(s.players[s.my_id()].rogue_rerolls==3,"client sees own cards")
			var p: Dictionary=s.players[s.my_id()]
			check(p.equipped.weapon.has("rogue_id"),"weapon engraving replicated")
			check(p.equipped.gear[0].get("rogue_id",-1)==2,"unique armor replicated")
			var ceiling: float=preload("res://scripts/attributes.gd").max_mana(p.attributes)+preload("res://scripts/rogue_equipment.gd").total(p,"mana")
			check(is_equal_approx(p.max_mana,ceiling),"equipment mana ceiling replicated")
			if p.rogue_selection.is_empty():
				if not requested_loot:
					s.action("rogue_loot")
					requested_loot=true
			else:
				s.action("rogue_selection_take",{"index":2,"id":p.rogue_selection.id,"version":p.rogue_selection.version})
				claimed=true
		if claimed and s.raid.get("net_stage",0)==1:
			var own: Dictionary=s.players[s.my_id()]
			for drop in s.raid.get("reward_drops",[]):
				if not drop.offer.is_empty() and own.p.distance_to(drop.p)<80: s.action("rogue_loot")
		if s.raid.get("net_stage",0)==2 and not moved:
			check(s.raid.floor==2 and s.raid.area==1,"client receives new floor")
			var expected_map=RogueMap.new()
			expected_map.generate(s.ruins.map_seed)
			expected_map.configure(1,1,true)
			check(s.ruins.terrain_hazards==expected_map.terrain_hazards and s.ruins.floor_polygon==expected_map.floor_polygon and s.ruins.extent==expected_map.extent,"client rebuilds identical forge ground and lava geometry")
			check(not s.roguelike.combat.missiles.is_empty(),"real projectile visuals replicated")
			check(not s.roguelike.combat.effects.is_empty(),"ground effects replicated")
			check(saw_event,"boss charge event replicated")
			moved=true
		if moved: s.local_input={"move":Vector2.RIGHT,"aim":Vector2.RIGHT}
	return false
func done() -> void:
	if settled: return
	settled=true
	check(s.results.size()==expected and s.results[s.my_id()].roguelike,"all peers receive rogue settlement")
	check(not s.running,"settlement stops run")
	if not host_mode: check(moved,"client completed room/visual/input verification")
	print("ROGUE NETWORK ","HOST" if host_mode else "CLIENT",": ",checks," checks / ",failures," failures")
	# Keep the authority alive while its reliable result packet is delivered.
	await create_timer(0.6).timeout
	quit(1 if failures else 0)

