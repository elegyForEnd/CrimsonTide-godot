extends RefCounted

const RogueMap = preload("res://scripts/rogue_map.gd")
const Equipment = preload("res://scripts/rogue_equipment.gd")
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
var combat = preload("res://scripts/rogue_combat.gd").new()
var loot_serial := 0 # Never reuse a selection id, even after restarting a run.

const FLOORS := ["幽光菌林", "魔焰铸炉", "星晶幻境", "风暴空港", "黑曜魔宫"]
const AREAS_PER_FLOOR := 7
const ROOM_NAMES := {"combat":"魔物围猎", "elite":"精英试炼", "shop":"游商营火", "treasure":"遗落宝藏", "talent":"灵契圣坛", "boss":"守层者"}
const BOONS := [
	{"name":"赤刃誓约", "desc":"伤害 +12%", "stat":"rogue_damage", "value":0.12},
	{"name":"不屈之心", "desc":"最大生命 +22，立即回复 22", "stat":"rogue_hp", "value":22.0},
	{"name":"巡夜轻步", "desc":"移动速度 +18", "stat":"rogue_speed", "value":18.0},
	{"name":"黑铁庇护", "desc":"受到伤害降低 6%（最高 40%）", "stat":"rogue_defense", "value":0.06},
	{"name":"晨钟甘露", "desc":"恢复 45% 生命与全部蓝量", "stat":"heal", "value":0.45}
]

func active(s) -> bool:
	return s.raid.get("mode","")=="roguelike"

func reset(s) -> void:
	s.raid={"mode":"roguelike", "day":1, "floor":1, "area":1, "phase":"rogue_combat", "time":0.0, "kind":0, "center":Ruins.CENTER, "hazards":[], "cleared":0, "offers":[], "revision":0, "route":[], "ended":false}
	# The new mode is a fresh run; carried campaign storage is never risked.
	for p in s.players.values():
		p.pocket=Catalog.clean_container({},Catalog.POCKET_GRID)
		p.backpack=Catalog.make_bag("blue")
		p.bags=[]
		p.rogue_medicine=0 # Campaign medicine never enters this mode.
		p.rogue_boons={}
		p.rogue_stash=[]
		p.rogue_inventory_revision=0
		p.rogue_siphon_cd=0.0
		p.rogue_spell_heal_cd=0.0
		p.rogue_soul_cd=0.0
		p.rogue_gold=60
		p.rogue_rerolls=int(p.get("rogue_rerolls",0))
		p.rogue_damage=0.0
		p.rogue_hp=0.0
		p.rogue_speed=0.0
		p.rogue_defense=0.0
		var weapon: int=int(p.get("rogue_weapon",-1))
		Build.reset(s,p)
		if weapon>=0 and weapon<Catalog.WEAPONS.size():
			for i in Content.data.weapons.size():
				if Content.data.weapons[i].name==Catalog.weapon(weapon).name: equip(s,p,Content.make_weapon(i,0)); break
		p.build_reward_queue.append("starter")
	Build.departure(s)
	new_floor(s)
	enter(s)
	s.raid.phase="rogue_prepare"
	for p in s.players.values(): next_personal(s,p)
	s.message.emit("选择开局武器 · 永久战力修正：敌人生命×%.2f / 伤害×%.2f" % [s.raid.build_enemy_hp,s.raid.build_enemy_damage])

func new_floor(s) -> void:
	# Slots only provide defaults; either exit replaces the next room at entry.
	s.raid.route=["combat","talent","elite","shop","combat","treasure","boss"]

