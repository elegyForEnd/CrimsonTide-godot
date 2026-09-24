extends RefCounted
const Tactics = preload("res://scripts/boss_tactics.gd")
const Presentation = preload("res://scripts/boss_presentation.gd")

const NAMES := ["赤月葬钟主教", "荆棘誓约猎王", "血潮女王 · 永夜月冠"]
const COLORS := [Color("ba9aee"), Color("ea879d"), Color("f4cb83")]
const HEALTH := [1650.0,3100.0,5500.0]
const BASE_DAMAGE := [34.0,42.0,51.0]
const PARTY_HEALTH_BONUS := 0.80
const MAP_WEAK := ["mirror","earth"]
const MAP_STRONG := ["ash","bird","dragon"]
const REWARDS := [150,300,650]

# --- the hidden encounter ----------------------------------------------------
# Reached only by lighting all three sunrise bells and carrying the banished
# knight's amulet into the queen's arena. It replaces the ordinary ending with a
# fourth fight and a different report, and it is what recruits 墓煜.
const HIDDEN_NAME := "冥火尸王 · 墓玥"
const HIDDEN_HEALTH := 9200.0
const HIDDEN_REWARD := 1200
# The theme key every presentation, audio and VFX table indexes this encounter
# by. It sits after the three shipped raid bosses.
const HIDDEN_KIND := 4

# The daily dawn boss. Days one and two draw from the first two entries, so the
# roster is exactly the size of the two exploring days; the queen (kind 2) is the
# fixed final boss. No dawn boss may repeat across the run.
const DAWN_KINDS := [0,1]

func reset(s) -> void:
	s.raid={"day":1,"phase":"explore","time":0.0,"center":Ruins.CENTER,"kind":0,"hazards":[],"choices":{},"kills":0,"final_spawned":false,"wild_seals":{},"map_boss_defeats":{},"abyss_spawned":false,
		"hidden_spawned":false,"hidden_slain":false,"ended":false,"sealed_bells":{},"boss_kinds":{}}
	prepare_day(s,1)

func prepare_day(s, day: int) -> void:
	if day!=2:
		for i in range(s.enemies.size()-1,-1,-1):
			if s.enemies[i].get("mini_boss",false): s.enemies.remove_at(i)
	s.raid.day=day
	s.raid.time=0.0
	s.raid.phase="explore"
	s.raid.kind=roll_dawn_kind(s,day)
	s.raid.center=arena(s)
	s.raid.hazards=[]
	s.raid.choices={}
	s.raid.final_spawned=false
	s.bullets.clear()
	s.pending_ultimates.clear()
	for p in s.players.values():
		s.stop_search(p)
		p.pending_strike=false
		p.swing_time=0.0
		p.cast_time=0.0
		p.dodge_time=0.0
		p.channel=0.0
		p.target=""
		if day>1 and p.status in ["active","down"]:
			p.hp=minf(p.max_hp,p.hp+p.max_hp*0.35)
			p.sanity=minf(100,p.sanity+30)
			p.reserve+=48
	if day==1:
		spawn_map_guardians(s)
	if day==3:
		for p in s.players.values():
			if p.status=="active":
				p.p=arena_entry(s,p.id)
				p.invuln=3.0
		spawn_boss(s)

func roll_dawn_kind(s, day: int) -> int:
	# A dawn boss already fought on an earlier day is struck from the pool, so
	# day two can only field the dawn boss day one did not use. Day three is the
	# queen and never competes for a slot.
	if day>=3: return 2
	var used: Dictionary={}
	var history: Dictionary=s.raid.get("boss_kinds",{})
	for taken_day in history:
		if int(taken_day)<day: used[int(history[taken_day])]=true
	var pool: Array=[]
	for kind in DAWN_KINDS:
		if not used.has(kind): pool.append(kind)
	# A run cannot exhaust the roster; fall back to the full pool if it ever did.
	if pool.is_empty(): pool=DAWN_KINDS.duplicate()
	var pick: int=pool[s.rng.randi_range(0,pool.size()-1)]
	history[day]=pick
	s.raid.boss_kinds=history
	return pick

