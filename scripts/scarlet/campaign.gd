extends RefCounted
## Independent ADV authority. No dependency on legacy story, raid or roguelike rules.
signal changed
signal location_changed
signal presentation_requested(event: Dictionary)
signal notice(text: String)
signal battle_speech(speaker: String, text: String)
signal combat_event(event: Dictionary)
signal audio_cue(kind: String)
const Inventory=preload("res://scripts/story_inventory.gd")
var inventory=Inventory.new(self)
const Equipment=preload("res://scripts/rpg_equipment.gd")
var equipment_combat=preload("res://scripts/scarlet/equipment_combat.gd").new(self)
var fieldwork=preload("res://scripts/scarlet/fieldwork.gd").new(self)
const Combat = preload("res://scripts/scarlet/combat.gd")
const INTERACT_RADIUS := 105.0
const HERO_NAMES := ["绯月","雪璃","鸦羽"]
var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/scarlet/campaign.json"))
var state: Dictionary = {}
var path := "user://scarlet-campaign.json"
var save_enabled := true
var save_error := ""
var hero_at := Vector2(900,1530)
var facing := Vector2.UP
var allies: Array = [Vector2.ZERO,Vector2.ZERO,Vector2.ZERO]
var clock := 0.0
var moving := false
var action_time := 0.0
var action_total := .38
var action_windup := .10
var action_special := 0
var action_weapon := 1
var pending_strike: Dictionary={}
var move_phase := 0.0
var sprinting := false
var loot_rng := RandomNumberGenerator.new()
var attack_cd := 0.0
var skill_cd := 0.0
var dodge_cd := 0.0
var dodge_time := 0.0
var dodge_direction := Vector2.ZERO
var invulnerable := 0.0
var hurt_time := 0.0
var charge := 0.0
var auto_save := 0.0
var interaction: Dictionary = {}
var escort_group: Array = []
var combat = Combat.new()
var enemies: Array:
	get: return combat.enemies
var active_quest := ""
var navigation:=AStarGrid2D.new()
var navigation_zone:=""
var loading:=false
var water_hazard: Dictionary={}
var geography=preload("res://scripts/scarlet/geography.gd").new()

func _init() -> void:
	loot_rng.randomize()
	geography.install(content)
	combat.campaign = self

func new_state() -> Dictionary:
	return {"version":2,"revision":content.revision,"act":1,"stage":0,"zone":"1:0","hero":0,
		"completed":[],"accepted":[],"steps":{},"facts":{},"choices":{},"world":{"heart_intact":true,"queen_alive":true},"seen":{},
		"gallery":[],"cinema_seen":[],"pending":{},"position":[900,1530],"hp":180.0,
		"potions":5,"coins":100,"xp":0,"weapon_rank":0,"armor_rank":0,"level_points":[0,0,0],
		"unlocked":["1:0"],"visited":["1:0"],"tracked":"","checkpoint":{},"encounter":{},"escort_task":{},"escort_people":[],
		"ending_seen":false,"ending_collection":[],"history":[],"read":{},"settings":{"speed":35.0,"auto_delay":1.8},"trial_task":{},
		"party":[0,1,2],"sword":"contract","finale_backed_up":false,"started":false,"map_revision":"original-maps-1","intake_viewed":{},
		"fieldwork":{},"fieldwork_relaxed":false,
		"materials":0,"forged":0,"specialties":[[0,0,0],[0,0,0],[0,0,0]],"bag":[],"stash":[],"kits":[{"blade":1,"armor":1,"charm":0},{"blade":1,"armor":1,"charm":0},{"blade":1,"armor":1,"charm":0}],"gear":{},
		"equipment":[{},{},{}],"items_revision":0,"item_serial":0,"buyback":[],"merchant_stock":{},"overflow":[],"opened_chests":{},"waypoints":["1:0"]}

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0)!=2 or data.get("revision","")!=content.revision: return false
	for key in ["steps","facts","choices","world","seen","pending","checkpoint","encounter","settings","read"]:
		if not data.get(key) is Dictionary: return false
	for key in ["completed","accepted","gallery","cinema_seen","unlocked","visited","history","party","position"]:
		if not data.get(key) is Array: return false
	if not content.zones.has(data.get("zone","")) or data.position.size()!=2: return false
	for qid in data.completed+data.accepted:
		if not content.quests.has(qid): return false
	for qid in data.steps:
		if not content.quests.has(qid) or not (data.steps[qid] is float or data.steps[qid] is int): return false
		if int(data.steps[qid])<0 or int(data.steps[qid])>content.quests[qid].nodes.size(): return false
	if not (data.get("hero") is float or data.get("hero") is int): return false
	if int(data.hero)<0 or int(data.hero)>2 or not data.party.any(func(v): return (v is float or v is int) and int(v)==int(data.hero)): return false
	for key in ["hp","potions","coins","xp","weapon_rank","armor_rank"]:
		if not (data.get(key) is int or data.get(key) is float): return false
	if not data.pending.is_empty() and not data.pending.get("kind","") in ["scene","cinematic","question","choices","death","confirm"]: return false
	if int(data.get("items_revision",0))>=1 and not Inventory.valid_data(data): return false
	if not data.get("fieldwork",{}) is Dictionary: return false
	if not data.get("fieldwork_relaxed",false) is bool: return false
	for id in data.get("fieldwork",{}):
		var entry: Variant=data.fieldwork[id]
		if not fieldwork.profiles.has(id) or not entry is Dictionary or not entry.get("done") is Array or not entry.get("finished",false) is bool: return false
		var unique: Array=[]
		for part in entry.done:
			if not (part is int or part is float) or float(part)!=floorf(float(part)) or int(part)<0 or int(part)>=3 or int(part) in unique: return false
			unique.append(int(part))
		if entry.get("finished",false) and unique.size()!=3: return false
		if fieldwork.profiles[id].mode=="procedure":
			for i in unique.size():
				if unique[i]!=i: return false
	return true

func load_campaign(save_path: String = "") -> bool:
	loading=true
	if save_path!="": path=save_path
	state=new_state(); combat.clear(); escort_group.clear(); interaction.clear(); pending_strike.clear(); action_time=0; attack_cd=0; dodge_time=0; hurt_time=0; invulnerable=0
	fieldwork.reset()
	equipment_combat.reset()
	if FileAccess.file_exists(path):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		# The new sequence has different objectives and ending rules. Keep the old
		# file intact and open a separate story slot instead of misreading its steps.
		if data is Dictionary and data.get("revision","")=="scarlet-1":
			var replacement: String=path.trim_suffix(".json")+".crown-city.json"
			return load_campaign(replacement)
		if not valid_save(data) and FileAccess.file_exists(path+".bak"):
			data=JSON.parse_string(FileAccess.get_file_as_string(path+".bak"))
		if not valid_save(data):
			save_enabled=false; loading=false; save_error="赤月遗书存档无法读取；原存档已保留。请从菜单创建新槽。"; return false
		for key in state:
			if data.has(key): state[key]=data[key]
		state.map_revision=data.get("map_revision","")
	state.act=int(state.zone.get_slice(":",0)); state.stage=int(state.zone.get_slice(":",1))
	state.hero=int(state.hero)
	for entry in state.fieldwork.values():
		for i in entry.done.size(): entry.done[i]=int(entry.done[i])
	inventory.initialize(); inventory.restore_numeric()
	if not FileAccess.file_exists(path):
		inventory.receive(inventory.make("potion",1,0,2)); inventory.receive(inventory.make("scrap",1,0,4)); inventory.receive(inventory.make("crystal"))
	for i in state.party.size(): state.party[i]=int(state.party[i])
	hero_at=Vector2(state.position[0],state.position[1])
	if state.get("map_revision","")!="original-maps-1":
		hero_at=spawn_at(); state.map_revision="original-maps-1"; state.position=[hero_at.x,hero_at.y]
	if not walkable(hero_at): hero_at=spawn_at()
	for i in 3: allies[i]=place(hero_at+Vector2((i-1)*60,60))
	state.hp=clampf(float(state.hp),1,max_hp())
	if not state.escort_task.is_empty():
		var task: Dictionary=state.escort_task.duplicate()
		var saved_people: Array=state.escort_people.duplicate(true)
		start_escort(task.qid,current_node(content.quests[task.qid]))
		if saved_people.size()==escort_group.size():
			for i in escort_group.size():
				var saved: Dictionary=saved_people[i]
				escort_group[i].p=Vector2(saved.p[0],saved.p[1]); escort_group[i].hp=float(saved.hp); escort_group[i].following=bool(saved.get("following",false))
	elif not state.encounter.is_empty(): combat.restore(state.encounter)
	loading=false; location_changed.emit(); changed.emit(); return true

