extends RefCounted
const Choreography = preload("res://scripts/boss_choreography.gd")
const Variants = preload("res://scripts/rogue_variants.gd")
const Art = preload("res://scripts/boss_effect_art.gd")

# Phase one keeps the original five-move rotation byte for byte; phase two opens
# the two authored finishers (indices 5 and 6) that only exist past half health.
const PHASE1_CURSOR := [0,1,2,3,4]
const PHASE2_CURSOR := [5,2,6,0,3,1,4]
const PHASE1_MOVES := 5
const PHASE2_MOVES := 7
# 深渊变数对敌人属性的影响有硬上下限，避免任何一条变数把战斗推离可玩区间。
const ENEMY_HP_SCALE_BOUNDS := Vector2(0.5,3.0)
const ENEMY_TEMPO_BOUNDS := Vector2(0.5,2.0)
const BULLET_SPEED_BOUNDS := Vector2(0.5,2.0)
const BULLET_VISUAL_BOUNDS := Vector2(1.0,3.0)
# 守层者池（R14）：每层从 Art.ROGUE 的 8 个身份里确定性地抽 5 个互不重复。
const POOL_FLOORS := 5
# 三个新守层者各自的编排键：复用该身份既有的四招编排骨架，另加两招二阶段终结技。
const CHOREO_KEYS := {5:"rq_bell",6:"rq_earth",7:"rq_abyss"}

# All damage shapes share their geometry with RogueField's telegraphs.
const NAMES := ["幽蕈古王", "熔炉暴君", "星镜女皇", "雷翼舰长", "黑曜剑圣", "暮钟司祭", "岩窟冢主", "湮潮之主"]
const MOVES := [
	[{"name":"古根横扫","shape":"cone","reach":155.0,"windup":0.8},
	 {"name":"幽光孢雨","shape":"radial","windup":1.0},
	 {"name":"根须牢笼","shape":"roots","windup":1.2},
	 {"name":"林王践踏","shape":"dash","windup":0.9},
	 {"name":"菌林复苏","shape":"summon","windup":1.4},
	 {"name":"孢云窒息","shape":"circle","reach":120.0,"windup":1.3},
	 {"name":"菌林献祭","shape":"summon","windup":1.5}],
	[{"name":"熔锤震地","shape":"circle","reach":120.0,"windup":1.0},
	 {"name":"炽铁散射","shape":"fan","windup":0.85},
	 {"name":"地火喷涌","shape":"eruption","windup":1.2},
	 {"name":"锁链冲撞","shape":"dash","windup":0.9},
	 {"name":"熔炉火环","shape":"ring","windup":1.35},
	 {"name":"锁链绞轮","shape":"line","reach":470.0,"windup":1.1},
	 {"name":"熔心过载","shape":"circle","reach":380.0,"windup":1.6}],
	[{"name":"星棱贯穿","shape":"line","windup":0.95},
	 {"name":"三镜折光","shape":"mirrors","windup":1.2},
	 {"name":"陨星坠落","shape":"meteors","windup":1.1},
	 {"name":"星轨轮舞","shape":"orbit","windup":1.0},
	 {"name":"幻镜跃迁","shape":"blink","windup":1.3},
	 {"name":"万镜回廊","shape":"mirrors","windup":1.2},
	 {"name":"星轨崩塌","shape":"orbit","windup":1.5}],
	[{"name":"雷翼斩","shape":"cone","reach":180.0,"windup":0.75},
	 {"name":"折返雷链","shape":"lightning","windup":1.0},
	 {"name":"游走飓风","shape":"cyclone","windup":1.25},
	 {"name":"疾风俯冲","shape":"dash","windup":0.8},
	 {"name":"天穹雷罚","shape":"storm","windup":1.1},
	 {"name":"折返风暴","shape":"lightning","windup":1.0},
	 {"name":"天穹断翼","shape":"fan","windup":1.4}],
	[{"name":"王庭三连斩","shape":"triple","reach":170.0,"windup":0.9},
	 {"name":"暗影拔刀","shape":"dash","windup":0.7},
	 {"name":"黑剑落雨","shape":"swords","windup":1.2},
	 {"name":"禁咒轮印","shape":"seal","windup":1.3},
	 {"name":"终焉十字","shape":"cross","windup":1.5},
	 {"name":"千刃返照","shape":"dash","reach":320.0,"windup":0.8},
	 {"name":"终末绝影","shape":"seal","windup":1.5}],
	# —— R14 扩容：三个新守层者（身份取自 Art.ROGUE[5..7]，零新美术）——
	# 前四招沿用该身份既有的编排骨架（见 boss_choreography.TIMELINE_BASE），后三招为本层新增。
	[{"name":"钟摆葬列","shape":"ring","windup":1.0},
	 {"name":"止声错拍","shape":"lane","windup":1.15},
	 {"name":"敲钟者","shape":"circle","windup":1.25},
	 {"name":"九刻终祷","shape":"radial","windup":1.45},
	 {"name":"裂钟回响","shape":"ring","reach":185.0,"windup":1.2},
	 {"name":"丧钟连祷","shape":"line","reach":430.0,"windup":1.1},
	 {"name":"终末叩响","shape":"radial","windup":1.6}],
	[{"name":"钻地折返","shape":"dash","windup":0.95},
	 {"name":"断层立壁","shape":"line","reach":420.0,"windup":1.15},
	 {"name":"穹顶坠岩","shape":"circle","reach":150.0,"windup":1.3},
	 {"name":"蜕甲震穴","shape":"eruption","windup":1.2},
	 {"name":"碎岩倾轧","shape":"eruption","windup":1.25},
	 {"name":"地脉封锁","shape":"ring","reach":200.0,"windup":1.35},
	 {"name":"终末崩落","shape":"circle","reach":390.0,"windup":1.7}],
	[{"name":"潮汐吸引","shape":"circle","reach":210.0,"windup":1.1},
	 {"name":"错齿吞噬","shape":"cone","reach":200.0,"windup":0.95},
	 {"name":"蛇流换岸","shape":"line","reach":430.0,"windup":1.2},
	 {"name":"噬月深潜","shape":"dash","windup":0.85},
	 {"name":"逆流绞杀","shape":"ring","reach":195.0,"windup":1.15},
	 {"name":"万潮归寂","shape":"radial","windup":1.35},
	 {"name":"终末深潜","shape":"circle","reach":400.0,"windup":1.65}]]