func spawn_map_guardians(s) -> void:
	# One weak encounter and two distinct strong encounters are seeded on day one.
	# Survivors stay in the world on day two with their original combat values.
	var weak: String=MAP_WEAK[s.rng.randi_range(0,MAP_WEAK.size()-1)]
	var strong: Array=MAP_STRONG.duplicate()
	for i in 2:
		var pick: int=s.rng.randi_range(0,strong.size()-1)
		spawn_map_guardian(s,str(strong[pick]))
		strong.remove_at(pick)
	spawn_map_guardian(s,weak)

func spawn_map_guardian(s, kind: String) -> void:
	match kind:
		"mirror": s.mini_bosses.spawn(s,1,0)
		"ash": s.mini_bosses.spawn(s,1,1)
		"earth": s.wild_bosses.spawn_mini(s,1,0)
		"bird": s.wild_bosses.spawn_mini(s,1,1)
		"dragon": s.dragon_boss.spawn(s,1)

func record_map_boss_defeat(s, e: Dictionary) -> void:
	var defeated: Dictionary=s.raid.get("map_boss_defeats",{})
	defeated[str(e.boss_name)]=true
	s.raid.map_boss_defeats=defeated

func arena(s) -> Vector2:
	# Landmark centres lie on the connected road network. Require open dodge space.
	var candidates: Array[Vector2]=[]
	for site in s.ruins.sites:
		var at: Vector2=site.p
		var clear: bool=not s.ruins.blocked(at,36)
		for i in 16:
			var edge := at+Vector2.from_angle(TAU*i/16.0)*185
			if s.ruins.blocked(edge,22) or not s.ruins.clear_line(at,edge): clear=false
		if clear: candidates.append(at)
	if candidates.is_empty(): return Ruins.SPAWN
	var previous: Vector2=s.raid.center
	var alternatives := candidates.filter(func(at: Vector2): return at.distance_to(previous)>700)
	if not alternatives.is_empty(): return alternatives[s.rng.randi_range(0,alternatives.size()-1)]
	return candidates[s.rng.randi_range(0,candidates.size()-1)]

func arena_entry(s, id: int) -> Vector2:
	for i in 32:
		var at: Vector2=s.raid.center+Vector2.from_angle(TAU*(i+id%8)/32.0)*165
		if not s.ruins.blocked(at,20): return at
	return s.raid.center

func tick(s, dt: float) -> void:
	if s.raid.is_empty(): return
	if s.raid.phase=="choice":
		resolve_choices(s)
		return
	if s.raid.phase=="complete": return
	s.raid.time+=dt
	if s.raid.phase=="explore":
		# Close the optional dungeon before fog starts, so it cannot bypass dawn.
		if s.raid.time>=s.SHRINK_START and s.map_id=="city":
			s.travel_city(true)
		if s.raid.time>=s.duration:
			spawn_boss(s)
	update_hazards(s,dt)

func spawn_boss(s, final_form: bool = false) -> void:
	if s.raid.phase=="boss" and not final_form: return
	if final_form:
		s.raid.final_spawned=true
		s.raid.hazards.clear()
	s.raid.phase="boss"
	s.raid.time=s.duration
	s.bullets.clear()
	# No extra spawn pass: the boss must appear at exactly the marked centre.
	var count := 0
	for p in s.players.values():
		if p.status in ["active","down"]: count+=1
	var health: float=(7600.0 if final_form else HEALTH[int(s.raid.day)-1])*(1+PARTY_HEALTH_BONUS*maxi(0,count-1))
	var kind: int=s.raid.kind
	s.enemies.append({"id":s.next_enemy,"p":s.raid.center,"type":[1,3,4][kind],"raid_boss":true,"boss_kind":kind,"boss_name":"无名赤月 · 血潮源核" if final_form else NAMES[kind],"final_form":final_form,"hp":health,"max_hp":health,"cd":2.2,"last":1,"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,"attack_time":0.0,"attack_total":0.0,"attack_released":false,"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0})
	s.next_enemy+=1
	Presentation.send(s,s.enemies.back(),"entrance")