func enter(s) -> void:
	combat.reset()
	s.raid["rogue_corpses"]=[]
	s.enemies.clear()
	s.bullets.clear()
	s.world_drops.clear()
	s.pending_ultimates.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	s.ruins.chests.clear()
	s.ruins.shrines.clear()
	s.ruins.exits.clear()
	s.ruins=RogueMap.new()
	s.ruins.generate(s.seed_value+int(s.raid.floor)*100+int(s.raid.area))
	var room: String=s.raid.route[int(s.raid.area)-1]
	s.ruins.configure(int(s.raid.floor)-1,int(s.raid.area),room not in ["shop","treasure","talent"],room)
	s.map_id="rogue"
	s.raid.center=Vector2(720,575)
	s.raid.day=1 # The campaign dawn/finale hooks must never run here.
	s.raid.time=0.0
	s.raid.room=s.raid.route[int(s.raid.area)-1]
	if int(s.raid.area)==1: s.raid["rooms_seen"]=[]
	s.raid.rooms_seen.append(s.raid.room)
	s.raid["exits"]=exit_choices(s)
	s.raid.revision+=1
	s.raid.offers=[]
	s.raid["reward_claims"]=[]
	s.raid["reward_chest"]={}
	s.raid["room_rewarded"]=false
	s.raid["reward_drops"]=[]
	var spawn_index := 0
	for p in s.players.values():
		p.rogue_selection={}
		p.rogue_interact_held=false
		s.stop_search(p)
		p.p=Vector2(330+spawn_index*45,s.ruins.lane_center(330+spawn_index*45))
		spawn_index+=1
		p.invuln=2.0
		p.pending_strike=false
		p.swing_time=0.0
		p.sanity=100.0
		p.reserve=96
		p["rogue_rescued_room"]=false
		p.height=0.0; p.height_velocity=0.0; p.build_summons=[]; p.build_fields=[]; p.build_inputs=[]
	if s.raid.room=="shop":
		s.raid.phase="rogue_shop"
		roll_offers(s,true)
	elif s.raid.room in ["treasure","talent"]:
		clear_room(s)
	else:
		s.raid.phase="rogue_combat"
		s.raid.wave=1
		spawn_wave(s)
	s.message.emit("第 %d 层 · 第 %d 区：%s" % [s.raid.floor,s.raid.area,ROOM_NAMES[s.raid.room]])

func spawn_wave(s) -> void:
	var boss_wave: bool=s.raid.room=="boss" and int(s.raid.wave)==3
	var floor_index: int=int(s.raid.floor)-1
	var count: int=1 if boss_wave else 6+floor_index+(2 if s.raid.room=="elite" else 0)
	var center: float=[760.0,1530.0,2360.0][int(s.raid.wave)-1]
	var variants: Array=[]
	var pool: Array=[0,1,2,3,4,5,6,7]
	var support_count := 0
	var summon_count := 0
	for i in count:
		var choices: Array=[]
		for v in pool:
			var role: String=combat.minions.ROLES[floor_index][v]
			if i<2 and role not in ["front","melee","ambush"]: continue
			if role in ["heal","buff"] and support_count>=2: continue
			if role=="summon" and summon_count>=1: continue
			choices.append(v)
		if choices.is_empty(): choices=[0,1,2,3]
		var selected: int=choices[s.rng.randi_range(0,choices.size()-1)]
		variants.append(selected)
		pool.erase(selected)
		var role: String=combat.minions.ROLES[floor_index][selected]
		if role in ["heal","buff"]: support_count+=1
		if role=="summon": summon_count+=1
		if pool.is_empty(): pool=[0,1,2,3]
	# Shuffle with the run RNG so species do not occupy fixed spawn slots.
	for i in range(variants.size()-1,0,-1):
		var j: int=s.rng.randi_range(0,i)
		var previous: int=variants[i]
		variants[i]=variants[j]
		variants[j]=previous
	for i in count:
		var at: Vector2=spawn_point(s,Vector2(center,s.ruins.lane_center(center))) if boss_wave else dispersed_spawn_point(s,center)
		if boss_wave:
			s.spawn_enemy(at,4)
			combat.setup_boss(s.enemies.back(),floor_index)
			s.enemies.back()["build_xp_reward"]=20
			Build.enemy_budget(s,s.enemies.back())
			if s.raid.get("challenge",false):
				s.enemies.back().max_hp*=1.25
				s.enemies.back().hp=s.enemies.back().max_hp
			s.message.emit(combat.NAMES[floor_index]+"降临！")
		else:
			# Draw a varied local roster with capped support and summoning pressure.
			spawn_minion(s,at,floor_index,int(variants[i]),s.raid.room=="elite" and i<2)