var effects: Array=[]
var summons: Array=[]
var minion_start_gap := 0.0
var minions = preload("res://scripts/rogue_minions.gd").new()
var missiles: Array=[]

func reset() -> void:
	effects.clear()
	summons.clear()
	minion_start_gap=0.0
	missiles.clear()

func setup_boss(e: Dictionary, floor_index: int, s = null) -> void:
	# 身份由 (seed_value, floor) 纯函数派生：房主与客户端各自算出同一个守层者，
	# 不需要任何新的 raid 键，也不消耗 s.rng。拿不到种子时回落到扩容前的“楼层即身份”。
	var art_index := clampi(floor_index,0,Art.ROGUE.size()-1)
	var run_seed := pool_seed(s,e)
	if run_seed != 0: art_index = boss_art_for(run_seed,floor_index)
	e.merge({"rogue_guardian":true,"rogue_skin":floor_index,"boss_art":art_index,
		"art_key":Art.rogue_key(art_index),"boss_name":NAMES[art_index],
		"hp":950.0+floor_index*350.0,"max_hp":950.0+floor_index*350.0,"cd":1.8,
		"rogue_radius":30.0,"move_cursor":0,"boss_skill":-1,"boss_elapsed":0.0,
		"boss_windup":0.0,"boss_released":false,"boss_enraged":false,"phase":1,"attack_time":0.0},true)
	if CHOREO_KEYS.has(art_index): e["choreo_key"]=CHOREO_KEYS[art_index]
	# 变数属性钩子（R8 待接线项 c）：调用方传 s 时立刻生效；未传则由 update() 首次补应用。
	apply_variant_stats(s,e)

# —— 守层者池（R14）：确定性、无副作用、不写 raid、不动 s.rng ——
# 只用整数混洗：同一 (seed_value, floor) 在房主与客户端得到逐位相同的身份。
static func mix_seed(value: int, salt: int) -> int:
	var h := (int(value) ^ (salt * 0x9E3779B1)) & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0x7FFFFFFF
	return (h ^ (h >> 15)) & 0x7FFFFFFF

# 本局的身份池：8 取 5，互不重复。与楼层无关，所以同一局内各层不会撞同一个守层者。
static func boss_pool(seed_value: int) -> Array:
	var order: Array=[]
	for i in Art.ROGUE.size(): order.append(i)
	var state := mix_seed(seed_value,0x5EED)
	for i in range(order.size()-1,0,-1):
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var j: int = state % (i + 1)
		var swap = order[i]
		order[i]=order[j]
		order[j]=swap
	return order.slice(0,POOL_FLOORS)