func victory(s) -> void:
	# A run that already reached its hidden ending has settled: the ordinary
	# report must not fire a second time on top of it.
	if s.raid.phase!="boss" or s.raid.get("ended",false): return
	s.raid.kills+=1
	s.raid.hazards=[]
	s.bullets.clear()
	var day: int=s.raid.day
	for p in s.players.values():
		if p.status in ["active","down"]:
			p["boss_reward"]=int(p.get("boss_reward",0))+REWARDS[day-1]
			if p.status=="down":
				p.status="active"
				p.hp=p.max_hp*0.35
			p.invuln=5.0
	var chest: Dictionary=s.loot_container(s.raid.center,Vector2i(8,8),day+2,true)
	chest.merge({"fixed_loot":true,"reward_tier":day+2,"title":("吞月渊蛇 · 深渊遗赠" if s.raid.get("abyss_spawned",false) else "无名赤月 · 终夜遗赠" if s.raid.get("final_spawned",false) else NAMES[int(s.raid.kind)]+" · 黎明遗赠"),"open":true})
	if s.raid.get("abyss_spawned",false):
		s.place_entry(chest,"abyss_shedding")
		s.place_entry(chest,"abyssal_motherheart")
	elif s.raid.get("final_spawned",false): s.place_entry(chest,"bloodmoon_nightwomb")
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),mini(5,day+2)))
	s.place_entry(chest,Catalog.make_equipment("gear",s.rng.randi_range(0,2),day+2))
	s.place_entry(chest,{"kind":"backpack","key":["blue","gold","red"][day-1]})
	for item in ["medicine","medicine","ammo","ammo","relic","relic"]: s.place_entry(chest,item)
	for i in day-1: s.place_entry(chest,"relic")
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
	if day==1:
		prepare_day(s,2)
	else:
		s.raid.phase="choice" if day==2 else "complete"
		# Intermission is safe and leaves time to collect the boss chest.
		s.enemies.clear()
		s.raid.choices={}

# --- the hidden encounter ----------------------------------------------------
# Lighting all three sunrise bells and carrying the banished knight's amulet
# this far replaces the ordinary ending: the queen stays down, a fourth
# encounter rises out of her ashes, and the run only settles when it dies.
func spawn_hidden(s) -> void:
	if s.raid.get("hidden_spawned",false) or s.raid.get("ended",false): return
	s.raid.hidden_spawned=true
	s.raid.hazards.clear()
	s.bullets.clear()
	s.enemies.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	var participants := 0
	for p in s.players.values():
		if p.status in ["active","down"]: participants+=1
	var health: float=HIDDEN_HEALTH*(1.0+0.55*maxi(0,participants-1))
	var at: Vector2=s.raid.center
	s.enemies.append({"id":s.next_enemy,"p":at,"type":4,"raid_boss":true,
		"boss_kind":HIDDEN_KIND,"hidden_final":true,
		"boss_name":HIDDEN_NAME,"hp":health,"max_hp":health,"cd":2.4,"last":1,
		"wander":Vector2.ZERO,"facing":1.0,"motion_phase":0.0,"moving":false,
		"attack_time":0.0,"attack_total":0.0,"attack_released":false,
		"attack_aim":Vector2.RIGHT,"sequence":0,"phase":1,"flash":0.0,"stagger":0.0})
	s.next_enemy+=1
	s.raid.phase="boss"
	s.broadcast_combat({"kind":"message","text":"冥火自王座裂隙涌出 · %s 苏醒" % HIDDEN_NAME})
	Presentation.send(s,s.enemies.back(),"entrance")