func begin() -> void:
	inventory.initialize()
	unlock_original_maps()
	if not state.pending.is_empty(): presentation_requested.emit(state.pending); return
	if not bool(state.started): state.started=true; save_campaign()
	ensure_intro()

func save_campaign() -> bool:
	if loading: return true
	if not save_enabled: return false
	state.position=[hero_at.x,hero_at.y]
	state.encounter=combat.snapshot()
	state.escort_people=[]
	for person in escort_group: state.escort_people.append({"p":[person.p.x,person.p.y],"hp":person.hp,"following":person.following})
	var text := JSON.stringify(state,"\t")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: save_error="无法保存战役，内存中的进度仍在。"; notice.emit(save_error); return false
	file.store_string(text); file.close()
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path,path+".bak")!=OK: return false
	var err := DirAccess.rename_absolute(path+".tmp",path)
	if err!=OK: notice.emit("存档写入失败："+error_string(err)); return false
	return true

func level() -> int:
	return clampi(1+int(sqrt(maxf(0,float(state.get("xp",0))))*0.30),1,50)

func max_hp() -> float:
	inventory.initialize()
	return (150.0+level()*9.0+int(state.get("armor_rank",0))*25.0+int(state.get("gear",{}).get("armor",0))*18.0+specialty(1)*8.0+inventory.bonus("hp"))*(1.0+float(inventory.modifiers().get("hp_pct",0))/100.0)

func damage(hero: int = -1) -> float:
	hero=int(state.hero) if hero<0 else hero
	inventory.initialize()
	var kit: Dictionary=state.kits[hero]
	return (24.0+level()*5.0+int(state.get("weapon_rank",0))*7.0+int(kit.blade)*11.0+int(state.forged)*6.0+int(kit.charm)*3.0+int(state.specialties[hero][0])*4.0+inventory.bonus("damage",hero))*(1.0+float(inventory.modifiers(hero).get("damage_pct",0))/100.0)

func skill_cooldown() -> float:
	return maxf(1.3,maxf(2,5-int(state.gear.charm)*.15-specialty(2)*.2)*(1.0-float(inventory.modifiers().get("cooldown",0))/100.0))

func specialty(index: int) -> int:
	return int(state.get("specialties",[[0,0,0],[0,0,0],[0,0,0]])[int(state.get("hero",0))][index])

func skill_points() -> int:
	return maxi(0,level()-1-specialty(0)-specialty(1)-specialty(2))

func learn(index: int) -> bool:
	if state.stage!=0 or index<0 or index>2 or skill_points()<=0 or specialty(index)>=10: return false
	state.specialties[int(state.hero)][index]+=1
	changed.emit(); save_campaign(); return true

func reset_specialty() -> bool:
	if state.stage!=0 or state.coins<100 or not "R-3-05" in state.completed: return false
	state.coins-=100; state.specialties[int(state.hero)]=[0,0,0]
	state.hp=minf(state.hp,max_hp()); changed.emit(); save_campaign(); return true

func zone() -> Dictionary: return content.zones[state.zone]
func terrain():
	geography.select("5:2" if not state.get("trial_task",{}).is_empty() else state.zone); return geography
func place(p: Vector2) -> Vector2: return terrain().place(p)
func safe_place(p: Vector2) -> Vector2:
	var at:=place(p)
	if walkable(at): return at
	var best:=INF
	for candidate in terrain().cells:
		var distance: float=candidate.distance_squared_to(p)
		if distance<best and walkable(candidate): best=distance; at=candidate
	return at
func spawn_at() -> Vector2: return terrain().spawn()
func gate_at() -> Vector2: return place(terrain().local(terrain().original.waypoint))
func can_travel() -> bool:
	return fieldwork.active.is_empty() and not combat.running and escort_group.is_empty() and state.trial_task.is_empty() and (state.stage==0 or hero_at.distance_to(gate_at())<=INTERACT_RADIUS)
func receive_at() -> Vector2: return place(Vector2(900,1450))
func act_data() -> Dictionary: return content.acts[int(state.act)-1]
func current_main() -> Dictionary:
	for qid in content.main_order:
		if not qid in state.completed: return content.quests[qid]
	return {}
func tracked() -> Dictionary:
	var qid: String=state.get("tracked","")
	if content.quests.has(qid) and available(content.quests[qid]) and (qid in state.accepted or qid==current_main().get("id","")): return content.quests[qid]
	return current_main()
func step_count(q: Dictionary) -> int: return int(state.steps.get(q.id,0))
func current_node(q: Dictionary = {}) -> Dictionary:
	if q.is_empty(): q=tracked()
	if q.is_empty() or step_count(q)>=q.nodes.size(): return {}
	return q.nodes[step_count(q)]
func available(q: Dictionary) -> bool:
	if q.id in state.completed: return false
	if q.id in ["S02","S03"] and not 2 in state.party: return false
	for qid in q.requires:
		if not qid in state.completed: return false
	if q.has("requires_active") and not q.requires_active in state.accepted and not q.requires_active in state.completed: return false
	return true
func accept(qid: String) -> bool:
	if not content.quests.has(qid) or not available(content.quests[qid]): return false
	var q: Dictionary=content.quests[qid]
	if q.kind=="main" and current_main().get("id","")!=qid: return false
	var first: Dictionary=q.nodes[0]
	if state.zone!=first.zone or hero_at.distance_to(place(Vector2(first.at[0],first.at[1])))>INTERACT_RADIUS: return false
	if not qid in state.accepted: state.accepted.append(qid)
	state.tracked=qid; changed.emit(); save_campaign(); return true
func track(qid: String) -> void:
	if qid in state.accepted or qid==current_main().get("id",""): state.tracked=qid; changed.emit(); save_campaign()

func ensure_intro() -> void:
	var q:=current_main()
	if q.is_empty() or not state.pending.is_empty(): return
	unlock_current()
	if q.get("auto_accept",false) and not q.id in state.accepted:
		state.accepted.append(q.id); state.tracked=q.id
		seek_step(q)
	continue_sequence(q)

func node_enabled(n: Dictionary) -> bool:
	return not n.has("when_key") or state.choices.get(n.when_key,null)==n.when_value

func seek_step(q: Dictionary) -> void:
	while step_count(q)<q.nodes.size() and not node_enabled(q.nodes[step_count(q)]):
		state.steps[q.id]=step_count(q)+1