# 第 floor 层的守层者身份索引（0..7）。
static func boss_art_for(seed_value: int, floor_index: int) -> int:
	var pool: Array=boss_pool(seed_value)
	return int(pool[posmod(floor_index,pool.size())])

# 种子只从既有字段取：会话的 seed_value（随 begin RPC 同步）或敌人字典里的 run_seed。
func pool_seed(s, e: Dictionary) -> int:
	if e.has("run_seed"): return int(e.run_seed)
	if s == null: return 0
	if s is Dictionary: return int(s.get("seed_value",0))
	if s is Object and "seed_value" in s: return int(s.get("seed_value"))
	return 0

# 7 招表按“身份”而不是“楼层”取：扩容后楼层与身份不再一一对应。
func moves_of(e: Dictionary) -> Array:
	var index := int(e.get("rogue_skin",0))
	if e.get("rogue_guardian",false): index = int(e.get("boss_art",index))
	return MOVES[clampi(index,0,MOVES.size()-1)]

func setup_minion(e: Dictionary, floor_index: int, variant: int, elite: bool, rng: RandomNumberGenerator, s = null) -> void:
	e.merge({"rogue_minion":true,"rogue_skin":floor_index,"rogue_variant":variant,
		"rogue_name":minions.NAMES[floor_index][variant],"rogue_radius":13.0,
		"hp":(42.0+floor_index*12.0)*(1.5 if elite else 1.0),
		"cd":rng.randf_range(.35,1.5),"attack_tempo":rng.randf_range(.85,1.15),
		"in_attack_range":false,"minion_age":0.0,"stagger":0.0},true)
	e.max_hp=e.hp
	e.merge({"role":minions.ROLES[floor_index][variant],"minion_skill":0,"minion_windup":.55,
		"skill_cds":[0.0,0.0],"shield_time":0.0,"rogue_shield":0.0,"guard_time":0.0,
		"buff_time":0.0,"buff_kind":"","support_target":-1},true)
	apply_variant_stats(s,e)

# —— 深渊变数：敌人侧数值钩子（R8 待接线项 c/d）——
# 只影响数值与表现层。命中判定几何（hit_radius）与伤害公式绝不参与。
func variant_mods(s) -> Dictionary:
	if s == null: return {}
	var raid = s.get("raid")
	if not (raid is Dictionary): return {}
	var variant_id := str(raid.get("variant",""))
	if variant_id.is_empty(): return {}
	return Variants.modifiers_of([variant_id])

func enemy_hp_scale(s) -> float:
	return clampf(1.0+float(variant_mods(s).get("enemy_hp",0.0)),ENEMY_HP_SCALE_BOUNDS.x,ENEMY_HP_SCALE_BOUNDS.y)

func enemy_tempo(s) -> float:
	return clampf(1.0+float(variant_mods(s).get("enemy_speed",0.0)),ENEMY_TEMPO_BOUNDS.x,ENEMY_TEMPO_BOUNDS.y)

func bullet_speed_scale(s) -> float:
	return clampf(1.0+float(variant_mods(s).get("bullet_speed",0.0)),BULLET_SPEED_BOUNDS.x,BULLET_SPEED_BOUNDS.y)

func bullet_visual_scale(s) -> float:
	return clampf(1.0+float(variant_mods(s).get("bullet_size",0.0)),BULLET_VISUAL_BOUNDS.x,BULLET_VISUAL_BOUNDS.y)

# 幂等：无变数时只留一个已应用标记，不额外膨胀快照里的敌人字典。
# s == null（调用方没传会话）时**不**记录标记，留给首次 update() 补应用。
func apply_variant_stats(s, e: Dictionary) -> void:
	if s == null: return
	if e.get("variant_stats_applied",false): return
	e["variant_stats_applied"]=true
	var hp_scale := enemy_hp_scale(s)
	if hp_scale!=1.0:
		e.hp=maxf(1.0,float(e.hp)*hp_scale)
		e.max_hp=maxf(1.0,float(e.max_hp)*hp_scale)
		e["variant_hp_scale"]=hp_scale
	var tempo := enemy_tempo(s)
	if tempo!=1.0 and e.has("cd"): e.cd=float(e.cd)/tempo
	var speed := bullet_speed_scale(s)
	if speed!=1.0: e["boss_bullet_speed"]=speed
	var visual := bullet_visual_scale(s)
	if visual!=1.0: e["boss_bullet_visual"]=visual