func dispersed_spawn_point(s, center: float) -> Vector2:
	var left := maxf(180.0,center-230.0)
	var right := minf(s.ruins.width-180.0,center+650.0)
	var best := Vector2.ZERO
	var best_clearance := -1.0
	# Sample the whole encounter section, choosing open space rather than a grid.
	# Random candidates preserve seeded runs while maximin spacing prevents clumps.
	var candidates: Array[Vector2]=[]
	for i in 96:
		candidates.append(Vector2(s.rng.randf_range(left,right),s.rng.randf_range(s.ruins.ground_y(s.ruins.ground_top.min())+35,s.ruins.ground_y(s.ruins.ground_lower.max())-35)))
	# Narrow necks and lava can invalidate many random samples; include safe fallbacks.
	for x in range(int(left),int(right),35):
		for y in range(int(s.ruins.ground_y(s.ruins.ground_top.min()))+35,int(s.ruins.ground_y(s.ruins.ground_lower.max()))-34,30): candidates.append(Vector2(x,y))
	for candidate in candidates:
		if s.ruins.blocked(candidate,31) or s.ruins.on_lava(candidate): continue
		var clearance := INF
		for e in s.enemies: clearance=minf(clearance,candidate.distance_to(e.p))
		for p in s.players.values():
			if p.status=="active": clearance=minf(clearance,candidate.distance_to(p.p)*0.55)
		if clearance>best_clearance:
			best=candidate
			best_clearance=clearance
		# Prefer random positions with ample breathing room; grid is fallback only.
		if best_clearance>=150.0: return best
	# Dense elite waves may fill their first section. Expand slightly rather than
	# stacking another monster on an occupied spawn or putting it near a player.
	if best_clearance<100.0:
		for x in range(int(180.0),int(s.ruins.fork_start-80.0),25):
			for y in range(int(s.ruins.ground_y(s.ruins.ground_top.min()))+35,int(s.ruins.ground_y(s.ruins.ground_lower.max()))-34,30):
				var candidate := Vector2(x,y)
				if s.ruins.blocked(candidate,31) or s.ruins.on_lava(candidate): continue
				var clearance := INF
				for e in s.enemies: clearance=minf(clearance,candidate.distance_to(e.p))
				for p in s.players.values():
					if p.status=="active": clearance=minf(clearance,candidate.distance_to(p.p)*.55)
				if clearance>best_clearance:
					best=candidate
					best_clearance=clearance
	if best_clearance>=0.0: return best
	return spawn_point(s,Vector2(center,s.ruins.lane_center(center)))

func spawn_point(s, at: Vector2) -> Vector2:
	for ring in range(0,16):
		for n in 16:
			var candidate: Vector2=at+Vector2.from_angle(n*TAU/16)*ring*18
			if not s.ruins.blocked(candidate,31): return candidate
	return Vector2(330,s.ruins.lane_center(330))

func spawn_minion(s, at: Vector2, floor_index: int, variant: int, elite: bool) -> void:
	s.spawn_enemy(spawn_point(s,at),0 if combat.minions.ROLES[floor_index][variant] in ["front","melee","ambush"] else 1)
	combat.setup_minion(s.enemies.back(),floor_index,variant,elite,s.rng)
	s.enemies.back()["build_elite"]=elite
	s.enemies.back()["build_xp_reward"]=6 if elite else 2
	Build.enemy_budget(s,s.enemies.back())

func tick(s, dt: float) -> void:
	if s.raid.phase=="rogue_prepare":
		var waiting := false
		for p in s.players.values():
			if p.connected and p.status=="active" and (not p.rogue_selection.is_empty() or not p.build_reward_queue.is_empty()): waiting=true
		if not waiting: s.raid.phase="rogue_combat"; s.raid.revision+=1
		return
	combat.tick(s,dt)
	for corpse in s.raid.get("rogue_corpses",[]): corpse.time=maxf(0,corpse.time-dt)
	for p in s.players.values():
		if (p.status!="active" or not p.connected) and not p.get("rogue_selection",{}).is_empty():
			var selection: Dictionary=p.rogue_selection
			add_reward_drop(s,p.p,int(selection.tier),{},0.0,-1,str(selection.get("category","gear")))
			s.raid.reward_drops.back()["offers"]=selection.offers.duplicate(true)
			p.rogue_selection={}
		if p.status!="active": continue
		for drop in s.raid.get("reward_drops",[]):
			var owner: Dictionary=s.players.get(int(drop.owner),{})
			if drop.get("personal",false) and (owner.is_empty() or not owner.connected): drop.personal=false; drop.owner=-1
		if s.raid.phase=="rogue_combat" and s.ruins.on_lava(p.p) and p.height<=12:
			var resist := minf(.3,Build.r(p,28,[.1,.15,.2])+(.2 if Build.gear(p,7) else 0)+(.2 if Build.gear(p,59) else 0))
			p.hp=maxf(0.0,p.hp-Build.incoming(s,p,s.incoming_damage(p,14.0*dt*(1.0-resist)),{},"lava"))
			p.flask_time=0.0; p.build_last_hurt=s.elapsed
			p.rogue_lava=true
			if p.hp<=0: s.down(p)
		else: p.rogue_lava=false
	if s.raid.phase=="rogue_reward": finish_rewards(s)
	if s.raid.phase!="rogue_combat" or not s.enemies.is_empty(): return
	if int(s.raid.wave)<3:
		var gate: float=[0.0,1120.0,1990.0][int(s.raid.wave)]
		for p in s.players.values():
			if p.status=="active" and p.p.x>=gate:
				s.raid.wave+=1
				spawn_wave(s)
				break
	else: clear_room(s)