func continue_sequence(q: Dictionary) -> void:
	if not state.pending.is_empty() or combat.running or not escort_group.is_empty(): return
	if not q.id in state.accepted: return
	var n:=current_node(q)
	if n.is_empty() or n.zone!=state.zone: return
	if n.kind=="checkpoint":
		state.world.pre_choice=true; save_checkpoint(".pre-choice")
		advance_step(q.id,n.id); return
	if n.get("chain",false):
		if n.kind=="scene": request_scene(n.scene,{"kind":"step","qid":q.id,"node":n.id})
		elif n.kind=="cinematic": request_movie(n.cinematic,{"kind":"step","qid":q.id,"node":n.id})

func save_checkpoint(suffix: String) -> void:
	if not save_enabled: return
	save_campaign()
	if FileAccess.file_exists(path): DirAccess.copy_absolute(path,path+suffix)

func unlock_current() -> void:
	var q:=current_main()
	if q.is_empty(): return
	var z: String="%d:%d" % [q.act,q.stage]
	if q.act<=state.act and not z in state.unlocked: state.unlocked.append(z)
	changed.emit(); save_campaign()

func enter_zone(z: String) -> bool:
	if not fieldwork.active.is_empty(): return false
	if not content.zones.has(z) or not z in state.unlocked or not state.pending.is_empty() or combat.running: return false
	if not escort_group.is_empty(): notice.emit("先把同行者带到接收点，再离开这段路。"); return false
	if not state.trial_task.is_empty(): notice.emit("先完成安全试航，返回船坞再出发。"); return false
	pending_strike.clear(); action_time=0; dodge_time=0
	state.zone=z; state.act=int(z.get_slice(":",0)); state.stage=int(z.get_slice(":",1))
	hero_at=spawn_at(); facing=Vector2.UP
	for i in 3: allies[i]=place(hero_at+Vector2((i-1)*65,70))
	if not z in state.visited: state.visited.append(z)
	if state.stage==0 and not z in state.waypoints: state.waypoints.append(z)
	interaction.clear(); location_changed.emit(); changed.emit(); save_campaign(); ensure_intro(); return true

func next_act() -> bool:
	var a:=int(state.act)
	if state.stage!=0 or a>=6 or not "R-%d-06" % a in state.completed: return false
	if a==5 and not state.seen.has("CIN-12"):
		request_movie("CIN-12",{"kind":"travel","act":6}); return true
	travel_act(a+1); return true

func unlock_original_maps() -> void:
	for zone_id in content.zones:
		if int(zone_id.get_slice(":",0))<=int(state.act) and not zone_id in state.unlocked: state.unlocked.append(zone_id)

func cross_original_boundary() -> void:
	if not fieldwork.active.is_empty(): return
	if combat.running or not escort_group.is_empty() or not state.trial_task.is_empty(): return
	var geo=terrain(); var native: Vector2=geo.native(hero_at)
	var stage: int=geo.original.region_at(native)
	if stage<0 or stage==geo.region.stage: return
	var target: String=geo.zone_for(int(state.act),stage)
	pending_strike.clear(); action_time=0
	state.zone=target; state.stage=int(target.get_slice(":",1)); hero_at=terrain().local(native)
	for i in 3: allies[i]=place(hero_at+Vector2((i-1)*50,60))
	if not target in state.visited: state.visited.append(target)
	navigation_zone=""; interaction.clear(); location_changed.emit(); ensure_intro(); save_campaign()

func travel_act(a: int) -> void:
	var z := "%d:0" % a
	if not z in state.unlocked: state.unlocked.append(z)
	enter_zone(z); unlock_original_maps()

func walkable(p: Vector2, radius: float = 22.0) -> bool:
	if not state.get("trial_task",{}).is_empty(): return Rect2(-680,200,820,1400).grow(-radius).has_point(p)
	if (combat.running or not escort_group.is_empty()) and not Rect2(Vector2.ZERO,terrain().region.extent).has_point(p*terrain().ratio): return false
	if not terrain().walkable(p,radius): return false
	for b in combat.barriers():
		if Rect2(b[0],b[1],b[2],b[3]).grow(radius).has_point(p): return false
	return true
func move_point(from: Vector2, delta: Vector2) -> Vector2:
	var count:=maxi(1,ceili(delta.length()/12.0))
	var result:=from
	for j in count:
		var d:=delta/float(count)
		if walkable(result+Vector2(d.x,0)): result.x+=d.x
		if walkable(result+Vector2(0,d.y)): result.y+=d.y
	return result
func sight(a: Vector2,b: Vector2) -> bool:
	for i in range(1,maxi(2,ceili(a.distance_to(b)/20.0))):
		if not walkable(a.lerp(b,float(i)/maxi(2,ceili(a.distance_to(b)/20.0))),2): return false
	return true

func navigate(from: Vector2,to: Vector2) -> Vector2:
	if sight(from,to): return from.direction_to(to)
	if navigation_zone!=state.zone:
		navigation_zone=state.zone; navigation.region=Rect2i(0,0,91,91); navigation.cell_size=Vector2(20,20)
		navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; navigation.update()
		for y in 91:
			for x in 91: navigation.set_point_solid(Vector2i(x,y),not walkable(Vector2(x,y)*20))
	var start:=near_navigation(Vector2i((from/20).round())); var end:=near_navigation(Vector2i((to/20).round()))
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(end): return Vector2.ZERO
	var path_points:=navigation.get_point_path(start,end)
	if path_points.size()<2: return Vector2.ZERO
	return from.direction_to(path_points[1])

func near_navigation(cell: Vector2i) -> Vector2i:
	if navigation.is_in_boundsv(cell) and not navigation.is_point_solid(cell): return cell
	for ring in range(1,8):
		for y in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				var p:=cell+Vector2i(x,y)
				if navigation.is_in_boundsv(p) and not navigation.is_point_solid(p): return p
	return cell