func bullet_speed_of(e: Dictionary) -> float:
	return clampf(float(e.get("boss_bullet_speed",1.0)),BULLET_SPEED_BOUNDS.x,BULLET_SPEED_BOUNDS.y)

# 仅表现层：G 集合按这个倍率放大敌人弹幕绘制，绝不改命中判定。
func bullet_visual_of(e: Dictionary) -> float:
	return clampf(float(e.get("boss_bullet_visual",1.0)),BULLET_VISUAL_BOUNDS.x,BULLET_VISUAL_BOUNDS.y)

# —— 守层者二阶段（R6）——
func boss_phase(e: Dictionary) -> int:
	return 2 if e.get("boss_enraged",false) or int(e.get("phase",1))>=2 else 1

# 第一阶段保持原来的 0..4 轮换；二阶段换成含两招专属终结技的 7 招表。
func skill_for_cursor(e: Dictionary, cursor: int) -> int:
	var order: Array = PHASE2_CURSOR if boss_phase(e)>=2 else PHASE1_CURSOR
	var size := int(moves_of(e).size())
	return posmod(int(order[posmod(cursor,order.size())]),size)

func phase2_only_skills() -> Array:
	return [PHASE1_MOVES,PHASE1_MOVES+1]

func nearest(s, e: Dictionary) -> Dictionary:
	var target: Dictionary={}
	var best := INF
	for p in s.players.values():
		if p.status=="active" and e.p.distance_squared_to(p.p)<best:
			target=p
			best=e.p.distance_squared_to(p.p)
	return target

func move_towards(s, e: Dictionary, direction: Vector2, distance: float) -> void:
	var before: Vector2=e.p
	var frost := 0
	for owner in e.get("build_status",{}): frost=maxi(frost,int(e.build_status[owner].get("frost",{}).get("stacks",0)))
	distance*=1.0-minf(.08 if e.get("rogue_guardian",false) else .15 if e.get("build_elite",false) else .25,frost*.06)
	e.p=s.ruins.move(e.p,direction*distance,float(e.rogue_radius))
	# An obstacle can be walked around; never project actors away from a border.
	if e.p.distance_to(before)<0.01:
		for side in [1.0,-1.0]:
			var trial: Vector2=s.ruins.move(e.p,direction.rotated(side*0.85)*distance,float(e.rogue_radius))
			if trial.distance_to(e.p)>0.01: e.p=trial; break
	e.moving=e.p.distance_to(before)>0.01
	e.motion_phase+=e.p.distance_to(before)/12.0

func update(s, e: Dictionary, dt: float) -> void:
	apply_variant_stats(s,e)
	e.flash=maxf(0,float(e.get("flash",0))-dt)
	e.moving=false
	if e.get("rogue_guardian",false): update_boss(s,e,dt)
	else: update_minion(s,e,dt)

func update_minion(s, e: Dictionary, dt: float) -> void:
	minions.update(s,self,e,dt)

func minion_event(s, e: Dictionary, action: String) -> void:
	s.broadcast_combat({"kind":"rogue-minion","action":action,"id":e.id,"p":e.p,
		"floor":e.rogue_skin,"variant":e.rogue_variant,"aim":e.get("attack_aim",Vector2.RIGHT),
		"target":e.get("attack_point",e.p),"duration":e.get("minion_windup",.55),
		"target_id":e.get("support_target",-1),
		"skill":e.get("minion_skill",0),"move":visual_move(e)})

func visual_move(e: Dictionary) -> String:
	if e.get("rogue_minion",false): return str(minions.skill(e,int(e.get("minion_skill",0))).kind)
	var moves: Array=moves_of(e)
	return str(moves[clampi(int(e.get("boss_skill",0)),0,moves.size()-1)].shape)

func missile(e: Dictionary, kind: String, from: Vector2, to: Vector2, delay: float, duration: float, damage: float) -> void:
	missiles.append({"source":e.id,"floor":e.rogue_skin,"fx_move":visual_move(e),"kind":kind,"start":from,"end":to,"p":from,
		"delay":delay,"duration":duration,"age":0.0,"damage":damage,"hit":{},"visual_height":0.0})