func clear_room(s) -> void:
	if s.raid.get("room_rewarded",false): return
	s.raid["room_rewarded"]=true
	combat.reset()
	s.raid.cleared+=1
	for p in s.players.values():
		p.rogue_gold+=25+int(s.raid.floor)*10+(50 if s.raid.get("challenge",false) else 0)
		Build.award(s,p)
	s.bullets.clear()
	s.pending_ultimates.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	s.raid.phase="rogue_reward"
	s.raid.offers=[]
	if s.raid.room=="talent":
		s.raid.revision+=1
		s.message.emit("灵契圣坛 · 每人两轮天赋三选一 · 可打开构筑配置")
		for p in s.players.values(): next_personal(s,p)
		finish_rewards(s)
		return
	var tier := mini(5,int(s.raid.floor)+(1 if s.raid.room in ["elite","boss","treasure"] else 0))
	var at := Vector2(480,s.ruins.lane_center(480))
	for p in s.players.values():
		if p.status=="active": at=p.p; break
	s.raid.reward_chest={"p":spawn_point(s,at+Vector2(100,0)),"tier":tier,"opened":false}
	s.raid.revision+=1
	s.message.emit("宝箱已出现 · 靠近按 E 开启")
	for p in s.players.values(): next_personal(s,p)

# All loot and pending choices live in the authoritative snapshot. A pickup
# removes its world packet before granting a personal, versioned selection.
func roll_tier(s) -> int:
	var weights: Array=[[45,45,9,1,0,0],[10,40,42,8,0,0],[0,10,45,38,7,0],[0,0,20,50,28,2],[0,0,5,35,52,8]][clampi(int(s.raid.floor)-1,0,4)]
	var roll: int=s.rng.randi_range(1,100)
	for i in weights.size():
		roll-=int(weights[i])
		if roll<=0: return i
	return 0

func reward_offers(s, tier: int, category: String = "gear", p: Dictionary = {}) -> Array:
	var offers: Array=[]
	if category in ["talent","core","boon"]:
		var pool: Array=[]
		for def in Content.data.talents:
			if (category=="core")!=(def.category=="K"): continue
			if not p.is_empty() and int(p.build_talents.get(def.id,0))>=int(def.max_rank): continue
			pool.append(def)
		for i in mini(3,pool.size()):
			var at: int=s.rng.randi_range(0,pool.size()-1)
			if not p.is_empty():
				var directions: Array=build_directions(p)
				if category=="core" and i<2:
					var preferred: int=directions[mini(i,directions.size()-1)]
					for j in pool.size():
						if int(pool[j].school)==preferred: at=j; break
				elif i==2 and category!="core":
					var upgrades: Array=[]
					for j in pool.size():
						if p.build_talents.has(pool[j].id): upgrades.append(j)
					if not upgrades.is_empty(): at=int(upgrades[s.rng.randi_range(0,upgrades.size()-1)])
				elif s.rng.randf()<.65:
					var suited: Array=[]
					for j in pool.size():
						if int(pool[j].school) in directions.slice(0,2): suited.append(j)
					if not suited.is_empty(): at=int(suited[s.rng.randi_range(0,suited.size()-1)])
			if i==0 and not p.is_empty() and int(p.build_cultivation)<=3:
				var school: int={1:0,2:1,0:2,3:6}.get(Catalog.weapon_family(int(p.weapon)),0)
				for j in pool.size():
					if pool[j].school==school and pool[j].category=="N": at=j; break
			if category!="core" and i<2 and not p.is_empty() and pool[at].id in p.build_library:
				var fresh: Array=[]
				for j in pool.size():
					if pool[j].id not in p.build_library: fresh.append(j)
				if not fresh.is_empty(): at=int(fresh[s.rng.randi_range(0,fresh.size()-1)])
			var def: Dictionary=pool.pop_at(at)
			offers.append({"name":def.name,"desc":def.text,"talent_id":def.id,"tier":tier,"price":50,"school":def.school})
		return offers
	var pool: Array=range(48 if category in ["weapon","starter"] else Equipment.GEAR.size())
	for i in 3:
		var choice: int=pool.pop_at(s.rng.randi_range(0,pool.size()-1))
		var item: Dictionary=Content.make_weapon(choice,tier) if category in ["weapon","starter"] else Equipment.make_gear(choice,tier)
		if category=="weapon" and s.rng.randf()<.25: item=Equipment.engrave(item,s.rng.randi_range(0,23))
		offers.append({"name":Catalog.item_name(item),"desc":Equipment.description(item),"item":item,"tier":tier,"price":0})
	return offers