func objective_nodes() -> Array:
	var result: Array=[]
	if not state.trial_task.is_empty():
		var points: Array=[Vector2(-450,1250),Vector2(-600,650),Vector2(100,1400)]
		return [{"id":"trial-point","kind":"trial_point","p":points[int(state.trial_task.index)],"label":"试航标线 %d / 3 · 靠近确认操舵" % (int(state.trial_task.index)+1)}]
	var qs: Array=[]
	var main:=current_main()
	if not main.is_empty(): qs.append(main)
	for qid in state.accepted:
		if content.quests.has(qid) and qid!=main.get("id",""): qs.append(content.quests[qid])
	for q in content.quests.values():
		if q.kind=="side" and available(q) and not q.id in state.accepted: qs.append(q)
	for q in qs:
		if not available(q): continue
		var n:=current_node(q)
		if n.is_empty() or n.zone!=state.zone or combat.running or not escort_group.is_empty(): continue
		if not q.id in state.accepted:
			result.append({"id":"offer:"+q.id,"kind":"offer","qid":q.id,"p":place(Vector2(n.at[0],n.at[1])),"label":"与%s交谈／调查 · %s" % [q.intake.giver,q.title]})
			continue
		var item: Dictionary=n.duplicate(true); item.qid=q.id; item.p=place(Vector2(n.at[0],n.at[1])); result.append(item)
		if n.get("optional",false) and step_count(q)+1<q.nodes.size():
			var following: Dictionary=q.nodes[step_count(q)+1].duplicate(true); following.qid=q.id; following.p=place(Vector2(following.at[0],following.at[1])); result.append(following)
	if not combat.running and escort_group.is_empty():
		for entry in content.get("npc_repeats",[]):
			if entry.zone!=state.zone: continue
			var q: Dictionary=content.quests[entry.qid]
			if entry.state=="active" and (not q.id in state.accepted or step_count(q)<1): continue
			if entry.state=="complete" and not q.id in state.completed: continue
			result.append({"id":"repeat:"+entry.id,"kind":"npc_repeat","entry":entry,"p":place(Vector2(1230,1410)),"label":"与"+str(entry.speaker)+"交谈"})
		var region=terrain().region
		for index in region.chests.size():
			var cache_id: String="%d:%d:cache:%d" % [region.act,region.stage,index]
			if not state.opened_chests.has(cache_id): result.append({"id":cache_id,"kind":"original_cache","p":place(region.chests[index]/terrain().ratio),"label":"探索宝箱"})
	if combat.running: result.append_array(combat.gadgets())
	result.append_array(preload("res://scripts/scarlet/enemy_encounters.gd").nodes(self))
	if not combat.running and escort_group.is_empty():
		var geo=terrain()
		for door in geo.original.entrances():
			if door.kind=="exit":
				var back: Dictionary=geo.original.return_door(geo.region.stage)
				if not back.is_empty(): result.append({"id":"original-exit","kind":"original_portal","p":geo.place(geo.local(door.p)),"target":geo.zone_for(int(state.act),int(back.source)),"native_return":back.p,"label":"返回 · "+content.zones[geo.zone_for(int(state.act),int(back.source))].name})
			elif int(door.source)==geo.region.stage:
				var target: String=geo.zone_for(int(state.act),int(door.stage))
				result.append({"id":"original-door:"+target,"kind":"original_portal","p":geo.place(geo.local(door.p)),"target":target,"label":"进入 · "+content.zones[target].name})
	if not escort_group.is_empty(): result.append({"id":"escort-receive","kind":"receive","p":receive_at(),"label":"同行者接收点"})
	if state.stage==0:
		result.append({"id":"rest","kind":"rest","p":place(terrain().local(terrain().original.npc_at[3])),"label":"医护 · 休息与补给"})
		result.append({"id":"forge","kind":"forge","p":place(terrain().local(terrain().original.npc_at[2])),"label":"工匠 · 整备装备"})
		for service in [{"role":4,"tab":"shop","label":"商人 · 交易"},{"role":1,"tab":"stash","label":"仓库 · 寄存行装"},{"role":0,"tab":"character","label":"小队 · 装备与专精"}]:
			result.append({"id":"service:"+service.tab,"kind":"inventory","tab":service.tab,"p":place(terrain().local(terrain().original.npc_at[service.role])),"label":service.label})
		if state.act<6 and "R-%d-06" % state.act in state.completed:
			result.append({"id":"travel","kind":"travel","p":place(Vector2(900,260)),"label":"确认交通 · 前往下一章"})
	return result

func nearest() -> Dictionary:
	var best:=INTERACT_RADIUS
	var result: Dictionary={}
	for n in objective_nodes():
		var d: float=hero_at.distance_to(n.p)
		if d<=best: best=d; result=n
	if not combat.running and escort_group.is_empty() and hero_at.distance_to(gate_at())<INTERACT_RADIUS and result.is_empty():
		result={"id":"gate","kind":"gate","label":"传送阵 · 激活与地区旅行","p":gate_at()}
	return result

func use(n: Dictionary) -> bool:
	if not fieldwork.active.is_empty(): return false
	if not state.pending.is_empty() or n.is_empty() or hero_at.distance_to(n.get("p",Vector2.INF))>INTERACT_RADIUS: return false
	if n.kind=="enemy_patrol": return preload("res://scripts/scarlet/enemy_encounters.gd").use(self,n)
	if n.kind=="original_cache":
		if combat.running or state.opened_chests.has(n.id): return false
		state.opened_chests[n.id]=true; state.coins+=30+int(state.act)*12; grant_weapon(n.p,true); audio_cue.emit("chest"); changed.emit(); save_campaign(); return true
	if n.kind=="gadget": return combat.use_gadget(n.id)
	if n.kind=="original_portal":
		if not n.target in state.unlocked: state.unlocked.append(n.target)
		var destination: Variant=n.get("native_return")
		if not enter_zone(n.target): return false
		if destination!=null:
			hero_at=place(terrain().local(destination)); location_changed.emit(); save_campaign()
		return true
	if n.kind=="trial_point" and not state.trial_task.is_empty():
		state.trial_task.index+=1
		if int(state.trial_task.index)>=3:
			var task: Dictionary=state.trial_task.duplicate(); state.trial_task={}; hero_at=place(Vector2(1500,1450)); location_changed.emit()
			advance_step(task.qid,task.node); notice.emit("试航回坞，舵杆可靠，回程船现在可以使用。")
		changed.emit(); save_campaign(); return true
	if n.kind=="inventory": presentation_requested.emit({"kind":"inventory","tab":n.tab}); return true
	if n.kind in ["rest","forge","gate","travel"]:
		if combat.running: return false
		match n.kind:
			"rest": state.hp=max_hp(); state.potions=maxi(5,int(state.potions)); notice.emit("已休息。小队恢复，药剂补至五份。"); changed.emit(); save_campaign()
			"forge": presentation_requested.emit({"kind":"service"})
			"gate":
				if not state.zone in state.waypoints: state.waypoints.append(state.zone); save_campaign()
				presentation_requested.emit({"kind":"map"})
			"travel": next_act()
		return true
	if n.kind=="receive": return receive_escort()
	if combat.running: return false
	if n.kind=="npc_repeat":
		var entry: Dictionary=n.entry
		present({"kind":"scene","id":"repeat:"+entry.id,"title":"再问一句","background":["village","city","mountain","palace","harbor","throne"][int(state.act)-1],"pages":[{"speaker":entry.speaker,"actor":entry.actor,"text":entry.text}],"choices":[],"after":{}})
		return true
	var qid: String=n.get("qid","")
	if not content.quests.has(qid): return false
	if n.kind=="offer":
		var offered: Dictionary=content.quests[qid]
		if not available(offered) or qid in state.accepted: return false
		if offered.kind=="main" and current_main().get("id","")!=qid: return false
		if n.id!="offer:"+qid or offered.nodes[0].zone!=state.zone: return false
		if hero_at.distance_to(place(Vector2(offered.nodes[0].at[0],offered.nodes[0].at[1])))>INTERACT_RADIUS: return false
		state.intake_viewed[qid]=true
		present({"kind":"choices","id":"offer:"+qid,"title":offered.title,"question":"%s\n地点：%s\n%s" % [offered.intake.giver,offered.intake.place,offered.description],"choices":[{"text":"接下这件事","accept_task":qid},{"text":"先准备，稍后再来","defer":true}],"after":{}})
		return true
	if content.quests[qid].kind!="main" and not qid in state.accepted: return false
	if not qid in state.accepted: return false
	if content.quests[qid].kind=="main" and qid!=current_main().get("id",""): return false
	var expected:=current_node(content.quests[qid])
	if expected.get("optional",false) and step_count(content.quests[qid])+1<content.quests[qid].nodes.size():
		var following: Dictionary=content.quests[qid].nodes[step_count(content.quests[qid])+1]
		if n.id==following.id: state.steps[qid]=step_count(content.quests[qid])+1; expected=following
	if expected.is_empty() or n.get("id","")!=expected.id or expected.zone!=state.zone or not available(content.quests[qid]): return false
	if hero_at.distance_to(place(Vector2(expected.at[0],expected.at[1])))>INTERACT_RADIUS: return false
	active_quest=qid
	match n.kind:
		"scene": request_scene(n.scene,{"kind":"step","qid":qid,"node":n.id})
		"branch_scene": request_scene(n.yes if bool(state.choices.get(n.key,false)) else n.no,{"kind":"step","qid":qid,"node":n.id})
		"cinematic":
			var cid: String=n.cinematic
			if cid=="CIN-06": cid="CIN-06A" if bool(state.choices.get("ambush_prepared",false)) else "CIN-06B"
			request_movie(cid,{"kind":"step","qid":qid,"node":n.id})
		"clue":
			return fieldwork.start(n)
		"deduce":
			for fact in n.needs:
				if not state.facts.has(fact): notice.emit("先查看线索袋中的相关证据。"); return false
			present({"kind":"question","id":n.id,"title":n.label,"question":n.question,"options":n.options,"answer":n.answer,"after":{"kind":"step","qid":qid,"node":n.id}})
		"mechanism":
			if int(n.get("hero",-1))>=0 and state.hero!=int(n.hero): notice.emit("这处需要%s。按 %d 切换。" % [HERO_NAMES[int(n.hero)],int(n.hero)+1]); return false
			if n.get("optional_preparation",false) and not state.choices.get("ambush_prepared",false): advance_step(qid,n.id); return true
			return fieldwork.start(n)
		"fight": start_encounter(qid,n,int(n.get("count",3)))
		"boss": start_boss(qid,n)
		"escort": start_escort(qid,n)
		"trial": state.trial_task={"qid":qid,"node":n.id,"index":0}; hero_at=Vector2(-90,1400); location_changed.emit(); notice.emit("WASD 操舵，依次驶过两处试航标线，再返回船坞。此段没有敌人。"); save_campaign()
		"route": execute_route(qid,n.id)
		"confirm","depart":
			present({"kind":"confirm","id":n.id,"title":n.label,"text":"确认后继续下一段。此前已经调查的证据与救下的人会保留。","after":{"kind":"step","qid":qid,"node":n.id}})
		"final_gate":
			present({"kind":"confirm","id":n.id,"title":"进入终局前","text":"退路与三人支点已准备。确认进入王座后建立独立战前记录；可以先回营整备、完成支线。","after":{"kind":"final_gate","qid":qid,"node":n.id}})
		"approach":
			if state.choices.get("palace_approach","front")=="side": return fieldwork.start(n)
			else: start_encounter(qid,n,3)
		"checkpoint": state.world.pre_choice=true; save_checkpoint(".pre-choice"); advance_step(qid,n.id)
		"optional_boss":
			present({"kind":"choices","id":n.id,"title":n.label,"choices":[{"text":"挑战并解除威胁","key":"optional:"+qid,"value":true},{"text":"先标记兽道／绕过看守，继续救人","key":"optional:"+qid,"value":false}],"after":{"kind":"optional_boss","qid":qid,"node":n.id,"boss":n.boss}})
	return true