func update_missiles(s, dt: float) -> void:
	for i in range(missiles.size()-1,-1,-1):
		var m: Dictionary=missiles[i]
		var source: Dictionary={}
		for e in s.enemies:
			if e.id==m.source and e.hp>0: source=e; break
		if source.is_empty(): missiles.remove_at(i); continue
		var active_dt: float=maxf(0,dt-maxf(0,m.delay))
		m.delay-=dt
		if m.delay>0: continue
		m.age+=active_dt
		var t: float=clampf(m.age/m.duration,0,1)
		var previous: Vector2=m.p
		if m.kind=="homing":
			var target: Dictionary=nearest(s,source)
			if not target.is_empty() and t<.6: m.end=target.p
			m.p=s.ruins.move(previous,(m.end-previous).normalized()*120*active_dt,8)
		else:
			var fraction: float=sin(t*PI) if m.kind=="boomerang" else t
			m.p=m.start.lerp(m.end,fraction)
		var intended: Vector2=m.p
		if m.kind not in ["throw","mist"]: m.p=s.ruins.move(previous,m.p-previous,8)
		m.visual_height=sin(t*PI)*100 if m.kind in ["throw","mist"] else 0.0
		var blocked: bool=m.p.distance_to(intended)>.5 if m.kind not in ["throw","mist"] else false
		if m.kind not in ["throw","mist"]:
			for p in s.players.values():
				if p.status!="active" or m.hit.has(p.id): continue
				if Geometry2D.get_closest_point_to_segment(p.p,previous,m.p).distance_to(p.p)<23:
					s.hurt(p,m.damage,source,"normal"); m.hit[p.id]=true
		if t>=1 or blocked:
			if m.kind in ["throw","mist"]:
				zone(source,"circle",m.end,48,0,.18 if m.kind=="throw" else 3.0,m.damage if m.kind=="throw" else 0.0)
				if m.kind=="mist": effects.back()["slow"]=.25
			s.broadcast_combat({"kind":"rogue-projectile-impact","p":previous if blocked else m.p,"floor":m.floor})
			missiles.remove_at(i)

func begin_skill(s, e: Dictionary, skill: int, target: Dictionary) -> void:
	# 弹幕倍率在起手时定一次，随后的编排弹与瞬发弹复用同一份，逐帧不再取。
	var speed_scale := bullet_speed_scale(s)
	if speed_scale!=1.0: e["boss_bullet_speed"]=speed_scale
	else: e.erase("boss_bullet_speed")
	var visual_scale := bullet_visual_scale(s)
	if visual_scale!=1.0: e["boss_bullet_visual"]=visual_scale
	else: e.erase("boss_bullet_visual")
	if e.get("rogue_guardian",false):
		var pool: Array=Choreography.names(e)
		e.boss_skill=clampi(skill,0,pool.size()-1)
		if Choreography.start(s,e,str(pool[e.boss_skill]),(target.p-e.p).normalized(),target.p): return
	var table: Array=moves_of(e)
	var move: Dictionary=table[clampi(skill,0,table.size()-1)]
	e.boss_skill=skill
	e.boss_elapsed=0.0
	e.boss_windup=float(move.windup)*(0.84 if e.boss_enraged else 1.0)
	e.boss_released=false
	e.attack_total=e.boss_windup+0.75
	e.attack_time=e.attack_total
	e.attack_aim=(target.p-e.p).normalized()
	if absf(e.attack_aim.x)>.05: e.facing=signf(e.attack_aim.x)
	e.attack_point=target.p
	e.attack_start=e.p
	e.boss_points=[]
	e.boss_lines=[]
	var shape: String=move.shape
	var damage := 20.0+int(e.rogue_skin)*4.0
	var delay: float=e.boss_windup
	if shape in ["cone","triple"]:
		zone(e,"cone",e.p,float(move.reach),delay,0.16,damage,e.attack_aim)
		if shape=="triple":
			for n in 2: zone(e,"cone",e.p,float(move.reach),delay+0.38*(n+1),0.12,damage,e.attack_aim.rotated(0.35 if n==0 else -0.35))
	elif shape=="circle": zone(e,"circle",e.p,float(move.reach),delay,0.18,damage)
	elif shape in ["ring","seal"]:
		zone(e,"ring",e.p,155.0,delay,0.3,damage,Vector2.RIGHT,90.0)
		if shape=="seal": zone(e,"ring",e.p,235.0,delay+0.65,0.25,damage,Vector2.RIGHT,170.0)
	elif shape in ["roots","eruption","meteors","storm","swords"]:
		var count := 3 if shape in ["roots","eruption"] else 5
		for n in count:
			var at: Vector2=s.ruins.safe_point(target.p+Vector2((n-count/2)*95,55*sin(n*2.1)))
			e.boss_points.append(at)
			zone(e,"circle",at,48.0 if shape=="roots" else 57.0,delay+n*0.20,2.0 if shape in ["roots","eruption"] else 0.22,damage)
	elif shape in ["line","mirrors","lightning","cross","dash"]:
		var count := 3 if shape in ["mirrors","lightning"] else 2 if shape=="cross" else 1
		for n in count:
			var dir: Vector2=e.attack_aim.rotated((n-1)*0.32) if count==3 else e.attack_aim.rotated(n*PI/2)
			var start: Vector2=e.p
			if shape=="lightning": start=e.p+Vector2(n*70,-50+n*50)
			var end: Vector2=s.ruins.move(start,dir*(330.0 if shape=="dash" else 540.0),20)
			e.boss_lines.append({"a":start,"b":end})
			zone(e,"line",start,24.0,delay+(n*0.2 if shape=="lightning" else 0),0.38,damage,dir,0.0,end)
	elif shape=="blink":
		e.attack_point=s.roguelike.spawn_point(s,target.p+Vector2(120,0))
		zone(e,"circle",e.attack_point,100,delay,0.18,damage)
	elif shape=="cyclone":
		zone(e,"cyclone",e.p,58,delay,3.5,damage,e.attack_aim)
	else:
		# Radial / fan / orbit / summon warns at the caster before release.
		zone(e,"aura",e.p,85.0,delay,0.35,0.0,e.attack_aim)
	s.broadcast_audio(cue(e,skill,"charge"),e)
	s.broadcast_combat({"kind":"rogue-boss-charge","p":e.p,"id":e.id,"floor":e.rogue_skin,"duration":delay})