func hidden_victory(s) -> void:
	s.raid.hidden_slain=true
	s.raid.ended=true
	s.raid.hazards.clear()
	s.bullets.clear()
	s.soul_reaps.clear()
	s.fire_zones.clear()
	for p in s.players.values():
		if p.status in ["active","down"]:
			p["boss_reward"]=int(p.get("boss_reward",0))+HIDDEN_REWARD
			p["hidden_ending"]=true
			if p.status=="down":
				p.status="active"
				p.hp=p.max_hp*0.35
			p.invuln=6.0
	var chest: Dictionary=s.loot_container(s.raid.center,Vector2i(8,8),5,true)
	chest.merge({"fixed_loot":true,"reward_tier":5,
		"title":"冥火尸王 · 冥府遗赠","open":true},true)
	for item in ["medicine","medicine","ammo","ammo","relic","relic","relic"]: s.place_entry(chest,item)
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),5))
	s.place_entry(chest,Catalog.make_equipment("weapon",Catalog.roll_weapon(s.rng),5))
	s.place_entry(chest,Catalog.make_equipment("gear",s.rng.randi_range(0,2),5))
	s.place_entry(chest,{"kind":"backpack","key":"red"})
	chest.searched=s.container_units(chest)
	s.append_chest(chest)
	s.raid.phase="complete"
	s.enemies.clear()
	s.raid.choices={}
	s.broadcast_combat({"kind":"message","text":"隐藏结局 · 冥火之下，墓煜回应了你的召唤"})

func choose(s, id: int, choice: String) -> void:
	if not s.authority() or s.raid.phase not in ["choice","complete"]: return
	var p: Dictionary=s.players.get(id,{})
	if p.is_empty() or p.status!="active": return
	if choice=="extract":
		p.status="extracted"
		s.cancel_ultimate(id)
	elif choice=="continue" and s.raid.phase=="choice":
		s.raid.choices[id]=true
	elif choice=="wait":
		s.raid.choices.erase(id)

func resolve_choices(s) -> void:
	var remaining := 0
	for p in s.players.values():
		if p.status=="down": return
		if p.status=="active":
			remaining+=1
			if not s.raid.choices.get(p.id,false): return
	if remaining>0: prepare_day(s,3)

func hazard(s, shape: String, at: Vector2, aim: Vector2, radius: float, delay: float, damage: float, inner: float = 0.0) -> void:
	s.raid.hazards.append({"shape":shape,"p":at,"aim":aim,"radius":radius,"inner":inner,"time":delay,"total":delay,"damage":damage,"fired":false,"linger":0.24})

func update_hazards(s, dt: float) -> void:
	for i in range(s.raid.hazards.size()-1,-1,-1):
		var h: Dictionary=s.raid.hazards[i]
		h.time-=dt
		if h.time<=0 and not h.fired:
			h.fired=true
			if h.has("boss_kind"):
				var event: Dictionary=h.duplicate(true)
				event.merge({"kind":"boss-vfx","action":"release","id":h.get("source",0)},true)
				s.broadcast_combat(event)
			else: s.emit_effect("hit",h.p)
			for p in s.players.values():
				if hazard_contains(h,p.p) and s.ruins.clear_line(h.p,p.p): s.hurt(p,h.damage)
		if h.fired and h.has("pulse_interval") and h.time<=-float(h.next_pulse) and h.time>=-float(h.linger):
			h.next_pulse=float(h.next_pulse)+float(h.pulse_interval)
			for p in s.players.values():
				if hazard_contains(h,p.p) and s.ruins.clear_line(h.p,p.p): s.hurt(p,h.damage)
		if h.time < -float(h.linger): s.raid.hazards.remove_at(i)

func hazard_contains(h: Dictionary, at: Vector2) -> bool:
	var v: Vector2=at-h.p
	if h.shape=="line":
		return v.dot(h.aim)>=-22 and v.dot(h.aim)<=h.radius and absf(v.dot(h.aim.orthogonal()))<=44
	if h.shape=="lane": return v.dot(h.aim)>=0 and v.dot(h.aim)<=h.radius and absf(v.dot(h.aim.orthogonal()))<=h.inner
	if h.shape=="gap_ring": return v.length()<=h.radius and v.length()>=h.inner and absf(h.aim.angle_to(v))>float(h.get("gap",0.5))
	if h.shape=="arc": return v.length()<=h.radius and v.length()>=h.inner and absf(h.aim.angle_to(v))<=float(h.get("arc",1.05))
	if h.shape=="cone": return v.length()<=h.radius and absf(h.aim.angle_to(v))<=float(h.get("arc",1.05))
	return v.length()<=h.radius and v.length()>=h.inner