func present(event: Dictionary) -> void:
	state.pending=event.duplicate(true)
	state.pending["page"]=0
	interaction.clear(); save_campaign(); changed.emit(); presentation_requested.emit(state.pending)

func request_scene(sid: String, after: Dictionary, replay: bool = false) -> void:
	if not content.scenes.has(sid): push_error("Missing Scarlet scene: "+sid); return
	var event: Dictionary=content.scenes[sid].duplicate(true)
	event.kind="scene"; event.after=after; event.replay=replay
	# Empty movie slots use the new authored ADV, never old same-ID footage.
	if event.has("film") and not event.get("film_after",false) and not state.seen.has("scene-film:"+sid) and not replay:
		state.seen["scene-film:"+sid]=true
		var film: Dictionary=content.cinematics[event.film]
		if film.get("path",null)!=null and ResourceLoader.exists(str(film.path)):
			request_movie(event.film,{"kind":"film_scene","scene":sid,"continuation":after}); return
	present(event)

func request_movie(cid: String, after: Dictionary) -> void:
	var event: Dictionary=content.cinematics[cid].duplicate(true)
	event.kind="cinematic"; event.after=after; present(event)

func update_page(index: int) -> void:
	if state.pending.is_empty(): return
	state.pending.page=index; save_campaign()

func choose(slot: int) -> bool:
	var p: Dictionary=state.pending
	if p.is_empty(): return false
	if p.kind=="question":
		if slot!=int(p.answer): notice.emit("这项和已知证据不吻合。可以打开线索袋复核，再选择。"); return false
		return finish_presentation(true)
	var options: Array=p.get("choices",[])
	if slot<0 or slot>=options.size(): return false
	var item: Dictionary=options[slot]
	if item.get("defer",false):
		state.pending={}; save_campaign(); changed.emit(); return true
	if item.has("accept_task"):
		if not accept(item.accept_task): return false
		state.pending={}
		var q: Dictionary=content.quests[item.accept_task]
		if q.get("intake_scene","")!="": request_scene(q.intake_scene,{"kind":"intake","qid":q.id})
		else: continue_sequence(q)
		save_campaign(); return true
	if item.has("confirmation"):
		# Do not store a branch until the second, explicit confirmation.
		present({"kind":"choices","id":"confirm-resolution","title":"确认自己的回答","question":item.confirmation,
			"choices":[{"text":"确认我的选择","key":item.key,"value":item.value},{"text":"再想想","return_event":p}],"after":p.after})
		return true
	if item.has("return_event"): present(item.return_event); return true
	for fact in item.get("requires",[]):
		if not state.facts.has(fact): return false
	if item.has("key"): state.choices[item.key]=item.value
	if item.get("key","")=="resolution": save_checkpoint(".branch-"+str(item.value))
	if item.get("reply","")!="":
		var after: Dictionary=p.after.duplicate(true)
		if item.has("return_menu"): after={"kind":"query_return","menu":item.return_menu,"continuation":p.after}
		for fact in p.get("facts",[]): state.facts[fact]=true
		state.seen[p.id]=true; state.pending={}; request_scene(item.reply,after); return true
	return finish_presentation(true)

func finish_presentation(choice_made: bool = false) -> bool:
	var p: Dictionary=state.pending.duplicate(true)
	if p.is_empty(): return false
	if p.kind=="question" and not choice_made: return false
	if not p.get("choices",[]).is_empty() and not choice_made: return false
	if p.kind=="death": state.pending={}; combat.retry(); changed.emit(); save_campaign(); return true
	if not bool(p.get("replay",false)):
		if p.get("id","")!="": state.seen[p.id]=true
		for fact in p.get("facts",[]): state.facts[fact]=true
		if p.kind=="cinematic" and not p.id in state.cinema_seen: state.cinema_seen.append(p.id)
	state.pending={}
	if bool(p.get("replay",false)): changed.emit(); save_campaign(); return true
	if p.get("film_after",false) and p.has("film") and not state.seen.has("scene-film:"+str(p.id)):
		state.seen["scene-film:"+str(p.id)]=true
		var film: Dictionary=content.cinematics[p.film]
		if film.get("path",null)!=null and ResourceLoader.exists(str(film.path)):
			request_movie(p.film,p.get("after",{})); return true
	continue_after(p.get("after",{})); return true