func cue(e: Dictionary, skill: int, action: String) -> String:
	return "rogue-%d-%d-%s" % [int(e.rogue_skin),skill,action]

func update_boss(s, e: Dictionary, dt: float) -> void:
	var target: Dictionary=nearest(s,e)
	if target.is_empty(): return
	if not e.boss_enraged and e.hp<=e.max_hp*0.5:
		# 阶段切换只发生一次：boss_enraged 一旦置位便单调不回退（回血也不会退回一阶段）。
		e.boss_enraged=true
		e["phase"]=2
		s.broadcast_combat({"kind":"rogue-boss-phase","id":e.id,"p":e.p,"floor":e.rogue_skin,"duration":1.2})
		s.message.emit(e.boss_name+"进入二阶段！招式全开")
		s.broadcast_audio("rogue-%d-phase" % int(e.rogue_skin),e)
		# Dedicated identity crest announces the phase, without a generic aura.
	if e.attack_time>0 and e.get("choreo_cast",false):
		e.attack_time=maxf(0,e.attack_time-dt)
		return
	if e.attack_time>0:
		e.boss_elapsed+=dt
		e.attack_time=maxf(0,e.attack_time-dt)
		if not e.boss_released and e.boss_elapsed>=e.boss_windup:
			e.boss_released=true
			release(s,e)
		var table: Array=moves_of(e)
		var shape: String=str(table[clampi(int(e.boss_skill),0,table.size()-1)].shape)
		if shape=="dash" and e.boss_elapsed>=e.boss_windup:
			var advance: float=maxf(0,minf(e.boss_elapsed,e.boss_windup+0.38)-maxf(e.boss_elapsed-dt,e.boss_windup))
			e.p=s.ruins.move(e.p,e.attack_aim*780*advance,e.rogue_radius)
			e.moving=advance>0
		return
	e.cd=maxf(0,e.cd-dt)
	var direction: Vector2=(target.p-e.p).normalized()
	if absf(direction.x)>0.05: e.facing=signf(direction.x)
	if e.cd<=0 and e.p.distance_to(target.p)<600:
		var skill: int=skill_for_cursor(e,int(e.move_cursor))
		e.move_cursor+=1
		begin_skill(s,e,skill,target)
		e.cd=(1.0 if e.boss_enraged else 1.65)/enemy_tempo(s)
	elif e.p.distance_to(target.p)>115:
		move_towards(s,e,direction*1.0,(100.0 if e.boss_enraged else 70.0)*dt)

