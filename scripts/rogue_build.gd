extends RefCounted
## Host-authoritative build rules. Child damage never starts another hit chain.
const Content = preload("res://scripts/rogue_content.gd")
const HERO_BASE := [[12,11,12,15,21,10,17],[12,18,11,10,12,21,14],[16,10,17,23,12,10,10],[11,16,11,11,12,20,17]]
const HERO_GRADES := [{"strength":"D","dexterity":"B","arcane":"C"},{"intelligence":"B","arcane":"C"},{"strength":"B","dexterity":"D"},{"intelligence":"B","arcane":"B"}]
const FORGE_COST := [1,1,2,2,2]
const GRADE_ORDER := ["-","E","D","C","B","A","S"]
const CM_ROUTES := [["DA","AADA",">S","JAS"],["DA","ADS","JA","AJS"],["DA","AADS","JA","JAS"],["DA","ADS","JA","JAS"]]
const HC_ROUTES := [["AADAS",">SJA","JAS","ASU"],["ADS","JAS","AADS","DASU"],["ADJS","DAAS","AA<>S","JASU"],["ADS","AJAS","DAAS","ASU"]]

static func reset(s, p: Dictionary) -> void:
	p.merge({"build_version":3,"build_talents":{},"build_library":[],"build_cultivation":0,"build_attributes":{},"build_attribute_points":0,
		"build_level":1,"build_xp":0,"build_xp_total":0,"build_chest_attribute_drops":0,
		"build_forge_points":0,"build_forge_level":0,"build_forge_bound":"","build_core":"","build_temper":"","build_awards":{},
		"build_cd":{},"build_buffs":{},"build_counts":{},"build_heals":[],"build_mana_returns":[],"build_summons":[],"build_fields":[],
		"build_reward_queue":[],"build_serial":0,"build_inputs":[],"build_combo_label":"","build_combo_time":0.0,"build_hero_cd":0.0,
		"build_shield":0.0,"build_shield_time":0.0,"build_shields":{},"build_last_hurt":-10.0,"build_stationary":0.0,"build_souvenirs":0,"build_floor_souvenirs":0,
		"height":0.0,"height_velocity":0.0,"jump_cd":0.0,"air_attacks":0,"air_art":false,"air_dodge":false,
		"flask":100.0,"flask_cd":0.0,"flask_time":0.0,"flask_committed":false,"soul_lamp":true,"lamp_time":0.0,
		"flask_refills":0,"flask_combat_awards":0,"flask_elite_award":false,"build_vitality_healed":0,"flask_shop_floor":0,"build_respec_floor":0},true)
	# `rogue_rerolls` is *caller-owned config*, not run state: `session.gd` already
	# stored the purchased card count there and `roguelike.gd` added the growth
	# tree's `start_rerolls` on top of it. Merging a literal `3` with overwrite=true
	# used to wipe both, which is why bought cards never reached the run. Only hand
	# out the legacy default when the caller never set the key at all.
	if not p.has("rogue_rerolls"): p["rogue_rerolls"]=3
	s.refresh_max_hp(p)
	p.hp=p.max_hp
	p.mana=p.max_mana
	p.ammo=16; p.reserve=96