func continue_after(after: Dictionary) -> void:
	match after.get("kind",""):
		"step": advance_step(after.qid,after.node)
		"intake": continue_sequence(content.quests[after.qid])
		"complete": commit_quest(after.qid)
		"travel": travel_act(int(after.act))
		"film_scene": request_scene(after.scene,after.continuation)
		"query_return":
			var menu: Dictionary=content.scenes[after.menu]
			present({"kind":"choices","id":after.menu,"title":menu.title,"question":"还有什么要问清楚？","choices":menu.choices,"after":after.continuation})
		"final_gate":
			if not state.finale_backed_up:
				state.finale_backed_up=true; save_checkpoint(".before-finale")
			advance_step(after.qid,after.node)
		"route": execute_route(after.qid,after.node)
		"optional_boss":
			if state.choices.get("optional:"+str(after.qid),false): combat.start(after.qid,after.node,after.boss,1)
			else: advance_step(after.qid,after.node)
		"boss_phase": combat.resume_phase(int(after.phase))
		"queen_finisher": combat.commit_victory()
		"queen_report": combat.commit_victory()
	changed.emit(); save_campaign()

func execute_route(qid: String,node_id: String) -> void:
	var n: Dictionary=current_node(content.quests[qid])
	var route: String=str(state.choices.get(n.get("key",""),""))
	if route=="trade":
		present({"kind":"question","id":node_id,"title":"核对原编号","question":"如何完整带回药箱，不让村医替查扣行为担保？","options":["按原编号更正收货记录，留副本","把村医写成查扣担保人","拆开每只瓶子证明没有问题"],"answer":0,"after":{"kind":"step","qid":qid,"node":node_id}})
	elif route=="fight": start_encounter(qid,n,3)
	elif route=="stealth":
		combat.start(qid,node_id,"",2); combat.context.stealth=true
		for e in combat.enemies: e.patrol_origin=e.p; e.watch=Vector2.UP
		notice.emit("绕过巡兵视线，从后侧卸门栓。被发现后可以解除守卫继续；不丢失药箱或线索。")

func advance_step(qid: String, node_id: String) -> void:
	if not content.quests.has(qid) or qid in state.completed: return
	var q: Dictionary=content.quests[qid]
	var n:=current_node(q)
	if n.is_empty() or n.id!=node_id: return
	state.steps[qid]=step_count(q)+1
	for key in n.get("effects",{}): state.world[key]=n.effects[key]
	if n.has("sword"): state.sword=n.sword
	if n.has("party"):
		state.party=[]
		for member in n.party: state.party.append(int(member))
		state.hero=0
	seek_step(q)
	if step_count(q)>=q.nodes.size():
		if q.outro!="": request_scene(q.outro,{"kind":"complete","qid":qid}); return
		commit_quest(qid)
		if qid=="R-P03": enter_zone("1:1")
	else: changed.emit(); save_campaign(); continue_sequence(q)

func grant_equipment(tier: int,fixed: bool=false) -> void:
	inventory.initialize()
	var q := 3 if fixed else Equipment.quality_roll(loot_rng,tier,"field")
	var item := inventory.make_loot(int(state.hero),tier,q,loot_rng,"","章节奖励" if fixed else "field")
	inventory.receive(item)
	combat_event.emit({"kind":"weapon_drop" if item.slot=="blade" else "equipment_drop","p":hero_at,"weapon_index":int(item.get("weapon_index",-1)),"base":item.base,"name":item.name,"quality":int(item.quality)})
	if not fixed and loot_rng.randf()<.25: inventory.receive(inventory.make("scrap",1,0,2))

func boss_equipment_drop(boss_id: String, at: Vector2) -> void:
	var receipt := "equipment_boss:"+boss_id
	if state.world.has(receipt): return
	state.world[receipt]=true
	var act := clampi(int(state.act),1,6)
	var item := inventory.make_loot(int(state.hero),act,4,loot_rng,"blade","boss")
	inventory.receive(item)
	inventory.receive(inventory.make_loot(int(state.hero),act,3,loot_rng,"armor" if loot_rng.randf()<.5 else "charm","boss"))
	inventory.receive(inventory.make(["gem_ember","gem_rime","gem_gale"][clampi(act/2,0,2)],1,0,1))
	notice.emit("首领遗物：%s · 暗金；套装与晶石已收纳。" % item.name)
	combat_event.emit({"kind":"weapon_drop","p":at,"weapon_index":int(item.weapon_index),"name":item.name,"quality":4})

func commit_quest(qid: String) -> bool:
	if qid in state.completed or not content.quests.has(qid): return false
	var q: Dictionary=content.quests[qid]
	if step_count(q)<q.nodes.size() or not available(q): return false
	state.completed.append(qid); state.accepted.erase(qid)
	state.xp+=q.reward.xp; state.coins+=q.reward.coins; state.materials+=2+int(q.act); state.hp=max_hp()
	if qid.ends_with("-06"): grant_equipment(int(q.act),true)
	state.world["completed:"+qid]=true
	if state.tracked==qid: state.tracked=""
	if qid=="S01": state.world.lamp_repaired=true
	if qid=="S02": state.world.independent_medicine=true
	if qid=="R-E01":
		state.ending_seen=true
		var ending: String=state.choices.get("resolution","")
		if not ending in state.ending_collection: state.ending_collection.append(ending)
	if qid=="R-3-06": state.party=[0,1]; state.hero=0; state.sword="backup"
	if qid.begins_with("R-") and qid.ends_with("-06"):
		var camp_zone: String="%d:0" % int(q.act)
		if not camp_zone in state.unlocked: state.unlocked.append(camp_zone)
	notice.emit("完成「%s」 · 经验 +%d / 旅费 +%d" % [q.title,q.reward.xp,q.reward.coins])
	changed.emit(); save_campaign(); ensure_intro(); return true

func start_encounter(qid: String,n: Dictionary,count: int) -> void:
	combat.start(qid,n.id,"",count)

func start_boss(qid: String,n: Dictionary) -> void:
	var boss_id: String=act_data().boss
	combat.start(qid,n.id,boss_id,1)
	combat.context.last_phase=int(n.get("last_phase",content.bosses[boss_id].phases.size()-1))
	if int(n.get("start_phase",0))>0: combat.resume_phase(int(n.start_phase))
	if boss_id=="queen" and int(n.get("start_phase",0))==0: state.party=[0]; state.hero=0
	changed.emit(); save_campaign()

func start_escort(qid: String,n: Dictionary) -> void:
	escort_group.clear()
	for i in int(n.get("count",1)):
		var p: Vector2=Vector2(n.at[0],n.at[1])+Vector2((i%3-1)*38,(i/3)*38)
		if int(n.get("count",1))==7: p=[Vector2(730,1020),Vector2(1050,980),Vector2(760,780),Vector2(1100,740),Vector2(680,470),Vector2(980,470),Vector2(940,1150)][i]
		escort_group.append({"p":place(p),"hp":80.0,"name":"%s %d" % ["担架" if qid in ["R-P02","S05","R-6-01"] else "幸存者" if qid=="R-5-02" else "同行者",i+1],"arrived":false,"following":false})
		if i<n.get("names",[]).size(): escort_group[-1].name=n.names[i]
	state.escort_task={"qid":qid,"node":n.id}
	state.checkpoint={"kind":"escort","qid":qid,"node":n.id}
	if qid in ["R-1-05","R-3-02","R-5-02"]:
		combat.start(qid,n.id,"",2,true)
	notice.emit("保持在同行者附近，护送到南侧接收点。倒下者可按 E 扶起，不会永久死亡。")
	changed.emit(); save_campaign()