func release(s, e: Dictionary) -> void:
	var skill: int=e.boss_skill
	var shape: String=str(moves_of(e)[clampi(skill,0,moves_of(e).size()-1)].shape)
	s.broadcast_audio(cue(e,skill,"release"),e)
	if shape in ["radial","orbit"]:
		for n in (16 if shape=="orbit" else 12):
			var dir := Vector2.from_angle(n*TAU/(16 if shape=="orbit" else 12)+e.attack_aim.angle())
			bolt(s,e,dir,170 if shape=="orbit" else 205,18+e.rogue_skin*3)
		if shape=="orbit":
			for n in 8: bolt(s,e,Vector2.from_angle(n*TAU/8+0.2),260,18+e.rogue_skin*3)
	elif shape=="fan":
		for n in 9: bolt(s,e,e.attack_aim.rotated((n-4)*0.14),230,24)
	elif shape=="summon":
		if s.enemies.size()<12:
			for n in 3: summons.append({"floor":int(e.rogue_skin),"variant":n+1,"p":s.ruins.safe_point(e.p+Vector2(-110+n*110,80))})
		e.hp=minf(e.max_hp,e.hp+e.max_hp*0.035)
	elif shape=="blink": e.p=e.attack_point

func bolt(s, e: Dictionary, direction: Vector2, speed: float, damage: float) -> void:
	# bullet_visual 只被表现层读取（G 集合），命中判定始终是 session.gd 里的默认 hit_radius=18.0。
	s.bullets.append({"p":e.p,"v":direction*speed*bullet_speed_of(e),"life":2.6,"damage":damage,"owner":0,"boss_source":e.id,"fx_move":visual_move(e),"rogue_tone":e.rogue_skin,"rogue_guardian":e.get("rogue_guardian",false),"bullet_visual":bullet_visual_of(e)})

func zone(e: Dictionary, shape: String, at: Vector2, radius: float, delay: float, life: float, damage: float,
		direction: Vector2 = Vector2.RIGHT, inner: float = 0.0, end: Vector2 = Vector2.ZERO) -> void:
	e["visual_zone_serial"]=int(e.get("visual_zone_serial",0))+1
	effects.append({"fx_move":visual_move(e),"visual_token":str(e.id)+":"+str(e.visual_zone_serial),"source":e.id,"floor":int(e.rogue_skin),"rogue_guardian":e.get("rogue_guardian",false),"shape":shape,"p":at,"end":end,
		"radius":radius,"inner":inner,"direction":direction,"delay":delay,"windup":delay,
		"life":life,"total":life,"age":0.0,"damage":damage*(1.0 if e.get("choreo_cast",false) else float(e.get("build_damage_scale",1))),"hit":{},"pulse":0.0,"active":delay<=0})

func contains(fx: Dictionary, point: Vector2) -> bool:
	if fx.get("choreographed",false): return Choreography.Geometry.contains(fx,point)
	var distance: float=point.distance_to(fx.p)
	match str(fx.shape):
		"line": return Geometry2D.get_closest_point_to_segment(point,fx.p,fx.end).distance_to(point)<fx.radius+15
		"cone": return distance<fx.radius+15 and absf(fx.direction.angle_to(point-fx.p))<0.85
		"ring": return distance>=fx.inner-15 and distance<=fx.radius+15
		"aura": return false
	return distance<fx.radius+15