func update_boss(s, e: Dictionary, dt: float) -> void:
	e.flash=maxf(0,float(e.flash)-dt)
	e.attack_time=maxf(0,float(e.attack_time)-dt)
	e.moving=false
	e["stagger"]=maxf(0,float(e.get("stagger",0))-dt)
	e.cd=maxf(0,e.cd-dt)
	Tactics.tick(s,e,dt)
	if e.stagger>0 or Tactics.update_guard(e,dt): return
	var hidden: bool=bool(e.get("hidden_final",false))
	var phase := 1
	if e.hp<=e.max_hp*0.60: phase=2
	if e.hp<=e.max_hp*0.30: phase=3
	if phase!=int(e.get("phase",1)):
		e.phase=phase
		Presentation.send(s,e,"phase")
	e.phase=phase
	var target: Dictionary={}
	var best := INF
	for p in s.players.values():
		if p.status=="active" and p.p.distance_to(e.p)<best:
			target=p
			best=p.p.distance_to(e.p)
	if target.is_empty(): return
	var response: Dictionary=Tactics.response(s,e)
	if not response.is_empty():
		if response.kind=="attack" and Tactics.start_guard(e,response.aim,s): return
		if response.kind!="attack":
			cast_boss(s,e,target,str(response.kind),response.aim,response.point)
			return
	if e.attack_time<=0 and not e.get("reaction",{}).is_empty(): return
	var aim: Vector2=(target.p-e.p).normalized()
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	# Reposition between casts; all telegraphs keep their original origin and aim.
	if e.attack_time<=0 and (int(e.sequence)>0 or best>230):
		var preferred: float=150.0 if e.get("final_form",false) else (205.0 if hidden else [190.0,130.0,165.0][int(e.boss_kind)])
		var side := 1.0 if (int(e.sequence)+int(e.id))%2==0 else -1.0
		var direction := aim.orthogonal()*side
		if best>preferred+30: direction=(aim+direction*0.25).normalized()
		elif best<preferred-45: direction=(-aim+direction*0.6).normalized()
		move_boss(s,e,direction,180.0+18.0*phase,dt)
		aim=(target.p-e.p).normalized()
		best=target.p.distance_to(e.p)
	if e.cd>0 or e.attack_time>0 or not s.ruins.clear_line(e.p,target.p): return
	var seq: int=e.sequence
	var moves: Array=HIDDEN_MOVES if hidden else (["blood_moon","orbit","sunder","nightfall","last_light"] if e.get("final_form",false) else (["bell","marks","quick_bell","slow_bell","cross"] if e.boss_kind==0 else (["spear","cleave","feint","guard","fan","reap"] if e.boss_kind==1 else ["crown","lances","coronation","execution","eclipse"])))
	var move: String=moves[seq%moves.size()]
	if not hidden and e.boss_kind==0 and move in ["bell","quick_bell"] and best>340: move="marks"
	if not hidden and e.boss_kind==1 and move in ["cleave","feint","reap"] and best>260: move="spear"
	e.sequence+=1
	if move=="guard":
		if Tactics.start_guard(e,aim,s): return
		move="feint"
	cast_boss(s,e,target,move,aim,target.p)

# The hidden encounter's rotation. Every move answers a different mistake: a
# ring punishes standing still, a lane punishes circling at one radius, and the
# grave patches punish committing to a corner of the arena.
const HIDDEN_MOVES := ["grave_ring","soul_lance","tomb_patch","cinder_fan","bone_cage","rift_walk","necro_pyre","marrow","hidden_cross","pyre_finale"]