func build_directions(p: Dictionary) -> Array:
	var family := Catalog.weapon_family(int(p.weapon))
	var default: Array={1:[0,9],2:[1,8],0:[2,7],3:[6,7]}[family]
	var weights: Dictionary={int(default[0]):3,int(default[1]):2}
	var weapon: int=Build.weapon_id(p)
	var thematic: int=3 if weapon in [6,16,28,38,43] else 4 if weapon in [7,17,29,39] else 5 if weapon in [8,18,30,40] else 10 if weapon in [23,47] else 11 if weapon in [36,48] else -1
	if thematic>=0: weights[thematic]=float(weights.get(thematic,0))+4
	for id in p.build_talents:
		var school: int=int(Content.entry(id).school)
		weights[school]=float(weights.get(school,0))+int(p.build_talents[id])*2
	var result: Array=weights.keys()
	result.sort_custom(func(a,b): return float(weights[a])>float(weights[b]) or (weights[a]==weights[b] and int(a)<int(b)))
	return result

func next_personal(s, p: Dictionary) -> void:
	if p.status!="active" or not p.rogue_selection.is_empty() or p.build_reward_queue.is_empty(): return
	var category: String=p.build_reward_queue.pop_front()
	loot_serial+=1
	p.rogue_selection={"id":loot_serial,"version":0,"tier":0,"category":category,"personal":true,"offers":reward_offers(s,0,category,p)}

func add_reward_drop(s, at: Vector2, tier: int, offer: Dictionary = {}, delay: float = 0.0, owner: int = -1, category: String = "gear") -> void:
	loot_serial+=1
	s.raid.reward_drops.append({"id":loot_serial,"p":spawn_point(s,at),"tier":tier,"offer":offer.duplicate(true),"born":s.elapsed,"delay":delay,"owner":owner,"category":category})

func loot_interact(s, p: Dictionary) -> void:
	if p.status!="active" or not p.get("rogue_selection",{}).is_empty(): return
	var chest: Dictionary=s.raid.get("reward_chest",{})
	if not chest.is_empty() and not chest.opened and p.p.distance_to(chest.p)<=85:
		chest.opened=true
		chest["opened_at"]=s.elapsed
		var categories: Array=["weapon","gear"]
		var index := 0
		for ally in s.players.values():
			if not ally.connected: continue
			for category in categories:
				add_reward_drop(s,chest.p+Vector2((index%4-1)*70,45+floori(index/4.0)*50),roll_tier(s),{},.65+index*.04,int(ally.id),category)
				s.raid.reward_drops.back()["personal"]=true
				index+=1
			# Personal, bound attribute shards use one roll per opened chest/player.
			var chance := .5 if s.raid.room=="boss" else .2
			if ally.build_chest_attribute_drops<2 and s.rng.randf()<chance:
				add_reward_drop(s,chest.p+Vector2((index%4-1)*70,45+floori(index/4.0)*50),0,{"name":"属性灵晶 +1","desc":"拾取获得1点局内属性，可在构筑页分配。","attribute_points":1},.65+index*.04,int(ally.id),"attribute")
				s.raid.reward_drops.back()["personal"]=true
				ally.build_chest_attribute_drops+=1
				index+=1
		s.effect.emit("seal",chest.p)
		s.broadcast_audio("chest",p)
		s.raid.revision+=1
		return
	var nearest := -1
	var distance := 80.0
	for i in s.raid.get("reward_drops",[]).size():
		var drop: Dictionary=s.raid.reward_drops[i]
		if s.elapsed<float(drop.born)+float(drop.delay): continue
		if drop.get("personal",false) and int(drop.owner)!=int(p.id): continue
		if not drop.get("personal",false) and drop.owner==p.id and s.elapsed<float(drop.born)+1.0: continue
		var d: float=p.p.distance_to(drop.p)
		if d<distance: nearest=i; distance=d
	if nearest<0: return
	var drop: Dictionary=s.raid.reward_drops[nearest]
	s.raid.reward_drops.remove_at(nearest)
	s.broadcast_audio("loot",p)
	if not drop.offer.is_empty():
		if not apply_offer(s,p,drop.offer): s.raid.reward_drops.append(drop)
	else:
		p.rogue_selection={"id":drop.id,"version":0,"tier":drop.tier,"category":drop.get("category","gear"),"offers":drop.offers if drop.has("offers") else reward_offers(s,int(drop.tier),str(drop.get("category","gear")),p)}
	s.raid.revision+=1