func tick(s, dt: float) -> void:
	minion_start_gap=maxf(0,minion_start_gap-dt)
	update_missiles(s,dt)
	# Spawning is deferred until the enemy iteration has finished.
	for entry in summons:
		var source_alive: bool=not entry.has("owner")
		var summoned_count := 0
		for e in s.enemies:
			if e.hp>0 and e.id==int(entry.get("owner",-1)): source_alive=true
			if e.hp>0 and e.get("rogue_summoned",false): summoned_count+=1
		if not source_alive or summoned_count>=4: continue
		s.roguelike.spawn_minion(s,entry.p,entry.floor,entry.variant,false)
		s.enemies.back()["rogue_summoned"]=true
		s.enemies.back()["summon_owner"]=int(entry.get("owner",-1))
		s.enemies.back().hp*=.45
		s.enemies.back().max_hp=s.enemies.back().hp
		if entry.get("decoy",false):
			s.enemies.back().hp=1.0
			s.enemies.back().max_hp=1.0
			s.enemies.back()["rogue_decoy"]=true
			s.enemies.back()["decoy_life"]=1.5
		s.broadcast_combat({"kind":"rogue-support","style":"summon","p":entry.p,"target":entry.p,"id":int(entry.get("owner",s.enemies.back().id)),"floor":entry.floor})
	summons.clear()
	for e in s.enemies:
		if not e.get("rogue_summoned",false) or int(e.get("summon_owner",-1))<0: continue
		var living := false
		for owner in s.enemies:
			if owner.id==e.summon_owner and owner.hp>0: living=true; break
		if not living: e.hp=0.0
	for p in s.players.values(): p["rogue_slow"]=0.0
	for i in range(effects.size()-1,-1,-1):
		var fx: Dictionary=effects[i]
		var living := false
		for e in s.enemies:
			if e.id==fx.source and e.hp>0: living=true; break
		if not living: effects.remove_at(i); continue
		if fx.get("choreographed",false):
			if not Choreography.linked(s,int(fx.source),str(fx.get("link",""))): effects.remove_at(i); continue
			if fx.active:
				fx.p+=fx.get("velocity",Vector2.ZERO)*dt
				fx.aim=fx.aim.rotated(float(fx.get("rotate",0))*dt)
				fx.direction=fx.aim
		var active_dt: float=maxf(0,dt-maxf(0,fx.delay))
		fx.delay-=dt
		if fx.delay>0: continue
		if not fx.get("visual_sent",false):
			fx["visual_sent"]=true
			if fx.get("choreographed",false):
				for boss in s.enemies:
					if boss.id==fx.source:
						boss["boss_released"]=true
						var mark := str(fx.choreo_serial)+":"+str(fx.windup)
						if mark not in boss.get("choreo_sound_marks",[]):
							if not boss.has("choreo_sound_marks"): boss["choreo_sound_marks"]=[]
							boss.choreo_sound_marks.append(mark)
							s.broadcast_audio(cue(boss,int(boss.get("boss_skill",0)),"release"),boss)
			fx["visual_next"]=0.38
			s.broadcast_combat({"kind":"rogue-zone","p":fx.p,"fx":fx.duplicate(true)})
		fx.active=true
		if fx.get("choreographed",false): Choreography.modifiers(s,fx,active_dt)
		fx.age+=active_dt
		fx.life-=active_dt
		if fx.get("ring_expand",false):
			fx.radius=lerpf(40,140,clampf(fx.age/fx.total,0,1))
			fx.inner=maxf(15,fx.radius-30)
		if fx.shape=="cyclone": fx.p=s.ruins.move(fx.p,fx.direction*75*active_dt,10)
		for p in s.players.values():
			if p.status!="active" or not contains(fx,p.p) or Choreography.cover_blocks(s,fx,p.p): continue
			if not fx.get("choreographed",false): p.rogue_slow=maxf(p.rogue_slow,float(fx.get("slow",0)))
			var last: float=fx.hit.get(p.id,-10.0)
			if fx.age-last>=0.6:
				if float(fx.damage)>0:
					var source: Dictionary={}
					for enemy in s.enemies:
						if enemy.id==fx.source: source=enemy; break
					var height_tag: String=fx.get("height_tag","ground" if fx.shape in ["ring","roots","cross"] else "normal")
					s.hurt(p,float(fx.damage),source,height_tag,"direct",str(fx.get("element","lightning" if int(fx.floor)==3 else "fire" if int(fx.floor)==1 else "physical")))
				if not fx.get("choreographed",false) and float(fx.get("pull",0))>0: p.p=s.ruins.move(p.p,(fx.p-p.p).normalized()*float(fx.pull)*(.7 if s.RogueBuild.gear(p,56) else 1.0),15)
				if float(fx.get("push",0))>0: p.p=s.ruins.move(p.p,(p.p-fx.p).normalized()*float(fx.push)*(.7 if s.RogueBuild.gear(p,56) else 1.0),15)
				fx.hit[p.id]=fx.age
		if fx.life<=0: effects.remove_at(i)

func defeated(s, e: Dictionary) -> void:
	if not e.get("rogue_guardian",false): return
	s.broadcast_combat({"kind":"rogue-boss-fall","id":e.id,"p":e.p,"floor":e.rogue_skin,"duration":1.3})
	s.broadcast_audio("rogue-%d-fall" % int(e.rogue_skin),e)
	s.message.emit(e.boss_name+"已击败")
	# Keep an animated death silhouette, with no remaining damage.
	s.raid["rogue_corpses"]=[{"p":e.p,"floor":e.rogue_skin,"time":1.2,"total":1.2,"facing":e.facing}]
	for other in s.enemies:
		if other.get("rogue_summoned",false): other.hp=0.0
	effects.clear()
	summons.clear()