func receive_escort() -> bool:
	if escort_group.is_empty(): return false
	if combat.running: notice.emit("先解除护送段的威胁。"); return false
	for person in escort_group:
		if float(person.hp)<=0: notice.emit("回到倒下的同行者身边，按 E 扶起。"); return false
		if Vector2(person.p).distance_to(receive_at())>180: notice.emit(str(person.name)+"还没到接收点。靠近他们，引导过来。"); return false
	var checkpoint: Dictionary=state.escort_task.duplicate()
	state.world["received:"+str(checkpoint.node)]=escort_group.map(func(person): return person.name)
	escort_group.clear(); state.checkpoint={}; state.escort_task={}
	advance_step(checkpoint.qid,checkpoint.node); return true

func upgrade(kind: String) -> bool:
	if state.stage!=0 or combat.running: return false
	var key: String="weapon_rank" if kind=="weapon" else "armor_rank"
	var price:=70+int(state[key])*55
	if state.coins<price or int(state[key])>=6: notice.emit("旅费不足，或已经完成全部六次整备。"); return false
	state.coins-=price; state[key]+=1; state.hp=max_hp(); changed.emit(); save_campaign(); return true

func switch_hero(index: int) -> bool:
	if not fieldwork.active.is_empty(): return false
	inventory.initialize()
	if action_time>0 or dodge_time>0: return false
	if not index in state.party: notice.emit("%s当前不在可操作队伍。装备与行李仍保留。" % HERO_NAMES[clampi(index,0,2)]); return false
	if index==state.hero: return true
	allies[int(state.hero)]=hero_at; hero_at=allies[index]; state.hero=index; inventory.sync_gear()
	state.hp=minf(state.hp,max_hp()); equipment_combat.barrier=0; equipment_combat.barrier_time=0
	changed.emit(); return true

func heal() -> bool:
	if state.potions<=0 or state.hp>=max_hp(): return false
	var before: float=float(state.hp)
	state.potions-=1; state.hp=minf(max_hp(),float(state.hp)+max_hp()*.5*(1.0+float(inventory.modifiers().get("potion",0))/100.0))
	var healed: float=float(state.hp)-before
	combat_event.emit({"kind":"heal","p":hero_at,"amount":healed}); changed.emit(); save_campaign(); return true

func attack(direction: Vector2,special: int=0) -> bool:
	if not fieldwork.active.is_empty(): return false
	inventory.initialize()
	if special<0 or special>2 or dodge_time>0: return false
	if not state.pending.is_empty() or not state.trial_task.is_empty() or (state.stage==0 and not combat.running) or action_time>0: return false
	if special==0 and attack_cd>0 or special==1 and skill_cd>0 or special==2 and charge<100: return false
	if direction.length()>.01: facing=direction.normalized()
	action_weapon=equipped_weapon(); action_special=special
	var spec: Dictionary=Catalog.weapon(action_weapon)
	action_total=maxf(.20,float(spec.rate)); action_windup=float(spec.windup)
	if special==0:
		var speed := 1.0+float(inventory.modifiers().get("haste",0))/100.0
		action_total/=speed; action_windup/=speed
	if special>0: action_total=maxf(.55,action_total); action_windup=minf(.35,action_total*.4)
	action_time=action_total; attack_cd=action_total+.04
	if special==1: skill_cd=skill_cooldown()
	if special==2: charge=0
	var radius: float=maxf(180,float(spec.reach)) if special==0 else 440.0 if special==1 else 650.0
	radius*=terrain().speed_scale()
	var amount: float=damage()*([clampf(float(spec.damage)/38.0,.55,3.4),2.0,4.8][special])
	if state.hero==1 and special==1:
		var before: float=float(state.hp)
		state.hp=minf(max_hp(),state.hp+28.0)
		var healed: float=float(state.hp)-before
		if healed>0.0: combat_event.emit({"kind":"heal","p":hero_at,"amount":healed})
		invulnerable=1.3
	if state.hero==2 and special==1: hero_at=move_point(hero_at,facing*140*terrain().speed_scale()); invulnerable=.5
	pending_strike={"kind":"attack","hero":int(state.hero),"p":hero_at,"direction":facing,"radius":radius,"special":special,"weapon_index":action_weapon,"amount":amount,"remaining":action_windup}
	var windup := pending_strike.duplicate(); windup.kind="windup"; windup.windup=action_windup
	combat_event.emit(windup)
	return true

func equipped_weapon(hero: int = -1) -> int:
	inventory.initialize()
	hero=int(state.hero) if hero<0 else hero
	return Inventory.weapon_index(state.equipment[hero].get("blade",{}),hero)

func hero_actor(hero: int) -> Dictionary:
	var active := hero==int(state.hero)
	var attacking := active and action_time>0
	return {"id":hero,"hero":hero,"weapon":action_weapon if attacking else equipped_weapon(hero),"aim":facing,
		"swing_time":action_time if attacking else 0.0,"swing_total":action_total,"cast_time":0.0,
		"build_strike_windup":action_windup,"build_strike_kind":"art" if attacking and action_special>0 else "",
		"dodge_time":dodge_time if active else 0.0,"motion":"dodge" if active and dodge_time>0 else "run" if moving and sprinting else "walk" if moving else "idle"}

func release_strike() -> void:
	var strike := pending_strike.duplicate(); pending_strike.clear()
	if strike.is_empty() or int(strike.hero)!=int(state.hero): return
	var special := int(strike.special)
	var spec: Dictionary=Catalog.weapon(int(strike.weapon_index))
	strike.p=hero_at
	combat_event.emit(strike)
	var direct: Array=[]
	# Copy the list: defeating the final foe can replace the current encounter.
	for e in combat.enemies.duplicate():
		if e.hp<=0: continue
		var diff: Vector2=e.p-hero_at
		var dot := diff.normalized().dot(Vector2(strike.direction))
		var cone := .96 if Catalog.weapon_family(int(strike.weapon_index))==0 else .88 if Catalog.weapon_family(int(strike.weapon_index))==3 or spec.get("pattern","")=="thrust" else -.05
		if diff.length()<=float(strike.radius) and (special>0 or spec.get("pattern","") in ["spin","quake"] or diff.length()<60*terrain().speed_scale() or dot>cone) and sight(hero_at,e.p):
			direct.append(e)
	var phase_before: int=combat.phase
	if not direct.is_empty(): equipment_combat.begin_strike(int(strike.hero),special)
	for e in direct:
		combat.hit(e,float(strike.amount),int(strike.hero),special)
		charge=minf(100,charge+6.0*(1.0+float(inventory.modifiers().get("charge",0))/100.0))
		if not combat.running or combat.phase!=phase_before or combat.phase_pending: return
	# One splash per secondary target per released attack; no recursion or wall penetration.
	var splash := float(inventory.modifiers(int(strike.hero)).get("splash",0))
	if special==0 and splash>0:
		for e in combat.enemies.duplicate():
			if e in direct or e.hp<=0: continue
			for target in direct:
				if Vector2(e.p).distance_to(target.p)<180*terrain().speed_scale() and sight(target.p,e.p):
					combat.hit(e,float(strike.amount)*splash/100.0,int(strike.hero),0,false); break
			if not combat.running or combat.phase!=phase_before or combat.phase_pending: return

func grant_weapon(at: Vector2, guaranteed: bool = false) -> void:
	inventory.initialize()
	var misses := int(state.world.get("weapon_drop_misses",0))
	if not guaranteed and misses<3 and loot_rng.randf()>=.30:
		state.world.weapon_drop_misses=misses+1; return
	if not guaranteed: state.world.weapon_drop_misses=0
	var source := "chest" if guaranteed else "field"
	var item := inventory.make_loot(int(state.hero),int(state.act),Equipment.quality_roll(loot_rng,int(state.act),source),loot_rng,"blade",source)
	var bag_before: int=state.bag.size(); var stash_before: int=state.stash.size()
	inventory.receive(item)
	var destination := "行囊" if state.bag.size()>bag_before else "仓库" if state.stash.size()>stash_before else "营地待领取箱"
	notice.emit("获得武器：%s · %s（已放入%s）" % [item.name,Inventory.QUALITY[int(item.quality)],destination])
	combat_event.emit({"kind":"weapon_drop","p":at,"weapon_index":int(item.weapon_index),"name":item.name,"quality":int(item.quality)})
	changed.emit()