func apply_offer(s, p: Dictionary, offer: Dictionary) -> bool:
	if offer.has("attribute_points"):
		p.build_attribute_points+=int(offer.attribute_points)
		p.rogue_inventory_revision+=1
		s.message.emit("拾取属性灵晶 · 属性点 +%d · Tab → 构筑 → 七属性" % int(offer.attribute_points))
		return true
	if offer.has("talent_id"):
		var id := str(offer.talent_id)
		if id not in p.build_library:
			if p.build_library.size()-p.build_talents.size()>=12:
				s.message.emit("未激活收藏已满：行囊中遗忘一项，或暂存修为")
				return false
			p.build_library.append(id)
			if Content.entry(id).category=="K":
				var school: int=int(Content.entry(id).school)
				var basic: String="T%03d" % (school*8+1)
				var has_basic := false
				for known in p.build_library:
					var def := Content.entry(known)
					if int(def.school)==school and def.category=="N": has_basic=true; break
				if not has_basic and p.build_library.size()-p.build_talents.size()<12: p.build_library.append(basic)
		Build.activate(s,p,id,1)
	elif offer.has("flask_refill"):
		if p.flask>50 or p.flask_shop_floor==int(s.raid.floor): return false
		p.flask=minf(100,p.flask+50); p.flask_shop_floor=int(s.raid.floor)
	elif offer.has("item"):
		if offer.item.kind=="medicine": p.flask=minf(100,p.flask+50)
		elif not equip(s,p,offer.item): return false
	else: return false
	p.rogue_inventory_revision+=1
	return true

func selection_action(s, p: Dictionary, kind: String, payload: Dictionary) -> void:
	var selection: Dictionary=p.get("rogue_selection",{})
	if selection.is_empty() or int(payload.get("id",-1))!=selection.id or int(payload.get("version",-1))!=selection.version: return
	if kind=="rogue_selection_reroll":
		if p.rogue_rerolls<=0: return
		p.rogue_rerolls-=1
		selection.offers=reward_offers(s,int(selection.tier),str(selection.get("category","gear")),p)
		selection.version+=1
		return
	if kind=="rogue_selection_bank" and selection.get("category","") in ["talent","core"]:
		p.rogue_selection={}; next_personal(s,p); finish_rewards(s); s.raid.revision+=1
		return
	if kind=="rogue_selection_return" and selection.get("personal",false): return
	if kind=="rogue_selection_return":
		add_reward_drop(s,p.p+Vector2(45,0),int(selection.tier),{},0.0,p.id,str(selection.get("category","gear")))
		s.raid.reward_drops.back()["offers"]=selection.offers.duplicate(true)
		p.rogue_selection={}
		return
	var index := int(payload.get("index",-1))
	if index<0 or index>=selection.offers.size() or kind not in ["rogue_selection_take","rogue_selection_drop"]: return
	var offer: Dictionary=selection.offers[index]
	if kind=="rogue_selection_drop" and not offer.has("item"): return
	if kind=="rogue_selection_drop": add_reward_drop(s,p.p+Vector2(45,0),int(selection.tier),offer,0.0,p.id)
	else:
		if not apply_offer(s,p,offer): return
	p.rogue_selection={}
	next_personal(s,p)
	if p.id not in s.raid.reward_claims: s.raid.reward_claims.append(p.id)
	if s.raid.phase in ["rogue_reward","rogue_shop_reward"]: finish_rewards(s)
	s.raid.revision+=1

func roll_offers(s, _shop: bool, target: Dictionary = {}) -> void:
	var players: Array=s.players.values() if target.is_empty() else [target]
	for p in players:
		var offers: Array=[]
		for category in ["weapon","weapon","gear","gear","gear"]:
			var offer: Dictionary=reward_offers(s,roll_tier(s),category,p)[0]
			offer.price=50 if category=="talent" else 65+int(s.raid.floor)*10
			offers.append(offer)
		offers.append({"name":"血瓶补充 50%","desc":"容量不高于50%时可买，每层一次；不会立即治疗。","flask_refill":50,"price":45,"tier":0,"sold":p.flask_shop_floor==int(s.raid.floor)})
		p["rogue_shop_offers"]=offers
	s.raid.offers=s.players.values()[0].get("rogue_shop_offers",[]).duplicate(true)
	s.raid.revision+=1

func equip(s,p: Dictionary,item: Dictionary) -> bool:
	# Replaced equipment stays in the run's slot-free reserve, never campaign storage.
	var old: Dictionary=p.equipped.weapon if item.kind=="weapon" else p.equipped.gear[Catalog.gear_slot(item)]
	if not old.is_empty():
		if p.rogue_stash.size()>=12:
			s.message.emit("备用行囊已满：先分享或丢弃一件装备")
			return false
		p.rogue_stash.append(old.duplicate(true))
	if not item.has("instance_id"):
		loot_serial+=1; item=item.duplicate(true); item["instance_id"]="%d:%d" % [s.seed_value,loot_serial]
	if item.kind=="weapon":
		p.equipped.weapon=item.duplicate(true)
		p.weapon=int(item.weapon)
		var clip: int=s.RogueActions.clip(p)
		var rounds: int=int(p.ammo)
		p.ammo=mini(rounds,clip)
		p.reserve=int(p.reserve)+maxi(0,rounds-clip) # Moving rounds out of a smaller magazine never creates ammunition.
		p.reload=0.0
		p.combo=0
		p.pending_strike=false
		if Build.safe(s,p): Build.bind_forge(p)
	else: p.equipped.gear[Catalog.gear_slot(item)]=item.duplicate(true)
	s.refresh_max_hp(p)
	p.rogue_inventory_revision+=1
	return true