func cast_boss(s, e: Dictionary, _target: Dictionary, move: String, aim: Vector2, point: Vector2) -> void:
	var phase := int(e.get("phase",1))
	var hidden: bool=bool(e.get("hidden_final",false))
	e.attack_aim=aim
	if absf(aim.x)>0.05: e.facing=signf(aim.x)
	var damage: float=BASE_DAMAGE[int(s.raid.day)-1]*(1.0+0.12*(phase-1))
	var delay: float=[1.05,0.85,0.75][phase-1]
	var first: int=s.raid.hazards.size()
	e["move_id"]=move
	if hidden:
		damage=(27+int(s.raid.day)*6)*(1.0+0.13*(phase-1))
		cast_hidden(s,e,move,aim,point,damage,delay,phase)
	else:
			match move:
				"dodge":
					e.move_name="截断退路 · 翻滚落点已锁定"
					if e.boss_kind==1: hazard(s,"line",e.p,aim,520,0.90,damage)
					else: hazard(s,"circle",point,aim,90,0.90,damage)
				"reload":
					e.move_name="破绽追击 · 装填时注意闪避"
					if e.boss_kind==0: hazard(s,"circle",point,aim,80,0.65,damage*0.85)
					else: hazard(s,"line",e.p,aim,560,0.65,damage*0.85)
				"counter":
					e.move_name="招架反击 · 快刺接慢扫"
					hazard(s,"line",e.p,aim,390,0.55,damage*0.75)
					hazard(s,"cone",e.p,aim,245,1.45,damage*1.10)
				"bell":
					e["move_name"]="葬钟回响 · 离开紫环"
					hazard(s,"ring",e.p,aim,295,delay,damage,95)
					if s.raid.day==2: hazard(s,"ring",e.p,aim,440,delay+0.85,damage,295)
				"marks":
					e["move_name"]="月蚀祷告 · 离开脚下印记"
					for p in s.players.values():
						if p.status=="active": hazard(s,"circle",p.p,aim,85,delay,damage)
					if phase>=2: hazard(s,"circle",e.p,aim,110,delay+0.6,damage)
				"quick_bell":
					e.move_name="急鸣丧钟 · 快震后退"
					hazard(s,"circle",e.p,aim,180,0.55,damage*0.75)
					hazard(s,"ring",e.p,aim,340,1.35,damage,180)
				"slow_bell":
					e.move_name="停钟再鸣 · 慢拍，先内后外"
					hazard(s,"ring",e.p,aim,380,1.55,damage*1.15,115)
					hazard(s,"circle",e.p,aim,130,2.20,damage)
				"cross":
					e.move_name="十字葬仪 · 穿过交错钟线"
					hazard(s,"line",point-aim*260,aim,520,0.65,damage*0.8)
					hazard(s,"line",point-aim.orthogonal()*260,aim.orthogonal(),520,1.55,damage)
				"spear":
					e["move_name"]="猎王血矛 · 横向闪避"
					hazard(s,"line",e.p,aim,520,delay,damage+5)
					if s.raid.day==2:
						for angle in [-0.32,0.32]: hazard(s,"line",e.p,aim.rotated(angle),520,delay+0.55,damage)
				"cleave":
					e["move_name"]="荆棘断誓 · 绕到背后"
					hazard(s,"cone",e.p,aim,240,delay,damage)
					if phase>=2: hazard(s,"cone",e.p,-aim,240,delay+0.75,damage)
				"feint":
					e.move_name="猎誓虚晃 · 快刺接蓄力斩"
					hazard(s,"line",e.p,aim,330,0.55,damage*0.65)
					hazard(s,"cone",e.p,aim,255,1.65,damage*1.20)
				"fan":
					e.move_name="三棘追猎 · 快矛接侧翼慢矛"
					hazard(s,"line",e.p,aim,520,0.60,damage*0.8)
					for angle in [-0.45,0.45]: hazard(s,"line",e.p,aim.rotated(angle),520,1.50,damage)
				"reap":
					e.move_name="回身收割 · 前快后慢"
					hazard(s,"cone",e.p,aim,220,0.60,damage*0.8)
					hazard(s,"cone",e.p,-aim,260,1.60,damage*1.1)
				"blood_moon":
					e.move_name="血月初升 · 先入内环再后撤"
					hazard(s,"ring",e.p,aim,440,1.05,damage,140)
					hazard(s,"circle",e.p,aim,150,1.80,damage*1.10)
				"orbit":
					e.move_name="碎冠星轨 · 穿过矛隙"
					for i in 8+phase*2:
						hazard(s,"line",e.p,aim.rotated(TAU*i/(8+phase*2)),580,0.85,damage*0.85)
				"sunder":
					e.move_name="月刃断章 · 快慢交错"
					hazard(s,"cone",e.p,aim,270,0.62,damage*0.75)
					hazard(s,"cone",e.p,-aim,310,1.65,damage*1.20)
				"nightfall":
					e.move_name="终夜坠落 · 连续走位"
					for p in s.players.values():
						if p.status=="active":
							for i in phase:
								hazard(s,"circle",p.p+Vector2.from_angle(TAU*i/3.0)*i*115,aim,110,0.70+i*0.55,damage)
				"last_light":
					e.move_name="血潮源核 · 破晓前的最后一击"
					hazard(s,"ring",e.p,aim,500,1.45,damage*1.05,180)
					hazard(s,"line",e.p,aim,580,2.05,damage*1.20)
					hazard(s,"circle",point,aim,115,2.65,damage)
				"crown":
					e["move_name"]="月冠审判 · 先入内环再远离"
					hazard(s,"ring",e.p,aim,450,delay,damage,130)
					hazard(s,"circle",e.p,aim,155,delay+0.8,damage+6)
				"lances":
					e["move_name"]="血潮王令 · 穿过王矛间隙"
					for i in 6+phase*2:
						hazard(s,"line",e.p,Vector2.from_angle(aim.angle()+TAU*i/(6+phase*2)),560,delay,damage)
				"coronation":
					e["move_name"]="永夜加冕 · 持续移动"
					for p in s.players.values():
						if p.status!="active": continue
						for i in phase:
							var at: Vector2=p.p+Vector2.from_angle(TAU*i/3)*float(i)*95
							hazard(s,"circle",at,aim,95,delay+i*0.55,damage)
				"execution":
					e.move_name="女王处刑 · 两快一慢"
					hazard(s,"cone",e.p,aim,220,0.55,damage*0.65)
					hazard(s,"cone",e.p,-aim,220,1.00,damage*0.65)
					hazard(s,"ring",e.p,aim,380,1.95,damage*1.15,110)
				"eclipse":
					e.move_name="蚀月错拍 · 慢环接快爆"
					hazard(s,"ring",e.p,aim,450,1.50,damage,145)
					hazard(s,"circle",point,aim,95,1.95,damage)
			if e.boss_kind==2 and phase==3 and not hidden: hazard(s,"ring",s.raid.center,aim,620,delay+1.1,damage,460)
	var marks: Array=[]
	for i in range(first,s.raid.hazards.size()):
		var h: Dictionary=s.raid.hazards[i]
		h["source"]=e.id
		h["boss_kind"]=int(e.boss_kind)
		h["move"]=move
		h["part"]=i-first
		h["phase"]=phase
		h["final_form"]=e.get("final_form",false)
		h["hidden_final"]=bool(hidden)
		h["perimeter"]=not hidden and int(e.boss_kind)==2 and phase==3 and i==s.raid.hazards.size()-1
		h["tempo"]="快" if h.total<=0.70 else ("慢" if h.total>=1.4 else "")
		if not marks.has(h.total): marks.append(h.total)
	marks.sort()
	if marks.is_empty(): return
	e["attack_marks"]=marks
	e["windup"]=marks[0]
	e.attack_total=float(marks.back())+0.35
	e.attack_time=e.attack_total
	e.cd=maxf(e.attack_total+0.45,2.8 if phase==1 else 2.35)
	Presentation.send(s,e,"charge",{"total":marks[0]})