func enemy_weapon_drop(enemy: Dictionary, encounter: Dictionary, phase: int) -> void:
	var receipt := "weapon_loot:%s:%s:%s:%d:%s" % [state.zone,str(encounter.get("qid","")),str(encounter.get("node","")),phase,str(enemy.id)]
	if state.world.has(receipt): return
	state.world[receipt]=true
	grant_weapon(enemy.p)
	if loot_rng.randf()<.22:
		var item := inventory.make_loot(int(state.hero),int(state.act),Equipment.quality_roll(loot_rng,int(state.act),"field"),loot_rng,"armor" if loot_rng.randf()<.5 else "charm")
		inventory.receive(item)
		notice.emit("获得装备：%s · %s（已自动收纳）" % [item.name,Inventory.QUALITY[int(item.quality)]])
		combat_event.emit({"kind":"equipment_drop","p":enemy.p,"base":item.base,"name":item.name,"quality":int(item.quality)})
	if loot_rng.randf()<.12: inventory.receive(inventory.make(["crystal","gem_ember","gem_rime","gem_gale"][loot_rng.randi_range(0,3)]))
	save_campaign()

func dodge(direction: Vector2) -> bool:
	if not fieldwork.active.is_empty(): return false
	if dodge_cd>0 or action_time>0 or not state.pending.is_empty(): return false
	dodge_direction=direction.normalized() if direction.length()>.01 else facing
	dodge_time=.24; dodge_cd=.85; invulnerable=.3; equipment_combat.dodge(); return true

func take_damage(amount: float, element: String, grace: float) -> void:
	var received: float=equipment_combat.incoming(amount,element)
	state.hp-=received
	invulnerable=grace
	if received>0:
		hurt_time=.18
		combat_event.emit({"kind":"hurt","p":hero_at,"damage":received})

func update(dt: float,motion: Vector2,holding_interact: bool = false) -> void:
	if not fieldwork.active.is_empty(): return
	if not state.pending.is_empty(): return
	dt=minf(dt,.05); clock+=dt; auto_save+=dt
	for key in ["action_time","attack_cd","skill_cd","dodge_cd","dodge_time","invulnerable","hurt_time"]: set(key,maxf(0,float(get(key))-dt))
	moving=motion.length()>.01
	sprinting=motion.length()>1.01
	move_phase+=dt*(11.5 if sprinting else 7.0) if moving else 0.0
	if moving and action_time<=0: facing=motion.normalized()
	if not pending_strike.is_empty():
		pending_strike.remaining-=dt
		if pending_strike.remaining<=0: release_strike()
		if not state.pending.is_empty(): return
	if dodge_time>0: motion=dodge_direction*2.8
	hero_at=move_point(hero_at,motion.limit_length(2.8)*310.0*terrain().speed_scale()*dt*(1.0+float(inventory.modifiers().get("speed",0))/100.0))
	cross_original_boundary()
	allies[int(state.hero)]=hero_at
	for i in state.party:
		if i==state.hero: continue
		var goal:=place(hero_at+Vector2(-65 if i==1 else 65,75))
		allies[i]=move_point(allies[i],navigate(allies[i],goal)*minf(300*terrain().speed_scale()*dt,Vector2(allies[i]).distance_to(goal)))
	combat.tick(dt)
	equipment_combat.tick(dt)
	if not state.pending.is_empty(): return
	water_hazard={}
	if not escort_group.is_empty() and state.escort_task.get("qid","")=="R-5-02":
		var surge: float=float(state.world.get("surge_clock",0))+dt
		var phase_time:=fmod(surge,16.0)
		state.world.surge_clock=surge
		if phase_time>=10.0:
			water_hazard={"shape":"flood","p":Vector2(900,1300),"size":Vector2(1600,600),"radius":650.0,"delay":16.0-phase_time,"total":6.0,"direction":Vector2.DOWN}
		var wave:=int(surge/16.0)
		if wave>int(state.world.get("last_surge",0)):
			state.world.last_surge=wave
			if Rect2(100,1000,1600,600).has_point(hero_at) and invulnerable<=0: take_damage(22,"tide",.8)
			for person in escort_group:
				if Rect2(100,1000,1600,600).has_point(person.p): person.hp=maxf(0,person.hp-equipment_combat.incoming(22,"tide",true))
	for person in escort_group:
		if person.hp<=0:
			if holding_interact and hero_at.distance_to(person.p)<INTERACT_RADIUS: person.hp=80.0; notice.emit("已扶起同行者。继续去接收点。"); continue
		if hero_at.distance_to(person.p)<220: person.following=true
		if person.following and hero_at.distance_to(person.p)>75:
			var toward: Vector2=navigate(person.p,hero_at)
			var next:=move_point(person.p,toward*160.0*dt)
			# Route around cover instead of getting stuck at its centre.
			if next.distance_to(person.p)<dt*8:
				next=move_point(person.p,Vector2(-toward.y,toward.x)*160.0*dt)
			person.p=next
	if not interaction.is_empty():
		if hero_at.distance_to(interaction.p)>INTERACT_RADIUS: interaction.clear()
		elif holding_interact:
			interaction.time+=dt
			if interaction.time>=interaction.total:
				var task:=interaction.duplicate(); interaction.clear(); advance_step(task.qid,task.node)
	if state.hp<=0:
		present({"kind":"death","title":"从当前安全段重新接续","text":"已获得的证据、已救的人与当前 Boss 阶段保留。没有消耗旅费惩罚。","after":{}})
	if auto_save>10: auto_save=0; save_campaign()
	changed.emit()

func restore_before_finale() -> bool:
	return restore_snapshot(".before-finale")

func restore_snapshot(suffix: String) -> bool:
	if not suffix in [".before-finale",".pre-choice"]: return false
	var checkpoint:=path+suffix
	if not FileAccess.file_exists(checkpoint): return false
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(checkpoint))
	if not valid_save(data): return false
	var collection: Array=state.ending_collection.duplicate()
	var gallery: Array=state.gallery.duplicate()
	var seen: Dictionary=state.read.duplicate()
	if save_enabled:
		save_campaign()
		if DirAccess.copy_absolute(path,path+".after-finale")!=OK: return false
	state=data
	state.fieldwork=state.get("fieldwork",{})
	state.fieldwork_relaxed=state.get("fieldwork_relaxed",false)
	fieldwork.reset()
	state.hero=int(state.hero)
	inventory.initialize(); inventory.restore_numeric()
	if not FileAccess.file_exists(path):
		inventory.receive(inventory.make("potion",1,0,2)); inventory.receive(inventory.make("scrap",1,0,4)); inventory.receive(inventory.make("crystal"))
	for i in state.party.size(): state.party[i]=int(state.party[i])
	state.pending={}
	for item in collection:
		if not item in state.ending_collection: state.ending_collection.append(item)
	for item in gallery:
		if not item in state.gallery: state.gallery.append(item)
	state.read.merge(seen,true); combat.clear(); escort_group.clear()
	hero_at=spawn_at(); location_changed.emit(); changed.emit(); save_campaign(); return true