func inventory_action(s, p: Dictionary, payload: Dictionary) -> void:
	if int(payload.get("version",-1))!=int(p.get("rogue_inventory_revision",0)): return
	if s.pending_ultimates.has(p.id) or p.pending_strike or p.swing_time>0 or p.cast_time>0 or p.dodge_time>0:
		s.message.emit("当前动作结束后可管理行囊")
		return
	var source := str(payload.get("source",""))
	var index := int(payload.get("index",-1))
	var verb := str(payload.get("verb",""))
	var item: Dictionary={}
	if source=="reserve":
		if index<0 or index>=p.rogue_stash.size() or verb not in ["equip","discard"]: return
		item=p.rogue_stash.pop_at(index)
		if verb=="equip":
			var hp: float=p.hp
			equip(s,p,item)
			p.hp=minf(hp,p.max_hp) # Repeated armour swaps cannot generate health.
	elif source=="equipped":
		if index<0 or index>3 or verb not in ["stow","discard"]: return
		item=p.equipped.weapon if index==0 else p.equipped.gear[index-1]
		if item.is_empty(): return
		if verb=="stow":
			if p.rogue_stash.size()>=12: return
			p.rogue_stash.append(item.duplicate(true))
		if index==0:
			p.equipped.weapon={}
			s.restore_issue_weapon(p)
		else: p.equipped.gear[index-1]={}
		s.refresh_max_hp(p)
	elif source=="supply":
		if verb=="use":
			s.perform(p.id,"heal")
			return
		return # The bound flask cannot be dropped.
		item={"kind":"medicine"}
	else: return
	p.rogue_inventory_revision+=1
	if verb=="discard":
		var tier := int(item.get("tier",1))
		add_reward_drop(s,p.p+Vector2(45,0),tier,{"name":Catalog.item_name(item),"item":item,"tier":tier},0.0,p.id)
	s.message.emit("已丢弃 "+Catalog.item_name(item) if verb=="discard" else "已更新本局装备")

func choose(s,p: Dictionary,kind: String,payload: Dictionary) -> void:
	if p.status!="active" or not s.running or s.raid.ended: return
	if kind=="rogue_build":
		Build.management(s,p,payload)
		return
	if kind=="rogue_inventory":
		inventory_action(s,p,payload)
		return
	if kind=="rogue_loot":
		loot_interact(s,p)
		return
	if kind.begins_with("rogue_selection_"):
		selection_action(s,p,kind,payload)
		return
	# Reject clicks from an earlier room or an earlier offer roll.
	if int(payload.get("revision",-1))!=int(s.raid.revision): return
	if kind=="rogue_reroll" and s.raid.phase=="rogue_shop" and p.rogue_rerolls>0:
		p.rogue_rerolls-=1
		roll_offers(s,true,p)
	elif kind=="rogue_take" and s.raid.phase=="rogue_shop":
		var index: int=int(payload.get("index",-1))
		if index<0 or index>=p.rogue_shop_offers.size(): return
		var offer: Dictionary=p.rogue_shop_offers[index]
		if offer.get("sold",false) or p.rogue_gold<int(offer.price): return
		if not apply_offer(s,p,offer): return
		p.rogue_gold-=int(offer.price)
		offer.sold=true
		s.raid.revision+=1
	elif kind=="rogue_next" and s.raid.phase in ["rogue_shop","rogue_exit"]:
		var index := int(payload.get("index",-1))
		if index<0 or index>=s.raid.exits.size(): return
		if p.p.distance_to(s.ruins.exit_position(index))>64: return
		for ally in s.players.values():
			if ally.connected and (ally.status=="down" or not ally.get("rogue_selection",{}).is_empty() or (ally.status=="active" and ally.p.x<s.ruins.fork_start)): return
		var destination: Dictionary=s.raid.exits[index]
		s.raid["challenge"]=destination.get("challenge",false)
		if int(s.raid.area)<AREAS_PER_FLOOR: s.raid.route[int(s.raid.area)]=destination.room
		if s.raid.phase=="rogue_shop":
			s.raid.cleared+=1
			for ally in s.players.values(): Build.award(s,ally)
			s.raid["pending_destination"]=str(destination.room)
			var waiting := false
			for ally in s.players.values(): next_personal(s,ally); waiting=waiting or not ally.rogue_selection.is_empty()
			if waiting: s.raid.phase="rogue_shop_reward"; s.raid.revision+=1; return
		advance(s,str(destination.room))