# The hidden encounter's rotation. Each move punishes a different mistake: rings
# punish standing still, lanes punish circling at one radius, and the grave
# patches punish committing to one corner of the arena.
func cast_hidden(s, e: Dictionary, move: String, aim: Vector2, point: Vector2, damage: float, delay: float, phase: int) -> void:
	match move:
		"grave_ring":
			e["move_name"]="墓环迸裂 · 先内后外"
			hazard(s,"ring",e.p,aim,400,delay,damage,130)
			if phase>=2: hazard(s,"ring",e.p,aim,560,delay+0.8,damage*0.9,400)
		"soul_lance":
			e["move_name"]="冥魂长枪 · 横向闪避"
			hazard(s,"line",e.p,aim,560,delay,damage*1.1)
			if phase>=2:
				for angle in [-0.34,0.34]: hazard(s,"line",e.p,aim.rotated(angle),560,delay+0.5,damage*0.8)
		"tomb_patch":
			e["move_name"]="荒冢标记 · 离开脚下印记"
			for p in s.players.values():
				if p.status=="active": hazard(s,"circle",p.p,aim,100,delay,damage)
			if phase>=2: hazard(s,"circle",e.p,aim,135,delay+0.6,damage*0.9)
		"cinder_fan":
			e["move_name"]="烬火扇面 · 穿过扇形间隙"
			for i in 4+phase:
				hazard(s,"line",e.p,aim.rotated((i-(3+phase)*0.5)*0.24),500,0.7+i*0.12,damage*0.8)
		"bone_cage":
			e["move_name"]="枯骨囚笼 · 收束的环"
			hazard(s,"ring",e.p,aim,470,1.0,damage*0.85,300)
			hazard(s,"circle",e.p,aim,190,1.9,damage)
			if phase>=2: hazard(s,"ring",e.p,aim,620,2.6,damage,470)
		"rift_walk":
			e["move_name"]="裂隙潜行 · 落点已锁定"
			var landing: Vector2=point-aim*120
			hazard(s,"circle",landing,aim,125,0.85,damage*1.05)
			hazard(s,"lane",landing,aim.orthogonal(),520,1.5,damage*0.8,64)
			hazard(s,"lane",landing,-aim.orthogonal(),520,1.5,damage*0.8,64)
		"necro_pyre":
			e["move_name"]="死灵火葬 · 沿长墙跑向侧面"
			hazard(s,"lane",e.p-aim*260,aim,900,delay,damage*1.2,120)
			if phase>=2: hazard(s,"circle",point,aim,120,delay+0.7,damage)
		"marrow":
			e["move_name"]="抽髓 · 快慢交错"
			hazard(s,"cone",e.p,aim,270,0.6,damage*0.75)
			hazard(s,"cone",e.p,-aim,320,1.6,damage*1.2)
		"hidden_cross":
			e["move_name"]="冥火十字 · 穿过交错火线"
			hazard(s,"line",point-aim*280,aim,560,0.65,damage*0.85)
			hazard(s,"line",point-aim.orthogonal()*280,aim.orthogonal(),560,1.55,damage)
		"pyre_finale":
			e["move_name"]="焚尽冥府 · 破晓前最后一击"
			hazard(s,"ring",e.p,aim,540,1.35,damage*1.05,180)
			hazard(s,"line",e.p,aim,620,1.95,damage*1.15)
			hazard(s,"circle",point,aim,125,2.55,damage)
			if phase>=3: hazard(s,"ring",s.raid.center,aim,660,3.2,damage*0.9,520)

func move_boss(s, e: Dictionary, direction: Vector2, speed: float, dt: float) -> void:
	var before: Vector2=e.p
	var remaining := dt
	while remaining>0:
		var step := minf(remaining,0.025)
		var next: Vector2=s.ruins.move(e.p,direction*speed*step,31)
		# Leave a dodge corridor at the edge of the fixed arena.
		if next.distance_to(s.raid.center)>390 or next.distance_to(e.p)<speed*step*0.2:
			for side in [1.0,-1.0]:
				var alternate: Vector2=s.ruins.move(e.p,direction.orthogonal()*side*speed*step,31)
				if alternate.distance_to(s.raid.center)<=390 and alternate.distance_to(e.p)>=speed*step*0.2:
					next=alternate
					break
		if next.distance_to(s.raid.center)<=390: e.p=next
		remaining-=step
	var travelled: float=e.p.distance_to(before)
	e.moving=travelled>0.01
	e.motion_phase+=travelled/12.0