static func attributes(p: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for i in WatcherAttributes.KEYS.size():
		var key: String=WatcherAttributes.KEYS[i]
		result[key]=clampi(int(HERO_BASE[clampi(int(p.hero),0,3)][i])+int(p.get("attributes",{}).get(key,10))-10+int(p.get("build_attributes",{}).get(key,0)),10,99)
	return result

static func rank(p: Dictionary, n: int) -> int:
	return int(p.get("build_talents",{}).get("T%03d" % n,0))

static func r(p: Dictionary, n: int, values: Array) -> float:
	var level := rank(p,n)
	return float(values[mini(level,values.size())-1]) if level>0 else 0.0

static func gear(p: Dictionary, n: int) -> bool:
	for item in p.equipped.get("gear",[]):
		if item.get("build_id","")=="E%03d" % n: return true
	return false

static func engraving(p: Dictionary, n: int) -> bool:
	return int(p.equipped.get("weapon",{}).get("rogue_id",-1))==n-1

static func weapon_id(p: Dictionary) -> int:
	return int(p.weapon)-Content.WEAPON_BASE+1 if not Content.weapon(int(p.weapon)).is_empty() else 0

static func forge_level(p: Dictionary) -> int:
	var item: Dictionary=p.equipped.get("weapon",{})
	return int(p.get("build_forge_level",0)) if not item.is_empty() and str(item.get("instance_id",""))==str(p.get("build_forge_bound","")) else 0

static func visual_state(p: Dictionary) -> Dictionary:
	var level := clampi(forge_level(p),0,5)
	var item: Dictionary=p.equipped.get("weapon",{})
	var quality := clampi(int(item.get("tier",0)),0,5)
	var core_id := str(p.get("build_core",""))
	var def := Content.entry(core_id)
	var valid: bool=level>=2 and core_id.begins_with("WC") and not def.is_empty() and int(def.get("family",-1))==Catalog.weapon_family(int(p.weapon))
	return {"forge":level,"quality":quality,"quality_factor":Content.QUALITY[quality],
		"core":core_id if valid else "","core_rank":(2 if level>=4 else 1) if valid else 0,
		"temper":str(p.get("build_temper","")) if level>=3 else ""}

static func core(p: Dictionary, n: int) -> int:
	if forge_level(p)<2 or str(p.get("build_core",""))!="WC%03d" % n: return 0
	return 2 if forge_level(p)>=4 else 1

static func grades(p: Dictionary, index: int) -> Dictionary:
	var result: Dictionary=Catalog.weapon(index).get("scaling",{}).duplicate()
	var key := str(p.get("build_temper",""))
	if index==int(p.weapon) and forge_level(p)>=3 and key in ["strength","dexterity","intelligence","arcane"]:
		var at := GRADE_ORDER.find(str(result.get(key,"-")))
		if at>0 and at<6: result[key]=GRADE_ORDER[at+1]
	return result

static func quality(p: Dictionary) -> float:
	return Content.QUALITY[clampi(int(p.equipped.get("weapon",{}).get("tier",0)),0,5)]

static func aura(s, p: Dictionary, n: int, values: Array) -> float:
	var result := 0.0
	for ally in s.players.values():
		if ally.status=="active" and ally.connected and ally.p.distance_to(p.p)<=240: result=maxf(result,r(ally,n,values))
	return result

static func alone(s, p: Dictionary, distance: float = 320.0) -> bool:
	for ally in s.players.values():
		if ally.id!=p.id and ally.connected and ally.status=="active" and ally.p.distance_to(p.p)<=distance: return false
	return true

static func stat(s, p: Dictionary, name: String) -> float:
	match name:
		"hp": return r(p,65,[12,20,28])+r(p,89,[10,16,22])+(10 if gear(p,24) and s.players.size()==1 else 0)
		"mana": return r(p,49,[10,16,22])+r(p,89,[4,6,8])
		"damage": return forge_level(p)*.03+(.08 if gear(p,23) and alone(s,p) else 0)
		"defense": return r(p,66,[.03,.05,.07])+aura(s,p,90,[.02,.03,.04])+(.04 if gear(p,24) and not alone(s,p,240) else 0)
		"speed": return r(p,42,[8,12,16])+r(p,73,[8,12,16])+buff(p,"speed",s.elapsed)+(15 if gear(p,72) and p.hp<p.max_hp*.4 and s.players.size()==1 else 0)
		"regen": return clampf(r(p,50,[.10,.15,.20])+aura(s,p,91,[.06,.09,.12])+(0.25 if rank(p,56)>0 else 0)-(.2 if rank(p,32)>0 else 0)+(.25 if gear(p,4) and p.hp>=p.max_hp*.8 else 0)+(r(p,36,[.1,.15,.2]) if s.elapsed-float(p.get("build_last_hurt",-10))>=3 else 0),-.5,.5)
		"art_cdr": return minf(.25,r(p,58,[.04,.06,.08])+(.08 if gear(p,42) else 0)+(.05 if engraving(p,14) else 0))
		"dodge_cdr": return minf(.2,r(p,74,[.05,.08,.12])+(.08 if gear(p,69) else 0))
		"rate": return minf(.4,buff(p,"haste",s.elapsed))
	return 0.0

## A2 · 读取"当前层变数 + 该玩家诅咒"的合成数值表。唯一实现仍是 `session.rogue_mods(p)`
## （`roguelike.mod_of()` 只是它的转发），这里给出 Build 层需要的入口，避免各处自己拼一张表。
## A1 起 `rogue_mods()` 还多合并了**局外成长树**（`RogueGrowth.run_mods`），所以本入口
## 同时也是成长树效果键的读取点：`enemy_hp`/`enemy_damage`（成长侧，只影响数值）、
## `xp_gain`、`heal_scale` 等。
## 非魔境 / 无 `rogue_mods` 的桩会话一律返回 0.0，所以战场与战役路径逐位不变；
## 本函数是纯读，**不消耗 `s.rng`**（`rogue_mods` 本身也保证不消耗）。
static func hook_mod(s, p: Dictionary, key: String) -> float:
	if s==null or p==null or p.is_empty(): return 0.0
	if not s.has_method("rogue_mods"): return 0.0
	return float(s.rogue_mods(p).get(key,0.0))

static func hp_multiplier(p: Dictionary) -> float:
	return .9 if rank(p,48)>0 or rank(p,80)>0 else 1.0

static func interval(s, p: Dictionary) -> float:
	return (1.12 if rank(p,16)>0 and Catalog.weapon_family(int(p.weapon))==2 else 1.0)*(1.1 if rank(p,40)>0 else 1.0)/(1.0+stat(s,p,"rate"))

static func conditional_defense(s, p: Dictionary) -> float:
	var low: bool=p.hp<p.max_hp*.35
	var value: float=(.15 if gear(p,2) and low else 0)+(r(p,68,[.05,.08,.11]) if low else 0)
	if p.pending_strike and Catalog.weapon_family(int(p.weapon))==2: value+=r(p,11,[.05,.08,.11])
	if p.mana>=p.max_mana*.7: value+=r(p,54,[.06,.1])
	if not p.get("build_summons",[]).is_empty(): value+=r(p,87,[.04,.07])+(.06 if gear(p,19) else 0)
	if gear(p,22) and p.channel>0: value+=.15
	return minf(.2,value+buff(p,"defense",s.elapsed))

static func ready(s, p: Dictionary, key: String, seconds: float) -> bool:
	if s.elapsed<float(p.get("build_cd",{}).get(key,0)): return false
	p.build_cd[key]=s.elapsed+seconds
	return true

static func grant(p: Dictionary, key: String, value: float, seconds: float, now: float) -> void:
	p.build_buffs[key]={"value":value,"until":now+seconds}

static func buff(p: Dictionary, key: String, now: float) -> float:
	var b: Dictionary=p.get("build_buffs",{}).get(key,{})
	return float(b.get("value",0)) if now<float(b.get("until",0)) else 0.0

static func unit(s, p: Dictionary, hero: bool = false) -> float:
	var k := WatcherAttributes.scaling(attributes(p),HERO_GRADES[int(p.hero)] if hero else grades(p,int(p.weapon)))
	return 90.0*quality(p)*(1.0+k)*(1.0+s.rogue_damage_pool(p))

static func context(s, p: Dictionary, kind: String) -> Dictionary:
	p.build_serial=int(p.get("build_serial",0))+1
	var result := {"root":"%s:%d" % [p.id,p.build_serial],"kind":kind,"depth":0,"seen":{},"counted":false,"family":Catalog.weapon_family(int(p.weapon)),"weapon":weapon_id(p),"combo":int(p.combo),"height":float(p.get("height",0)),"unit":unit(s,p,kind=="skill"),"cost":float(p.get("build_last_cost",0)),"refunded":0.0,"first":true,"route":int(p.get("build_next_route",-1)),"hero_route":int(p.get("build_next_hero",-1)),"art_bonus":buff(p,"relay",s.elapsed)+(.2 if buff(p,"rotation",s.elapsed)>0 else 0)}
	result["vfx"]=visual_state(p) # Snapshot before a projectile outlives this equipment.

	for input in p.build_inputs:
		if input.get("root","")=="" and input.key=={"attack":"A","art":"S","skill":"U"}.get(kind,""): input.root=result.root
	p.build_next_route=-1; p.build_next_hero=-1
	return result

static func core_visual(s, p: Dictionary, n: int, at: Vector2, ctx: Dictionary = {}) -> void:
	var rank := core(p,n)
	if rank<=0: return
	var state := visual_state(p)
	if state.core!="WC%03d" % n: return
	var shown: Dictionary=ctx.get("core_visuals",{}) if ctx.has("root") else {}
	if shown.has(n): return
	shown[n]=true
	if ctx.has("root"): ctx["core_visuals"]=shown
	s.broadcast_combat({"kind":"weapon_core","p":at,"aim":p.aim,"id":p.id,"weapon_index":int(p.weapon),"core_id":n,"core_rank":rank,"vfx":state})

static func heal(s, source: Dictionary, target: Dictionary, ratio: float, passive: bool = true) -> float:
	if target.status!="active" or target.hp>=target.max_hp: return 0.0
	var amp: float=(.1 if gear(target,47) else 0)+(.1 if rank(target,96)>0 else 0)
	# A2 (R9 hook 6): CU06「干涸」/ CU10「碎盾」的 `heal_scale`（CAPS 锁在 [-0.60,0]，负=治疗变差）
	# 乘进这一笔治疗量。治量是攻击性资源，所以它必须真的落到数值上，而不是只写在诅咒描述里。
	# 无该键时 1.0：`wanted` 逐位不变。下界 0 只是防御（任何来源都不该把治疗变成倒扣）。
	var curse_heal := maxf(0.0,1.0+hook_mod(s,target,"heal_scale"))
	var wanted := minf(target.max_hp-target.hp,target.max_hp*ratio*(1.0+minf(.3,amp))*curse_heal)
	var recent: Array=target.get("build_heals",[]).filter(func(h): return s.elapsed-float(h.time)<5.0)
	var total := 0.0
	var own := 0.0
	for h in recent:
		total+=float(h.amount)
		if int(h.source)==int(target.id) and h.get("passive",true): own+=float(h.amount)
	wanted=minf(wanted,maxf(0,target.max_hp*.15-total))
	if source.id==target.id and passive: wanted=minf(wanted,maxf(0,target.max_hp*.1-own))
	target.hp+=wanted
	if wanted>0:
		recent.append({"time":s.elapsed,"amount":wanted,"source":source.id,"passive":passive})
		if rank(source,95)>0 and ready(s,source,"T095",5): grant(source,"healed",r(source,95,[.10,.15]),4,s.elapsed)
	target.build_heals=recent
	return wanted

static func shield(s, p: Dictionary, ratio: float, seconds: float, source: String = "general") -> void:
	var was_empty: bool=float(p.get("build_shield",0))<=0
	var sources: Dictionary=p.get("build_shields",{})
	var others := 0.0
	for key in sources:
		if key!=source: others+=float(sources[key].amount)
	var previous: Dictionary=sources.get(source,{})
	var amount := minf(maxf(0,p.max_hp*.35-others),maxf(float(previous.get("amount",0)),p.max_hp*ratio))
	sources[source]={"amount":amount,"time":minf(6.0,seconds+r(p,67,[.5,.8,1]))}
	p.build_shields=sources
	p.build_shield=others+amount
	p.build_shield_time=maxf(float(p.get("build_shield_time",0)),float(sources[source].time))
	if was_empty and gear(p,44) and ready(s,p,"E044",6): grant(p,"shield_strike",.14,3,s.elapsed)

static func mana(s, p: Dictionary, amount: float) -> void:
	var recent: Array=p.get("build_mana_returns",[]).filter(func(h): return s.elapsed-float(h.time)<1.0)
	var total := 0.0
	for h in recent: total+=float(h.amount)
	amount=minf(amount,maxf(0,4.0-total))
	p.mana=minf(p.max_mana,p.mana+amount)
	if amount>0: recent.append({"time":s.elapsed,"amount":amount})
	p.build_mana_returns=recent

static func refund(s, p: Dictionary, ctx: Dictionary, ratio: float) -> void:
	var amount := minf(float(ctx.cost)*ratio,maxf(0,float(ctx.cost)*.35-float(ctx.refunded)))
	ctx.refunded=float(ctx.refunded)+amount
	mana(s,p,amount)

static func lowest(s, p: Dictionary, distance: float = 240.0, other: bool = false) -> Dictionary:
	var target: Dictionary={}
	var ratio := INF
	for ally in s.players.values():
		if ally.status!="active" or not ally.connected or (other and ally.id==p.id) or ally.p.distance_to(p.p)>distance: continue
		if ally.hp/ally.max_hp<ratio: ratio=ally.hp/ally.max_hp; target=ally
	return target

static func spend_event(s, p: Dictionary, cost: float) -> void:
	p.build_last_cost=cost
	p.build_counts["spent"]=float(p.build_counts.get("spent",0))+cost
	if cost>=12:
		if gear(p,26) and ready(s,p,"E026",5): heal(s,p,p,.02)
		if rank(p,53)>0 and ready(s,p,"T053",5): grant(p,"refund_next",minf(cost*.35,r(p,53,[2,3])),4,s.elapsed)
		if (gear(p,21) or rank(p,93)>0) and ready(s,p,"support_heal",6):
			var target := lowest(s,p)
			if not target.is_empty(): heal(s,p,target,maxf(.02 if gear(p,21) else 0,r(p,93,[.015,.02])))
		if rank(p,96)>0 and ready(s,p,"T096",6):
			shield(s,p,.04,3)
			var ally := lowest(s,p,240,true)
			if not ally.is_empty(): shield(s,ally,.04,3)
	if rank(p,55)>0 and float(p.build_counts.spent)>=40 and ready(s,p,"T055",5):
		p.build_counts.spent=minf(39,float(p.build_counts.spent)-40)
		grant(p,"spring_echo",r(p,55,[.20,.30]),8,s.elapsed)

static func mana_cost(s, p: Dictionary, base: float, kind: String) -> float:
	if base<=0: return 0
	var reduction := .1 if gear(p,13) and p.mana>=p.max_mana*.75 else 0.0
	if kind=="attack" and Catalog.weapon_family(int(p.weapon))==3:
		reduction+=r(p,52,[.05,.08,.12])+(.1 if gear(p,43) else 0)+buff(p,"landing_cost",s.elapsed)
	if kind=="art": reduction+=buff(p,"hammer_cost",s.elapsed)+(.2 if buff(p,"rotation",s.elapsed)>0 else 0)-(.15 if rank(p,56)>0 else 0)
	return maxf(1.0 if kind=="attack" else 6.0 if kind=="art" else 20.0,base*(1.0-clampf(reduction,-.15,.25)))

static func attenuation(p: Dictionary, base: float) -> float:
	return minf(.8,base+r(p,22,[.08,.12]))

static func status(e: Dictionary, owner: int, name: String) -> int:
	return int(e.get("build_status",{}).get(str(owner),{}).get(name,{}).get("stacks",0))

static func add_status(s, p: Dictionary, e: Dictionary, name: String, stacks: int, power: float) -> void:
	if e.hp<=0 or e.get("boss_construct",false): return
	if not e.has("build_status"): e.build_status={}
	var owner := str(p.id)
	if not e.build_status.has(owner): e.build_status[owner]={}
	var states: Dictionary=e.build_status[owner]
	var duration := 4.0
	if name=="burn": duration=minf(6.0,4+r(p,26,[.5,1,1.5])+(1 if gear(p,8) else 0)+(1 if gear(p,35) else 0)+(.5 if engraving(p,11) else 0))
	elif name=="bleed": duration=4.0+(.5 if engraving(p,11) else 0)
	elif name=="frost": duration=minf(4.5,3.0+r(p,34,[.4,.7,1]))
	elif name=="mark": duration=4.0
	states[name]={"stacks":mini(1 if name=="mark" else 5,status(e,p.id,name)+stacks),"time":duration,"power":power,"clock":float(states.get(name,{}).get("clock",0))}
	if name=="frost" and int(states[name].stacks)==5 and s.elapsed>=float(e.get("build_cc_until",0)):
		e["build_cc_until"]=s.elapsed+(6 if rank(p,40)>0 else 7 if gear(p,38) else 8)
		if not e.get("rogue_guardian",false): e.stagger=maxf(float(e.get("stagger",0)),.3 if e.get("build_elite",false) else .6)
		if gear(p,9): shield(s,p,.06,4,"E009")
		if rank(p,37)>0: shield(s,p,r(p,37,[.05,.08]),4,"T037")
		if gear(p,62): mana(s,p,4)
		if rank(p,38)>0: proc(s,p,e,r(p,38,[.2,.3]),power)

static func proc(s, p: Dictionary, e: Dictionary, ratio: float, power: float = -1.0, kind: String = "proc") -> void:
	if ratio<=0 or e.hp<=0: return
	s.damage_enemy(e,(unit(s,p) if power<0 else power)*ratio,p.id,Vector2.ZERO,0,-1,-1,{"depth":1,"kind":kind})

static func nearby(s, p: Dictionary, e: Dictionary, distance: float, count: int = 1) -> Array:
	var candidates: Array=[]
	for target in s.enemies:
		if target.id!=e.id and target.hp>0 and not target.get("boss_construct",false) and target.p.distance_to(e.p)<=distance and s.ruins.clear_line(e.p,target.p): candidates.append(target)
	candidates.sort_custom(func(a,b): return a.p.distance_squared_to(e.p)<b.p.distance_squared_to(e.p))
	return candidates.slice(0,mini(count,candidates.size()))

static func summon(s, p: Dictionary, seconds: float, ratio: float) -> void:
	if p.build_summons.size()>=2: return
	p.build_summons.append({"time":minf(10,seconds+r(p,83,[.5,1,1.5])),"clock":0.0,"ratio":ratio,"power":unit(s,p),"extended":0.0,"p":p.p})

static func field(p: Dictionary, at: Vector2, seconds: float, radius: float, ratio: float, power: float, count: int = 3) -> void:
	if p.build_fields.size()>=2: return
	p.build_fields.append({"p":at,"time":seconds,"radius":radius,"ratio":ratio,"power":power,"clock":0.0,"count":count})

static func hit_multiplier(s, p: Dictionary, e: Dictionary, ctx: Dictionary) -> float:
	if int(ctx.get("depth",0))>0: return 1.0
	var normal: bool=ctx.get("kind","")=="attack"
	var art: bool=ctx.get("kind","")=="art"
	var family: int=int(ctx.get("family",Catalog.weapon_family(int(p.weapon))))
	var spell: bool=family==3 or ctx.get("kind","")=="skill"
	var c := 0.0
	var local_a := 0.0
	var penalty := 1.0
	var hp: float=p.hp/p.max_hp
	var mp: float=p.mana/p.max_mana
	var enemy_hp: float=e.hp/maxf(1,e.max_hp)
	var distance: float=p.p.distance_to(e.p)
	var blood := status(e,p.id,"bleed")
	var fire := status(e,p.id,"burn")
	var frost := status(e,p.id,"frost")
	var shock := status(e,p.id,"shock")
	var marked := status(e,p.id,"mark")>0
	if marked and normal: c+=.12
	c+=shock*.02
	if normal:
		local_a+=r(p,{1:1,2:9,0:17}.get(family,0),[.06,.10,.14])
		if distance>=220: c+=r(p,18,[.06,.09,.12])+(.12 if gear(p,49) else 0)
		if distance<=100 and family in [1,2] and gear(p,50): c+=.10
		if mp<=.35: c+=r(p,60,[.06,.09,.12])
		if rank(p,8)>0: penalty*=.88
		if rank(p,88)>0: penalty*=.88
		if rank(p,24)>0:
			if family==0 and distance<160: penalty*=.85
			if marked: c+=.22
		for key in ["dodge_strike","perfect_strike","shield_strike","counter","healed","summon_strike","reload_strike","art_strike","landing_strike"]: c+=buff(p,key,s.elapsed)
		if rank(p,72)>0: penalty*=.88
	if rank(p,96)>0: penalty*=.90
	if art:
		local_a+=r(p,57,[.08,.12,.16])
		c+=float(ctx.get("art_bonus",0))
		if enemy_hp<=.3 and gear(p,15): c+=.18
		if mp<=.3 and gear(p,41): c+=.16
	if forge_level(p)>=3 and p.get("build_temper","")=="steady" and (normal or art): local_a+=.04
	if blood>=3: c+=r(p,3,[.06,.09,.12])
	if blood>=5 and gear(p,5): c+=.12
	if fire>0: c+=r(p,27,[.05,.08,.11])
	if frost>=3: c+=r(p,35,[.06,.09,.12])+(.12 if spell and gear(p,37) else 0)
	if frost==5 and e.get("rogue_guardian",false) and spell and rank(p,40)>0: c+=.20
	if float(e.get("build_break_time",0))>0: c+=.12+r(p,13,[.12,.18])
	if spell and mp>=.7: c+=r(p,51,[.06,.09,.12])+(.18 if rank(p,56)>0 else 0)
	if gear(p,25) and mp>=.7: c+=.12
	if gear(p,27) and e.get("rogue_guardian",false): c+=.16
	if gear(p,28) and enemy_hp<.3: c+=.18
	if gear(p,52) and hp<.5: c+=.12
	if engraving(p,1) and enemy_hp>=.9: c+=.14
	if engraving(p,2) and enemy_hp<.6: c+=.10
	if engraving(p,3) and hp>=.8: c+=.10
	if engraving(p,4) and mp<=.3: c+=.12
	if engraving(p,15) and spell and mp>=.75: c+=.12
	if engraving(p,17) and e.get("rogue_guardian",false): c+=.12
	if engraving(p,18) and enemy_hp<=.25: c+=.16
	if engraving(p,19) and hp<=.4: c+=.14
	if buff(p,"perfect_haste",s.elapsed)>0: c+=.12
	var w: int=int(ctx.get("weapon",weapon_id(p)))
	if normal:
		if w==5 and buff(p,"dodge_window",s.elapsed)>0: c+=.16
		if w==6 and fire>0: c+=.10
		if w==9 and hp<.5: c+=.14
		if w==13 and enemy_hp>=.9: c+=.12
		if w==17 and frost>=3: c+=.15
		if w==22 and distance>=150: c+=.10
		if w==24 and enemy_hp<=.35: c+=.14
		if w==31 and float(p.get("build_stationary",0))>=.8: c+=.12
	var crit: float=.05+s.rogue_equipment_stat(p,"crit")+(.04 if engraving(p,16) and hp>=.5 else 0)+(r(p,21,[.08,.12]) if marked else 0)+(r(p,44,[.04,.06,.08]) if shock>=3 else 0)+(.06 if gear(p,30) and blood>=3 else 0)
	if not ctx.has("crit_targets"): ctx.crit_targets={}
	if not ctx.crit_targets.has(e.id): ctx.crit_targets[e.id]=s.rng.randf()<minf(.35,crit)
	var critical: bool=ctx.crit_targets[e.id]
	ctx["critical"]=critical
	var crit_damage := minf(1.75,1.5+(.1 if gear(p,33) and distance>=220 and normal else 0)) if critical else 1.0
	# Local A is added to A, rather than multiplying a second A pool.
	return (1.0+minf(1.2,s.rogue_damage_pool(p)+local_a))/(1.0+s.rogue_damage_pool(p))*(1.0+minf(.6,c))*penalty*crit_damage

static func consume(e: Dictionary, owner: int, name: String, amount: int) -> void:
	var states: Dictionary=e.get("build_status",{}).get(str(owner),{})
	if states.has(name): states[name].stacks=maxi(0,int(states[name].stacks)-amount)

static func hit_event(s, p: Dictionary, e: Dictionary, actual: float, killed: bool, ctx: Dictionary) -> void:
	if actual<=0 or p.status!="active" or int(ctx.get("depth",0))>0 or e.get("boss_construct",false): return
	var seen: Dictionary=ctx.get("seen",{})
	if seen.has(e.id): return
	seen[e.id]=true
	ctx.seen=seen
	var first: bool=not bool(ctx.get("counted",false))
	ctx.counted=true
	for input in p.build_inputs:
		if input.get("root","")==ctx.get("root","?"): input["hit"]=true
	if first: hero_effect(s,p,e,ctx)
	var normal: bool=ctx.get("kind","")=="attack"
	var art: bool=ctx.get("kind","")=="art"
	var family: int=int(ctx.get("family",0))
	var w: int=int(ctx.get("weapon",0))
	var power: float=float(ctx.get("unit",unit(s,p)))
	var third: bool=int(ctx.get("combo",0))==2 and family==1
	var blood := status(e,p.id,"bleed")
	var fire := status(e,p.id,"burn")
	var shock := status(e,p.id,"shock")
	var marked := status(e,p.id,"mark")>0
	# Only statuses that predate this hit may react.
	reactions(s,p,e,family,power)
	if status(e,p.id,"frost")>=3 and gear(p,10): grant(p,"defense",.08,2,s.elapsed)
	if normal and first:
		p.build_counts["attacks"]=int(p.build_counts.get("attacks",0))+1
		p.build_counts["same"]=int(p.build_counts.get("same",0))+1 if int(p.build_counts.get("target",-1))==int(e.id) else 1
		p.build_counts["target"]=e.id
	var count: int=int(p.build_counts.get("attacks",0))
	if normal:
		if gear(p,1) and ready(s,p,"E001",2): heal(s,p,p,minf(.02,actual*.04/p.max_hp))
		if rank(p,71)>0 and p.hp<p.max_hp*.4 and ready(s,p,"T071",3): heal(s,p,p,r(p,71,[.01,.015]))
		if first and third and rank(p,4)>0 and ready(s,p,"T004",2): mana(s,p,r(p,4,[1,2,3]))
		if first and buff(p,"refund_next",s.elapsed)>0:
			mana(s,p,buff(p,"refund_next",s.elapsed)); p.build_buffs.erase("refund_next")
		if first and buff(p,"spring_echo",s.elapsed)>0:
			proc(s,p,e,buff(p,"spring_echo",s.elapsed),power); p.build_buffs.erase("spring_echo")
		if first and gear(p,14) and p.mana<=p.max_mana*.3 and ready(s,p,"E014",3): mana(s,p,4)
		if third and gear(p,53) and ready(s,p,"E053",3): grant(p,"speed",20,2,s.elapsed)
		if blood>0 and gear(p,54) and ready(s,p,"E054",3): grant(p,"defense",.06,2,s.elapsed)
		if blood>=3 and gear(p,29) and ready(s,p,"E029",4): add_status(s,p,e,"bleed",1,power)
		if gear(p,34) and not marked and ready(s,p,"E034",3): add_status(s,p,e,"mark",1,power)
		if rank(p,20)>0 and ready(s,p,"T020",r(p,20,[4,3.5,3])): add_status(s,p,e,"mark",1,power)
		if first and count%3==0 and rank(p,2)>0 and ready(s,p,"T002",1.5): add_status(s,p,e,"bleed",int(r(p,2,[1,1,2])),power)
		for pair in [[25,"burn"],[33,"frost"],[41,"shock"]]:
			if rank(p,pair[0])>0 and ready(s,p,"T%03d" % pair[0],1): add_status(s,p,e,pair[1],int(r(p,pair[0],[1,1,2])),power)
		if rank(p,8)>0 and int(p.build_counts.get("same",0))%3==0 and ready(s,p,"T008",2): add_status(s,p,e,"bleed",1,power)
		if first and count%4==0:
			if rank(p,61)>0: grant(p,"relay",r(p,61,[.12,.18]),5,s.elapsed)
			if rank(p,64)>0: grant(p,"rotation",1,10,s.elapsed)
			if gear(p,39) and ready(s,p,"E039",2): proc(s,p,e,.18,power)
			if rank(p,46)>0 and ready(s,p,"T046",2):
				for target in nearby(s,p,e,180+r(p,43,[15,25,35])): proc(s,p,target,r(p,46,[.15,.22]),power)
		if first and rank(p,81)>0 and count%5==0 and ready(s,p,"T081",6): summon(s,p,r(p,81,[4,5,6]),.06)
		if first and rank(p,88)>0 and count%4==0 and ready(s,p,"T088",6): summon(s,p,6,.1)
		if marked and rank(p,24)>0 and ready(s,p,"T024",3):
			consume(e,p.id,"mark",1)
			for target in nearby(s,p,e,180): proc(s,p,target,.2,power)
			if core(p,9)>0 and ready(s,p,"WC009-mark",4):
				mana(s,p,core(p,9)); core_visual(s,p,9,p.p,ctx)
		elif marked: consume(e,p.id,"mark",1)
		if shock>=5 and rank(p,48)>0 and ready(s,p,"T048",4):
			consume(e,p.id,"shock",5); proc(s,p,e,.35,power)
			for target in nearby(s,p,e,180+r(p,43,[15,25,35])): proc(s,p,target,.35,power)
			mana(s,p,r(p,45,[3,5]))
		if buff(p,"dodge_window",s.elapsed)>0:
			if gear(p,11) and ready(s,p,"E011",4): add_status(s,p,e,"shock",2,power)
			if rank(p,47)>0 and ready(s,p,"T047",4): add_status(s,p,e,"shock",int(r(p,47,[1,2])),power)
			if first and gear(p,63) and ready(s,p,"E063",4): proc(s,p,e,.15,power)
			if first and family in [1,2] and rank(p,78)>0 and ready(s,p,"T078",4): proc(s,p,e,r(p,78,[.16,.24]),power)
		if third and core(p,2)>0 and ready(s,p,"WC002",2):
			add_status(s,p,e,"bleed",core(p,2),power); core_visual(s,p,2,e.p,ctx)
		if first and int(ctx.get("route",-1))==0 and family==1: p.p=s.ruins.move(p.p,p.aim*35)
		if first and int(ctx.get("route",-1))==1 and core(p,1)>0:
			p.p=s.ruins.move(p.p,p.aim*(45 if core(p,1)==1 else 60)); core_visual(s,p,1,p.p,ctx)
		if float(ctx.get("height",0))>0:
			if core(p,4)>0:
				add_poise(s,p,e,10 if core(p,4)==1 else 16,power); core_visual(s,p,4,e.p,ctx)
			if core(p,6)>0:
				add_status(s,p,e,"shock",core(p,6),power); core_visual(s,p,6,e.p,ctx)
			if core(p,8)>0 and ready(s,p,"WC008",5):
				add_status(s,p,e,"mark",1,power); core_visual(s,p,8,e.p,ctx)
			if core(p,2)>0 and blood==5 and ready(s,p,"WC002-air",6): consume(e,p.id,"bleed",2); proc(s,p,e,.10 if core(p,2)==1 else .16,power)
		if family==2:
			var poise := (50 if w==20 else 35)+r(p,10,[6,10,14])+(25 if rank(p,16)>0 else 0)+(12 if gear(p,31) else 0)+(10 if engraving(p,9) else 0)
			add_poise(s,p,e,poise,power)
			if rank(p,14)>0: grant(p,"hammer_cost",r(p,14,[.1,.15]),4,s.elapsed)
		else: add_poise(s,p,e,(14 if family==1 else 6)+(3 if engraving(p,9) else 0)+(4 if w==12 else 0)+(20 if w==12 and third else 0),power)
		match w:
			1: if third: add_status(s,p,e,"bleed",1,power)
			4: if count%3==0: add_status(s,p,e,"bleed",2,power)
			7: if ready(s,p,"W007",.8): add_status(s,p,e,"frost",1,power)
			8: if third: add_status(s,p,e,"shock",2,power)
			10: if first and count%4==0 and ready(s,p,"W010",2): proc(s,p,e,.15,power)
			11: if first and buff(p,"art_window",s.elapsed)>0 and ready(s,p,"W011",5): mana(s,p,3)
			16: add_status(s,p,e,"burn",2,power)
			18: if ready(s,p,"W018",1.5): add_status(s,p,e,"shock",2,power)
			19: if blood>=3 and ready(s,p,"W019",2): consume(e,p.id,"bleed",1); proc(s,p,e,.18,power)
			21: if buff(p,"hurt_window",s.elapsed)>0 and ready(s,p,"W021",6): shield(s,p,.04,3)
			25: if buff(p,"reload_window",s.elapsed)>0: add_status(s,p,e,"mark",1,power); p.build_buffs.erase("reload_window")
			27: if int(p.build_counts.get("same",0))%3==0: add_status(s,p,e,"bleed",1,power)
			28,38,43: if ready(s,p,"W-burn",.8 if w!=38 else 1): add_status(s,p,e,"burn",1,power)
			29,39: if ready(s,p,"W-frost",.7 if w==39 else 1): add_status(s,p,e,"frost",1,power)
			30: if count%4==0: add_status(s,p,e,"shock",2,power)
			32: if first and count%5==0 and ready(s,p,"W032",2):
				for target in nearby(s,p,e,150): proc(s,p,target,.20,power)
			35: if first and count%4==0 and ready(s,p,"W035",2): mana(s,p,2)
			37: if first and count%4==0 and ready(s,p,"W037",3): proc(s,p,e,.12,power)
			40: if first: add_status(s,p,e,"shock",1,power)
			46: if ready(s,p,"W046",1): add_status(s,p,e,"bleed",1,power)
			47: if first and int(p.build_counts.get("same",0))%4==0 and ready(s,p,"W047",6): summon(s,p,4,.04)
		if first:
			for pair in [[5,"bleed",4],[6,"burn",3],[7,"frost",3],[8,"shock",3]]:
				if engraving(p,pair[0]) and count%int(pair[2])==0 and ready(s,p,"I%03d" % pair[0],2): add_status(s,p,e,pair[1],1,power)
			if engraving(p,12) and count%4==0 and ready(s,p,"I012",3): mana(s,p,2)
			if engraving(p,24) and count%5==0 and ready(s,p,"I024",3): proc(s,p,e,.15,power)
			if engraving(p,10) and buff(p,"mark_next",s.elapsed)>0 and ready(s,p,"I010",5): add_status(s,p,e,"mark",1,power); p.build_buffs.erase("mark_next")
			if buff(p,"mirror_echo",s.elapsed)>0: proc(s,p,e,.18,power); p.build_buffs.erase("mirror_echo")
			if int(p.build_counts.get("reload_refunds",0))>0:
				mana(s,p,r(p,23,[1,2])); p.build_counts.reload_refunds-=1
			for key in ["dodge_strike","perfect_strike","shield_strike","counter","healed","summon_strike","reload_strike","art_strike","landing_strike","landing_cost"]: p.build_buffs.erase(key)
	if art:
		add_poise(s,p,e,20,power)
		if first:
			var refunded_before := float(ctx.refunded)
			refund(s,p,ctx,r(p,59,[.08,.12,.16])+(.1 if engraving(p,13) else 0)+(buff(p,"combo_refund",s.elapsed)))
			if core(p,9)>0 and float(ctx.refunded)>refunded_before and buff(p,"combo_refund",s.elapsed)>0: core_visual(s,p,9,p.p,ctx)
			if rank(p,62)>0 and ready(s,p,"T062",6): proc(s,p,e,r(p,62,[.16,.24]),power)
			if gear(p,48) and ready(s,p,"E048",5): mana(s,p,2)
			for ally in s.players.values():
				if ally.id!=p.id and ally.status=="active" and ally.p.distance_to(p.p)<=240 and gear(ally,48) and ready(s,ally,"E048",5): mana(s,ally,2)
			if e.hp<=e.max_hp*.3 and rank(p,63)>0: p.art_cd=maxf(0,p.art_cd-minf(float(p.get("build_art_base",5))*.15,r(p,63,[.4,.7])))
			if w==23:
				proc(s,p,e,.08*int(p.build_counts.get("souls",0)),power); p.build_counts.souls=0
			if w==36 and ready(s,p,"W036",8):
				shield(s,p,.03,3)
				var ally := lowest(s,p,220,true)
				if not ally.is_empty(): shield(s,ally,.03,3)
			if w==48 and ready(s,p,"W048",8): heal(s,p,p,.02)
			if core(p,5)>0 and ready(s,p,"WC005",8):
				shield(s,p,.03 if core(p,5)==1 else .05,3); grant(p,"art_strike",.06 if core(p,5)==1 else .10,3,s.elapsed); core_visual(s,p,5,p.p,ctx)
			if core(p,11)>0 and float(ctx.height)>0 and ready(s,p,"WC011",6):
				add_status(s,p,e,"frost",core(p,11),power); core_visual(s,p,11,e.p,ctx)
			if rank(p,32)>0 and fire>=3 and ready(s,p,"T032",6): field(p,e.p,3,90,.08,power)
		if blood==5 and rank(p,6)>0 and ready(s,p,"T006",4): consume(e,p.id,"bleed",3); proc(s,p,e,r(p,6,[.30,.40]),power)

	if e.get("rogue_guardian",false):
		if normal and gear(p,51) and ready(s,p,"E051-boss",8): mana(s,p,4)
		if gear(p,20) and ready(s,p,"E020-boss",10): shield(s,p,.04,4)

static func add_poise(s, p: Dictionary, e: Dictionary, amount: float, power: float) -> void:
	if e.hp<=0 or s.elapsed<float(e.get("build_break_until",0)): return
	e["build_poise"]=float(e.get("build_poise",0))+minf(90,amount)
	var threshold := 240 if e.get("rogue_guardian",false) else 160 if e.get("build_elite",false) else 100
	if e.build_poise<threshold: return
	e.build_poise=0.0
	e["build_break_time"]=2.0
	e["build_break_until"]=s.elapsed+12.0
	if not e.get("rogue_guardian",false): e.stagger=maxf(float(e.get("stagger",0)),.8)
	if gear(p,32) and ready(s,p,"E032",10): shield(s,p,.06,4)
	if rank(p,16)>0 and ready(s,p,"T016",12): mana(s,p,6)

static func reactions(s, p: Dictionary, e: Dictionary, family: int, power: float, broken: bool = false) -> void:
	if e.hp<=0: return
	if rank(p,7)>0 and status(e,p.id,"bleed")>=3 and status(e,p.id,"burn")>=3 and ready(s,p,"bloodfire",4):
		consume(e,p.id,"bleed",3); consume(e,p.id,"burn",3)
		proc(s,p,e,r(p,7,[.25,.32]),power)
		for target in nearby(s,p,e,100,2): proc(s,p,target,r(p,7,[.25,.32]),power)
	if rank(p,31)>0 and status(e,p.id,"burn")>=3 and status(e,p.id,"frost")>=3 and ready(s,p,"frostfire",3):
		consume(e,p.id,"burn",3); consume(e,p.id,"frost",3)
		proc(s,p,e,r(p,31,[.45,.55])*(1+(.08 if core(p,11)==1 else .12 if core(p,11)==2 else 0)),power)
		if rank(p,39)>0 and ready(s,p,"T039",4): shield(s,p,r(p,39,[.04,.06]),3,"T039")
	if rank(p,15)>0 and family==2 and status(e,p.id,"shock")>=3 and ready(s,p,"thunderbreak",3):
		consume(e,p.id,"shock",3)
		proc(s,p,e,r(p,15,[.35,.45])*(1+(.08 if core(p,6)==1 else .12 if core(p,6)==2 else 0)),power)
		if ready(s,p,"reaction_mana",4): mana(s,p,r(p,45,[3,5])+(4 if gear(p,40) else 0))

static func perfect(s, p: Dictionary) -> void:
	if buff(p,"dodge_age",s.elapsed)<=0 or not ready(s,p,"perfect",3): return
	grant(p,"perfect_strike",(.18 if gear(p,70) else 0),2,s.elapsed)
	if rank(p,76)>0 and ready(s,p,"T076",4): mana(s,p,r(p,76,[2,3,4]))
	if rank(p,77)>0 and ready(s,p,"T077",5): shield(s,p,r(p,77,[.04,.06]),3,"T077")
	if core(p,3)>0 and ready(s,p,"WC003",5):
		mana(s,p,core(p,3)); core_visual(s,p,3,p.p)
	if rank(p,80)>0: grant(p,"haste",.25,3,s.elapsed); grant(p,"perfect_haste",1,3,s.elapsed)
	p.build_combo_label="完美闪避"
	p.build_combo_time=1.2

static func incoming(s, p: Dictionary, amount: float, source: Dictionary, tag: String, element: String = "physical") -> float:
	if tag=="direct" and rank(p,72)>0 and ready(s,p,"T072",8): shield(s,p,.1,4,"T072")
	if tag=="direct" and gear(p,16) and ready(s,p,"E016",8): amount*=.88
	var absorb_ratio := .20 if gear(p,3) else 0.0
	if absorb_ratio>0:
		var absorbed := minf(p.mana,amount*minf(.3,absorb_ratio))
		p.mana-=absorbed; amount-=absorbed
		if absorbed>0: p.mana_delay=s.MANA_REGEN_DELAY
	var before := amount
	var shielded := minf(amount,float(p.get("build_shield",0)))
	p.build_shield=maxf(0,float(p.get("build_shield",0))-shielded)
	var remaining := shielded
	for key in p.get("build_shields",{}):
		var taken := minf(remaining,float(p.build_shields[key].amount))
		p.build_shields[key].amount-=taken; remaining-=taken
	amount-=shielded
	if shielded>0 and tag=="direct" and rank(p,69)>0 and ready(s,p,"T069",5): grant(p,"counter",r(p,69,[.12,.18]),3,s.elapsed)
	if amount>0:
		p.build_last_hurt=s.elapsed
		grant(p,"hurt_window",1,4,s.elapsed)
		if gear(p,6) and amount>=p.max_hp*.08 and ready(s,p,"E006",8): grant(p,"counter",.2,4,s.elapsed)
		if element=="lightning" and gear(p,12) and ready(s,p,"E012",8): shield(s,p,.05,4,"E012")
		if tag=="direct" and rank(p,70)>0 and amount>=p.max_hp*.04 and not source.is_empty() and source.p.distance_to(p.p)<=400 and s.ruins.clear_line(p.p,source.p) and ready(s,p,"T070",3): proc(s,p,source,r(p,70,[.16,.24]))
	if before>0: p.flask_time=0.0; p["flask_pending_commit"]=false
	return amount

static func action_event(s, p: Dictionary, token: String) -> void:
	var family := Catalog.weapon_family(int(p.weapon))
	var now: float=s.elapsed
	var sequence: Array=p.get("build_inputs",[])
	var window := maxf(.45,float(Catalog.weapon(int(p.weapon)).rate)+.35)
	if not sequence.is_empty() and now-float(sequence.back().time)>window: sequence=[]
	# A defensive cancel remains legal, but a canceled/missed A cannot grant a combo.
	for input in sequence:
		if input.key=="A" and not input.get("hit",false): sequence=[]; break
	var movement: Vector2=s.inputs.get(p.id,{}).get("move",Vector2.ZERO)
	if token=="S" and movement.normalized().dot(p.aim)>.6:
		if now-float(p.get("build_back_time",-10))<=.6: sequence.append({"key":"<","time":now,"hit":true})
		sequence.append({"key":">","time":now,"hit":true})
	sequence.append({"key":token,"time":now,"hit":token!="A","root":""})
	if sequence.size()>10: sequence.pop_front()
	p.build_inputs=sequence
	var keys := ""
	for input in sequence: keys+=str(input.key)
	var route_index: int=[1,2,0,3].find(family)
	var level := forge_level(p)
	p["build_next_route"]=-1; p["build_next_hero"]=-1
	if token=="D":
		grant(p,"dodge_window",1,2,now)
		grant(p,"dodge_age",1,.12,now)
		var bonus: float=r(p,75,[.08,.12,.16])+(.12 if engraving(p,20) else 0)+(.08 if core(p,1)==1 or core(p,7)==1 else .12 if core(p,1)==2 or core(p,7)==2 else 0)
		grant(p,"dodge_strike",bonus,2,now)
		if gear(p,18): grant(p,"speed",18,2,now)
		if gear(p,60) and ready(s,p,"E060",4): field(p,p.p,2,50,.04,unit(s,p),2)
		if core(p,7)>0:
			grant(p,"reload_haste",.05 if core(p,7)==1 else .08,5,now); core_visual(s,p,7,p.p)
	if token=="S":
		grant(p,"art_window",1,3,now)
		if gear(p,17) and ready(s,p,"E017",6): grant(p,"mirror_echo",1,3,now)
		if gear(p,66) and ready(s,p,"E066",4): grant(p,"speed",24,2,now)
		if engraving(p,21) and ready(s,p,"I021",8): shield(s,p,.04,3)
		if engraving(p,23) and float(p.get("build_last_cost",0))>=12 and ready(s,p,"I023",6): heal(s,p,p,.01)
		grant(p,"mark_next",1,5,now)
	if token=="U":
		if rank(p,94)>0 and ready(s,p,"T094",12):
			for ally in s.players.values():
				if ally.status=="active" and ally.p.distance_to(p.p)<=240: shield(s,ally,r(p,94,[.04,.06]),3)
		if rank(p,86)>0: grant(p,"soul_order",r(p,86,[.12,.18]),3,now)
		if gear(p,46): extend_summons(p,1)
	for i in CM_ROUTES[route_index].size():
		var required: int=[0,1,3,3][i] if family==1 else [0,1,0,3][i]
		if level>=required and keys.ends_with(CM_ROUTES[route_index][i]):
			p.build_next_route=i
			p.build_combo_label=["闪避追击","折返派生","升空 / 跃击","落地连段"][i]
			p.build_combo_time=1.3
	if level>=3 and p.build_hero_cd<=0:
		for i in HC_ROUTES[int(p.hero)].size():
			if keys.ends_with(HC_ROUTES[int(p.hero)][i]): p.build_next_hero=i; break
	if token=="S" and keys.ends_with("AAS") and core(p,9)>0: grant(p,"combo_refund",.05 if core(p,9)==1 else .08,1,now)

static func extend_summons(p: Dictionary, seconds: float) -> void:
	for soul in p.build_summons:
		var gain := minf(seconds,maxf(0,2-float(soul.extended)))
		soul.time=minf(10,float(soul.time)+gain); soul.extended+=gain

static func reload_event(s, p: Dictionary) -> void:
	grant(p,"reload_window",1,5,s.elapsed)
	grant(p,"mark_next",1,5,s.elapsed)
	if gear(p,58) and ready(s,p,"E058",5): grant(p,"reload_strike",.18,2,s.elapsed)
	if rank(p,23)>0 and ready(s,p,"T023",6): p.build_counts["reload_refunds"]=2
	p.build_buffs.erase("reload_haste")

## A2 (R9 hook 7): CU07「破瓶」的血瓶容量。基础容量 100，`flask_max`（CAPS 锁在 [-50,0]）
## 直接削容量，下限 25（正好是"喝一口"的代价，容量再低就永远喝不动了）。
## 所有"补到上限"的入口都必须过这里，否则诅咒只是一句文案。
static func flask_cap(s, p: Dictionary) -> float:
	return clampf(100.0+hook_mod(s,p,"flask_max"),25.0,100.0)

static func drink(s, p: Dictionary) -> bool:
	if p.status!="active" or p.hp>=p.max_hp or p.flask<25 or p.flask_cd>0 or p.flask_time>0 or p.height>0 or p.pending_strike or p.cast_time>0 or p.dodge_time>0: return false
	p.flask_time=.75
	p.flask_cd=2.5
	p.flask_committed=false
	p["flask_pending_commit"]=false
	p.build_inputs=[]
	return true

static func jump(s, p: Dictionary) -> bool:
	if p.status!="active" or p.height>0 or p.jump_cd>0 or p.flask_time>0 or p.cast_time>0 or p.dodge_time>0 or p.pending_strike or p.swing_time>.08: return false
	p.height_velocity=420.0
	p.height=.01
	p.jump_cd=1.2
	p.air_attacks=0
	p.air_art=false
	p.air_dodge=false
	p.swing_time=0.0
	p.attack=maxf(0,p.attack-.08)
	action_event(s,p,"J")
	p["build_landing_time"]=0.0
	return true

static func tick(s, p: Dictionary, dt: float) -> void:
	for key in ["jump_cd","flask_cd","build_hero_cd","build_combo_time","build_shield_time"]: p[key]=maxf(0,float(p.get(key,0))-dt)
	p["build_landing_time"]=maxf(0,float(p.get("build_landing_time",0))-dt)
	# A2 (R9 hook 7): 容量被 CU07「破瓶」削掉后，**当前**血量值也必须跟着降下来，
	# 否则楼层补给 / 事件补给会先把瓶子灌到 100 再被削回去。这里是唯一的逐帧兜底点，
	# 覆盖 `rogue_events.gd:172` 那种直接把 flask 写满的通道。身上没有诅咒时一次都不读，
	# 所以无诅咒路径逐位不变。
	if not p.get("rogue_curses",[]).is_empty(): p.flask=minf(p.flask,flask_cap(s,p))
	for key in p.get("build_shields",{}).keys():
		p.build_shields[key].time-=dt
		if p.build_shields[key].time<=0 or p.build_shields[key].amount<=0: p.build_shields.erase(key)
	p.build_shield=0.0
	for source in p.get("build_shields",{}).values(): p.build_shield+=float(source.amount)
	if p.status=="down":
		p.flask_time=0.0; p.height=0.0; p.height_velocity=0.0
		var cmd: Dictionary=s.inputs.get(p.id,{})
		if p.soul_lamp and bool(cmd.get("flask_held",false)):
			p.lamp_time+=dt
			if p.lamp_time>=2:
				p.soul_lamp=false; p.lamp_time=0.0; p.status="active"; p.hp=p.max_hp*.25; p.invuln=1.5
		else: p.lamp_time=0.0
		return
	if p.status!="active": return
	if p.hp<=0:
		p.flask_time=0.0
		p["flask_pending_commit"]=false
		return
	if p.flask_time>0:
		p.flask_time=maxf(0,p.flask_time-dt)
		if p.flask_time<=.3 and not p.flask_committed:
			p["flask_pending_commit"]=true
	if p.height>0 or p.height_velocity>0:
		# Integrate the ballistic arc exactly, so apex/airtime are frame independent.
		p.height+=p.height_velocity*dt-600*dt*dt
		p.height_velocity-=1200*dt
		if p.height<=0:
			p.height=0.0; p.height_velocity=0.0
			p.attack=maxf(p.attack,.25 if Catalog.weapon_family(int(p.weapon))==2 and p.air_attacks>0 else .12)
			p.build_landing_time=.18
			if core(p,3)>0:
				grant(p,"landing_strike",.08 if core(p,3)==1 else .12,2,s.elapsed); core_visual(s,p,3,p.p)
			if core(p,10)>0 and p.air_attacks>0:
				grant(p,"landing_cost",.08 if core(p,10)==1 else .12,2,s.elapsed); core_visual(s,p,10,p.p)
	var move: Vector2=s.inputs.get(p.id,{}).get("move",Vector2.ZERO)
	if move.normalized().dot(p.aim)<-.6: p["build_back_time"]=s.elapsed
	p.build_stationary=float(p.get("build_stationary",0))+dt if move.length()<.1 and p.dodge_time<=0 else 0.0
	var dodge_active: bool=p.dodge_time>0
	if p.get("build_was_dodging",false) and not dodge_active and gear(p,67) and ready(s,p,"E067",6): shield(s,p,.04,2,"E067")
	p["build_was_dodging"]=dodge_active
	if gear(p,72):
		for ally in s.players.values():
			if ally.id!=p.id and ally.status=="down" and ally.p.distance_to(p.p)<=300 and move.normalized().dot((ally.p-p.p).normalized())>.6: grant(p,"speed",25,.1,s.elapsed); break
	if gear(p,68) and s.elapsed-p.build_last_hurt>=6 and ready(s,p,"E068",6): heal(s,p,p,.01)
	for i in range(p.build_summons.size()-1,-1,-1):
		var soul: Dictionary=p.build_summons[i]
		soul.p=s.ruins.move(soul.p,(p.p-soul.p).limit_length((125 if gear(p,71) else 100)*dt),8)
		soul.time-=dt; soul.clock+=dt
		if soul.time<=0:
			p.build_summons.remove_at(i)
			if rank(p,84)>0 and ready(s,p,"T084",5): mana(s,p,r(p,84,[1,2,3]))
			continue
		if soul.clock>=1:
			soul.clock-=1
			var targets: Array=[]
			for e in s.enemies:
				if e.hp>0 and not e.get("boss_construct",false) and e.p.distance_to(soul.p)<=450 and s.ruins.clear_line(soul.p,e.p): targets.append(e)
			targets.sort_custom(func(a,b):
				if buff(p,"soul_target",s.elapsed)>0:
					if a.id==int(buff(p,"soul_target",s.elapsed)): return true
					if b.id==int(buff(p,"soul_target",s.elapsed)): return false
				return a.p.distance_squared_to(soul.p)<b.p.distance_squared_to(soul.p))
			if not targets.is_empty():
				var pool := minf(.4,r(p,82,[.08,.12,.16])+(.1 if gear(p,45) else 0)+(.08 if engraving(p,22) else 0)+(.04 if core(p,12)==1 else .08 if core(p,12)==2 else 0)+buff(p,"soul_order",s.elapsed))
				var total := 0.0
				for entity in p.build_summons: total+=float(entity.ratio)
				proc(s,p,targets[0],float(soul.ratio)*minf(1,.16/maxf(.001,total))*(1+pool),float(soul.power),"summon")
				if rank(p,85)>0 and ready(s,p,"T085",3): grant(p,"summon_strike",r(p,85,[.08,.12]),3,s.elapsed)
	for i in range(p.build_fields.size()-1,-1,-1):
		var zone: Dictionary=p.build_fields[i]
		var active_dt := minf(dt,maxf(0,float(zone.time)))
		zone.clock+=active_dt; zone.time-=dt
		while zone.clock>=.5:
			zone.clock-=.5
			var count := 0
			for e in s.enemies:
				if count>=int(zone.count): break
				if e.hp>0 and e.p.distance_to(zone.p)<=float(zone.radius) and s.ruins.clear_line(zone.p,e.p):
					proc(s,p,e,float(zone.ratio)*.5,float(zone.power),"field"); count+=1
		if zone.time<=0: p.build_fields.remove_at(i)

static func tick_enemies(s, dt: float) -> void:
	for e in s.enemies:
		e["build_poise"]=maxf(0,float(e.get("build_poise",0))-12*dt)
		if float(e.get("build_air_time",0))>0:
			e.build_air_time=maxf(0,float(e.build_air_time)-dt)
			if e.build_air_time<=0: e.height=0.0
		e["build_break_time"]=maxf(0,float(e.get("build_break_time",0))-dt)
		for owner in e.get("build_status",{}):
			var states: Dictionary=e.build_status[owner]
			var p: Dictionary=s.players.get(int(owner),{})
			for name in states.keys():
				var state: Dictionary=states[name]
				var active_dt := minf(dt,maxf(0,float(state.time)))
				state.time-=dt
				if not p.is_empty() and p.status=="active" and name in ["bleed","burn"] and int(state.stacks)>0:
					state.clock+=active_dt
					while float(state.clock)>=.5 and e.hp>0:
						state.clock-=.5
						var ratio := (.025 if name=="bleed" else .02)*int(state.stacks)*.5
						if name=="bleed" and rank(p,8)>0: ratio*=1.4
						if name=="burn" and rank(p,32)>0: ratio*=1.5
						proc(s,p,e,ratio,float(state.power),"dot")
						if name=="bleed" and rank(p,5)>0 and ready(s,p,"T005",6): shield(s,p,r(p,5,[.03,.05]),3,"T005")
						if name=="burn" and rank(p,30)>0 and ready(s,p,"T030",4): heal(s,p,p,r(p,30,[.01,.015]))
				if state.time<=0 or int(state.stacks)<=0: states.erase(name)

static func talent_cost(p: Dictionary) -> int:
	var cost := 0
	for id in p.get("build_talents",{}): cost+=int(p.build_talents[id])*int(Content.entry(id).get("cost",1))
	return cost

static func legal_talents(talents: Dictionary, budget: int) -> bool:
	if talents.size()>8: return false
	var cost := 0
	var cores := 0
	for id in talents:
		var entry := Content.entry(id)
		var level := int(talents[id])
		if entry.is_empty() or not id.begins_with("T") or level<1 or level>int(entry.max_rank): return false
		cost+=level*int(entry.cost)
		if entry.category=="K": cores+=1
		if entry.category!="N":
			var basic := 0
			var investment := 0
			for other in talents:
				var def := Content.entry(other)
				if def.school==entry.school and def.category!="K":
					investment+=int(talents[other])
					if def.category=="N": basic+=1
			if (entry.category=="A" and basic<1) or (entry.category=="K" and investment<2): return false
	return cores<=1 and cost<=mini(18,budget)

static func activate(s, p: Dictionary, id: String, delta: int) -> bool:
	if id not in p.build_library or delta not in [-1,1] or not safe(s,p): return false
	var proposed: Dictionary=p.build_talents.duplicate(true)
	var level := int(proposed.get(id,0))+delta
	if level<0: return false
	if level==0: proposed.erase(id)
	else: proposed[id]=level
	# Removing a prerequisite returns dependent ranks to the unspent budget.
	if delta<0:
		for dependent in proposed.keys():
			var def := Content.entry(dependent)
			if def.category=="N": continue
			var test: Dictionary={}
			for other in proposed:
				if Content.entry(other).school==def.school: test[other]=proposed[other]
			if not legal_talents(test,18): proposed.erase(dependent)
	if not legal_talents(proposed,int(p.build_cultivation)): return false
	var hp_grant := 0.0
	if id=="T065" and delta>0:
		var amount: int=[0,12,20,28][level]
		hp_grant=maxf(0,amount-int(p.get("build_vitality_healed",0)))
		p.build_vitality_healed=maxi(amount,int(p.get("build_vitality_healed",0)))
	p.build_talents=proposed
	s.refresh_max_hp(p)
	p.hp=minf(p.max_hp,p.hp+hp_grant*hp_multiplier(p))
	p.rogue_inventory_revision+=1
	return true

static func safe(s, p: Dictionary) -> bool:
	return p.status=="active" and s.raid.phase in ["rogue_prepare","rogue_shop","rogue_shop_reward","rogue_reward","rogue_exit"] and p.height<=0 and p.flask_time<=0 and not s.pending_ultimates.has(p.id) and p.swing_time<=0 and p.dodge_time<=0 and p.cast_time<=0

static func management(s, p: Dictionary, payload: Dictionary) -> bool:
	if int(payload.get("version",-1))!=int(p.rogue_inventory_revision) or not safe(s,p): return false
	var verb := str(payload.get("verb",""))
	var id := str(payload.get("id",""))
	match verb:
		"talent_up", "talent_down": return activate(s,p,id,1 if verb=="talent_up" else -1)
		"forget":
			if id not in p.build_library or p.build_talents.has(id): return false
			p.build_library.erase(id)
		"attribute":
			if id not in WatcherAttributes.KEYS or p.build_attribute_points<=0 or int(attributes(p)[id])>=99: return false
			p.build_attributes[id]=int(p.build_attributes.get(id,0))+1
			p.build_attribute_points-=1; s.refresh_max_hp(p)
		"respec":
			if p.build_respec_floor==int(s.raid.floor): return false
			for key in p.build_attributes: p.build_attribute_points+=int(p.build_attributes[key])
			p.build_attributes={}; p.build_respec_floor=int(s.raid.floor); s.refresh_max_hp(p)
		"forge":
			if p.equipped.weapon.is_empty() or int(p.build_forge_level)>=mini(5,int(s.raid.floor)): return false
			var cost: int=FORGE_COST[int(p.build_forge_level)]
			if p.build_forge_points<cost: return false
			bind_forge(p)
			p.build_forge_points-=cost; p.build_forge_level+=1
		"bind":
			if p.equipped.weapon.is_empty(): return false
			bind_forge(p)
		"core":
			var def := Content.entry(id)
			if forge_level(p)<2 or def.is_empty() or not id.begins_with("WC") or int(def.family)!=Catalog.weapon_family(int(p.weapon)): return false
			p.build_core=id
		"temper":
			if forge_level(p)<3: return false
			if id!="steady" and (id not in ["strength","dexterity","intelligence","arcane"] or str(Catalog.weapon(int(p.weapon)).get("scaling",{}).get(id,"-")) in ["-","S"]): return false
			p.build_temper=id
		"engrave":
			var n := int(payload.get("index",-1))
			if p.equipped.weapon.is_empty() or n<0 or n>=24 or p.rogue_gold<35: return false
			p.rogue_gold-=35; p.equipped.weapon.rogue_id=n
		_:
			return false
	p.rogue_inventory_revision+=1
	return true

static func bind_forge(p: Dictionary) -> void:
	var item: Dictionary=p.equipped.weapon
	if p.build_forge_bound==str(item.get("instance_id","")): return
	p.build_forge_bound=str(item.get("instance_id",""))
	p.build_core=""; p.build_temper=""

static func award(s, p: Dictionary) -> void:
	var key := "%d:%d" % [s.raid.floor,s.raid.area]
	if p.build_awards.has(key): return
	p.build_awards[key]=true
	var floor_index: int=int(s.raid.floor)
	var area: int=int(s.raid.area)
	if area<=3 or (floor_index in [2,3,4] and area==4):
		p.build_cultivation=mini(18,int(p.build_cultivation)+1)
	if s.raid.room=="talent":
		p.build_reward_queue.append("talent")
		p.build_reward_queue.append("talent")
		# R5: the node graph no longer guarantees that floor two's sanctuary sits at area 2,
		# so the flow core is granted in that floor's first sanctuary instead.
		if floor_index==2 and not bool(p.get("build_core_granted",false)):
			p.build_reward_queue.append("core")
			p.build_core_granted=true
	if (floor_index==1 and area==3) or (floor_index in [2,3,4] and area in [2,4]) or (floor_index==5 and area==3): p.build_forge_points+=1
	if s.raid.room in ["combat","elite"]:
		if p.flask_combat_awards<2:
			p.flask_combat_awards+=1; p.flask=minf(flask_cap(s,p),p.flask+10); p.flask_refills+=10
		if s.raid.room=="elite" and not p.flask_elite_award:
			p.flask_elite_award=true; p.flask=minf(flask_cap(s,p),p.flask+5); p.flask_refills+=5
	p.rogue_inventory_revision+=1

## `s` 是可选参数：仅用于 A2 的 `flask_max`（CU07「破瓶」）容量钳制。旧调用方
## （tests 的裸会话）不传 `s` 时容量恒为 100，行为与接线前逐位相同。
static func floor_enter(p: Dictionary, s = null) -> void:
	p.build_chest_attribute_drops=0
	p.flask=minf(flask_cap(s,p),p.flask+50)
	p.mana=minf(p.max_mana,p.mana+p.max_mana*.5)
	p.flask_refills=0
	p.flask_combat_awards=0; p.flask_elite_award=false
	p.flask_shop_floor=0
	p.build_floor_souvenirs=0
	p.build_summons=[]; p.build_fields=[]; p.build_inputs=[]

static func hero_skill(s, p: Dictionary, aim: Vector2) -> void:
	var power := unit(s,p,true)
	var ctx: Dictionary=p.get("build_skill_context",{})
	if ctx.is_empty(): ctx=context(s,p,"skill")
	s.broadcast_combat({"kind":"skill","p":p.p,"aim":aim,"hero":p.hero,"weapon":Catalog.weapon_family(p.weapon),"id":p.id})
	var count := 0
	for e in s.enemies:
		var delta: Vector2=e.p-p.p
		if e.hp<=0 or not s.ruins.clear_line(p.p,e.p) or delta.length()>(260 if p.hero==2 else 420) or (p.hero in [0,3] and delta.normalized().dot(aim)<.2): continue
		if count>=5: break
		var ratio: float=[2.0,.8,1.6,1.2][int(p.hero)]*(1.0 if count==0 else .65)
		s.damage_enemy(e,power*ratio,p.id,delta.normalized(),20,4,-1,ctx)
		count+=1
	if p.hero==1:
		if int(ctx.get("hero_route",-1))==3 and not ctx.get("hero_done",false): hero_effect(s,p,{},ctx)
		for ally in s.players.values():
			if ally.status=="active" and ally.p.distance_to(p.p)<=240: heal(s,p,ally,.12,false); shield(s,ally,.06,4,"Q:%s" % p.id)
	elif p.hero==2: shield(s,p,.08,4,"Q:%s" % p.id)
	elif p.hero==3: field(p,s.ruins.move(p.p,aim*160),4,160,.20,power,5)

static func enemy_budget(s, e: Dictionary) -> void:
	var floor_index := clampi(int(s.raid.floor)-1,0,4)
	var count := mini(4,maxi(1,s.players.size()))
	var boss: bool=e.get("rogue_guardian",false)
	var elite: bool=e.get("build_elite",false)
	var front: bool=e.get("role","front") in ["front","melee","ambush"]
	var base: float=[2600,4600,7200,10200,13800][floor_index] if boss else [150,260,420,620,900][floor_index] if front else [120,210,330,490,710][floor_index]
	# A1 · 成长树 `monster_slaying`（enemy_hp，≤ -20%）与 `iron_constitution`（enemy_damage，≤ -15%）
	# 在这里落地。**必须与 `raid.build_enemy_hp/build_enemy_damage` 分开乘**：
	# 那两个键是反向 rubber-banding（`departure()` 用玩家当前强度反推，clamp 到 [1,2.4]/[1,1.35]），
	# 而成长树是玩家**永久**投入。若把成长折进 rubber-band 的输入，`pow(damage,0.8)` 会把
	# 「变强」同时变成「怪更肉」，形成越买越难的负反馈（见报告 §3 的复核）。
	# 分开乘 = rubber-band 只看当场的构筑/装备强度，成长树永远是玩家净赚。
	# 成长树为 0 时两个 hook 都是 0.0，乘数恒为 1.0，出厂数值逐位不变。
	var growth_enemy_hp := 1.0+clampf(hook_mod(s,e,"enemy_hp"),-0.95,0.0)
	var growth_enemy_damage := 1.0+clampf(hook_mod(s,e,"enemy_damage"),-0.95,0.0)
	e.hp=base*(1+(count-1)*(.85 if boss else .75 if elite else .65))*(1.8 if elite else 1.0)*float(s.raid.get("build_enemy_hp",1))*growth_enemy_hp
	e.max_hp=e.hp
	e["build_damage_scale"]=float(s.raid.get("build_enemy_damage",1))*growth_enemy_damage
	e["build_base_damage"]=[24,30,37,45,54][floor_index]

static func departure(s) -> void:
	var damage := 0.0
	var health := 0.0
	for p in s.players.values():
		var basic: Dictionary=p.duplicate(true)
		basic.attributes={}
		basic.talents=[0,0,0]
		basic.home_meal=""
		damage+=s.weapon_damage(p)/maxf(1,s.weapon_damage(basic))
		health+=(p.max_hp/maxf(1,s.stat_max_hp(basic)))*(1.0-s.stat_defense(basic))/maxf(.01,1.0-s.stat_defense(p))
	var count := maxi(1,s.players.size())
	s.raid["build_enemy_hp"]=clampf(pow(damage/count,.8),1,2.4)
	s.raid["build_enemy_damage"]=clampf(pow(health/count,.25),1,1.35)

static func hero_effect(s, p: Dictionary, e: Dictionary, ctx: Dictionary) -> void:
	var index := int(ctx.get("hero_route",-1))
	if index<0 or ctx.get("hero_done",false) or p.build_hero_cd>0 or forge_level(p)<3: return
	ctx["hero_done"]=true
	# A2 (R9 hook 8): CU09「迟滞」的技能冷却 +25%。这里与 `rogue_actions.gd` 的 `p.art_cd`
	# 是同一份诅咒的两处消费点（连招技 / 武器技）；无诅咒时乘数恒为 1.0。
	p.build_hero_cd=8.0*(1.0+maxf(0.0,hook_mod(s,p,"cooldown")))
	var high: bool=forge_level(p)>=5
	var names: Array=[
		["红莲追影","升月归庭","赤羽落星","红莲月华接续"],
		["霜花祷步","晨钟悬光","圣刃回声","拂晓归誓"],
		["黑翼断庭","夜鸦返罪","羽幕定裁","夜鸦断罪终式"],
		["冥火牵星","葬月回镰","幽羽点名","冥庭剑雨终式"]]
	p.build_combo_label=names[int(p.hero)][index]; p.build_combo_time=1.8
	s.broadcast_combat({"kind":"hero_combo","p":p.p,"aim":p.aim,"id":p.id,"hero":int(p.hero),"weapon_index":int(p.weapon),"hero_route":index,"height":float(p.get("height",0))})
	var power: float=float(ctx.get("unit",unit(s,p,index==3)))
	match int(p.hero):
		0:
			if index in [0,1]: proc(s,p,e,.16 if high else .12,power)
			elif index==2: add_status(s,p,e,"bleed",2 if high else 1,power)
			else: proc(s,p,e,.20 if high else .16,power)
		1:
			if index==0: add_status(s,p,e,"frost",2 if high else 1,power)
			elif index==1:
				shield(s,p,.03 if high else .02,3)
				var ally := lowest(s,p,240,true)
				if not ally.is_empty(): shield(s,ally,.03 if high else .02,3)
			elif index==2: proc(s,p,e,.14 if high else .10,power)
			else:
				for ally in s.players.values():
					if ally.status=="active" and ally.p.distance_to(p.p)<=240: heal(s,p,ally,.02 if high else .01,false)
		2:
			if index==0: add_poise(s,p,e,16 if high else 10,power)
			elif index==1: proc(s,p,e,.16 if high else .12,power)
			elif index==2: shield(s,p,.04 if high else .03,3)
			else: proc(s,p,e,.20 if high else .16,power)
		3:
			if index in [0,3]:
				proc(s,p,e,(.20 if high else .16) if index==3 else (.14 if high else .10),power)
				grant(p,"soul_target",float(e.id),3,s.elapsed)
			elif index==1: add_status(s,p,e,"bleed",2 if high else 1,power)
			else:
				add_status(s,p,e,"mark",1,power)
				var mark: Dictionary=e.get("build_status",{}).get(str(p.id),{}).get("mark",{})
				if not mark.is_empty(): mark.time=5.0 if high else 4.0
	if core(p,12)>0:
		extend_summons(p,.5 if core(p,12)==1 else 1)
		if not p.build_summons.is_empty(): core_visual(s,p,12,p.p,ctx)

static func xp_needed(level: int) -> int:
	return 40+15*(maxi(1,level)-1)

static func add_experience(s, p: Dictionary, amount: int) -> void:
	if amount<=0: return
	p.build_xp+=amount; p.build_xp_total+=amount
	var gained := 0
	while p.build_xp>=xp_needed(int(p.build_level)):
		p.build_xp-=xp_needed(int(p.build_level))
		p.build_level+=1; p.build_attribute_points+=2; gained+=2
	if gained>0:
		p.rogue_inventory_revision+=1
		if p.id==s.my_id(): s.message.emit("局内等级升至 %d · 属性点 +%d · Tab → 构筑 → 七属性" % [p.build_level,gained])

static func enemy_experience(s, e: Dictionary) -> void:
	# Only original encounter enemies carry XP. Summons/constructs cannot be farmed.
	if e.hp>0 or e.get("build_xp_awarded",false) or e.get("rogue_summoned",false) or e.get("boss_construct",false) or e.get("build_no_rewards",false): return
	var amount := int(e.get("build_xp_reward",0))
	if amount<=0: return
	# A1 · 成长树 `scholar`（xp_gain，≤ +50%）与变数 `famine`/`starlight` 的同一个键，都在
	# **获得经验的那一刻**落地，而且**只在这里落地一次**：`e.build_xp_reward` 是刷怪时写入的
	# **基础值**（`roguelike.gd:383` 的 boss 分支与 `roguelike.gd:450` 的杂兵分支不再预乘），它是"这只怪值多少经验"的声明，也是随敌人
	# 进快照的字段，但它本身不是入账；真正决定 `build_xp_total`/等级/属性点的入口就是下面的
	# `add_experience()`。
	# 2026-06 修复：此前刷怪侧与这里**各乘了一次同一份** `(1+xp_gain)`，正增益被平方放大
	# （+40% 实际 ×1.96），而负增益（`famine` -20%）因为旧代码这里的 `maxf(0.0,·)` 只有刷怪侧
	# 生效过一次。两处合一后正负增益都严格线性一次；`maxf(0.0,·)` 必须一并移除，否则删掉预乘
	# 会把「饥荒」的 -20% 悄悄变成 0%。`amount` 仍有 `maxi(1,·)` 兜底，XP 永远不会变负或归零。
	# `xp_gain` 与 `gold` 一样是**全队**加成：它不是诅咒键，`session.rogue_mods()` 里只有成长树
	# 与变数会产出它，所以与队伍里是谁打死怪无关。
	# 键为 0 时乘数恒为 1.0（`is_equal_approx` 守卫），出厂的 `build_xp` 逐位不变（无 profile
	# 通道即旧行为）。
	var holder: Dictionary = {}
	for ally in s.players.values():
		holder = ally
		break
	var xp_scale := 1.0+hook_mod(s,holder,"xp_gain")
	if not is_equal_approx(xp_scale,1.0): amount=maxi(1,int(round(float(amount)*xp_scale)))
	e["build_xp_awarded"]=true
	for ally in s.players.values():
		if ally.connected and ally.status in ["active","down"]: add_experience(s,ally,amount)

static func killed(s, p: Dictionary, e: Dictionary) -> void:
	if e.get("boss_construct",false) or e.get("rogue_summoned",false) or e.get("build_no_rewards",false) or e.get("build_last_kind","") not in ["attack","art","skill","dot"] or p.status!="active": return
	var power := unit(s,p)
	if weapon_id(p)==23: p.build_counts["souls"]=mini(3,int(p.build_counts.get("souls",0))+1)
	if gear(p,51) and ready(s,p,"E051",2): mana(s,p,4)
	if gear(p,20) and ready(s,p,"E020",6): shield(s,p,.04,4,"E020")
	if status(e,p.id,"burn")>0:
		if gear(p,36) and ready(s,p,"E036",4): field(p,e.p,2,90,.06,power)
		if rank(p,29)>0 and ready(s,p,"T029",3):
			for target in nearby(s,p,e,140,2): add_status(s,p,target,"burn",int(r(p,29,[1,2])),power)
	if p.build_floor_souvenirs<3 and s.rng.randf()<minf(.2,.1*s.stat_discovery(p)/100.0):
		p.build_floor_souvenirs+=1; p.build_souvenirs+=1

static func commit_flask(s, p: Dictionary) -> void:
	# Resolve enemy collisions first. Same-frame lethal damage/cancellation wins over drinking.
	if not p.get("flask_pending_commit",false): return
	p.flask_pending_commit=false
	if p.status!="active" or p.hp<=0 or p.flask_committed or p.flask<25: return
	p.flask_committed=true; p.flask=maxf(0,p.flask-25)
	var amp: float=(.15 if gear(p,22) and s.players.size()==1 else 0)+r(p,92,[.05,.08,.12])*(1 if s.players.size()==1 else 0)+(.1 if gear(p,47) else 0)+(.1 if rank(p,96)>0 else 0)
	# A2 (R9 hook 6b): 血瓶这一笔是魔境里最大的一笔治疗（30% 上限生命），它**不走** `heal()`，
	# 所以必须在这里单独吃 `heal_scale`（CU06「干涸」/ CU10「碎盾」），否则"治疗效果 -30%"
	# 对最主要的治疗来源完全无效。无诅咒时乘数恒为 1.0，`tests/rogue_build_system.gd` 与
	# `tests/rogue_build_rules.gd` 的 `hp==20+max_hp*0.3` 逐位不变。
	var curse_heal := maxf(0.0,1.0+hook_mod(s,p,"heal_scale"))
	p.hp=minf(p.max_hp,p.hp+p.max_hp*.3*(1+minf(.3,amp))*curse_heal)
	s.broadcast_audio("heal",p)
	p.rogue_inventory_revision+=1