func exit_choices(s) -> Array:
	if int(s.raid.area)==AREAS_PER_FLOOR:
		if int(s.raid.floor)==5: return [{"room":"finish","name":"凯旋归城","desc":"完成本次闯关"}]
		var next_exits := random_destinations(s)
		for destination in next_exits: destination.name="下一层 · "+destination.name
		return next_exits
	if int(s.raid.area)==AREAS_PER_FLOOR-1:
		return [{"room":"boss","name":"守层者","desc":"击败首领，进入下一层"},{"room":"boss","name":"守层者 · 挑战","desc":"首领生命 +25% · 额外 50 魔晶","challenge":true}]
	return random_destinations(s)

func random_destinations(s) -> Array:
	var pool := ["combat","elite","shop","treasure","talent"]
	var descriptions := {"combat":"迎战魔物 · 通关奖励","shop":"安全补给 · 消耗魔晶购买","elite":"更强敌人 · 更高品质装备","treasure":"安全宝藏 · 免费选择装备","talent":"灵契圣坛 · 两轮天赋三选一"}
	var choices: Array=[]
	for i in 2:
		var index: int=s.rng.randi_range(0,pool.size()-1)
		var room: String=pool.pop_at(index)
		choices.append({"room":room,"name":ROOM_NAMES[room],"desc":descriptions[room]})
	return choices

func finish_rewards(s) -> void:
	if s.raid.phase=="rogue_prepare": return
	if s.raid.phase=="rogue_shop_reward":
		for ally in s.players.values():
			if ally.connected and (not ally.rogue_selection.is_empty() or not ally.build_reward_queue.is_empty()): return
		advance(s,str(s.raid.get("pending_destination","combat")))
		return
	if s.raid.phase!="rogue_reward": return
	if not s.raid.get("reward_chest",{}).is_empty() and not s.raid.reward_chest.opened: return
	# Three shared category packets cannot require four independent player claims.
	# Only unresolved choices block the exit; already chosen ground items do not.
	for drop in s.raid.get("reward_drops",[]):
		if drop.offer.is_empty(): return
	for ally in s.players.values():
		if not ally.get("rogue_selection",{}).is_empty(): return
	s.raid.phase="rogue_exit"
	s.raid.offers=[]
	s.raid.revision+=1

func advance(s, first_room: String = "combat") -> void:
	if int(s.raid.area)==AREAS_PER_FLOOR:
		if int(s.raid.floor)==5:
			for p in s.players.values(): p.status="extracted"
			settle(s)
			return
		s.raid.floor+=1
		s.raid.area=1
		for p in s.players.values(): Build.floor_enter(p)
		new_floor(s)
		s.raid.route[0]=first_room
	else: s.raid.area+=1
	enter(s)

func settle(s) -> void:
	if s.raid.ended: return
	s.raid.ended=true
	for id in s.players:
		var p: Dictionary=s.players[id]
		var won: bool=p.status=="extracted"
		var coins: int=int(s.raid.cleared)*12+(250 if won else 0)
		s.results[id]={"name":p.name,"escaped":won,"loot":0,"shared":coins+int(p.get("build_souvenirs",0))*2,"kills":p.kills,"coins":coins+int(p.get("build_souvenirs",0))*2,"xp":35+int(s.raid.cleared)*15,"equipment_loot":[],"hidden":false,"worn":s.worn_names(p),"roguelike":true,"cleared":s.raid.cleared,"floor":s.raid.floor}
	s.running=false
	s.finished.emit()
	if s.online: s.receive_results.rpc(s.results,s.players)

func rescue(s, p: Dictionary, held: bool, dt: float) -> bool:
	if not held: p.channel=0.0; p.target=""; return false
	for ally in s.players.values():
		if ally.status=="down" and not ally.get("rogue_rescued_room",false) and ally.p.distance_to(p.p)<=75:
			var key := "revive:%s" % ally.id
			if p.target!=key: p.channel=0.0; p.target=key
			var seconds: float=2.5*(1-Build.r(p,92,[.08,.12,.16]))
			p["channel_total"]=seconds
			p.channel+=dt
			if p.channel>=seconds:
				ally.status="active"; ally.hp=ally.max_hp*.25; ally.invuln=1.5; ally.rogue_rescued_room=true
				p.channel=0.0; p.target=""
			return true
	return false
