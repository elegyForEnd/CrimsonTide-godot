extends RefCounted
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")

static func height_hit(player_height: float, tag: String) -> bool:
	match tag:
		"low": return player_height<=24
		"ground": return player_height<=12
		"high": return player_height>=30 and player_height<=140
		"all": return player_height<=200
	return player_height<=100

static func start_art(s, p: Dictionary) -> bool:
	if not s.authority() or p.status!="active" or s.raid.phase!="rogue_combat" or p.art_cd>0 or p.reload>0 or p.swing_time>0 or p.attack>0 or p.cast_time>0 or p.dodge_time>0 or p.flask_time>0 or (p.height>0 and p.air_art) or s.pending_ultimates.has(p.id): return false
	var move: Dictionary=WeaponArts.of(int(p.weapon)).duplicate(true)
	var family := Catalog.weapon_family(int(p.weapon))
	var cost := Build.mana_cost(s,p,float(move.mana),"art")
	if not s.spend_mana(p,cost): return false
	p.art_cd=maxf(3,float(move.cooldown)*(1.0-Build.stat(s,p,"art_cdr"))*(1.15 if Build.rank(p,64)>0 else 1.0))
	p["build_art_base"]=p.art_cd
	Build.action_event(s,p,"S")
	var ctx := Build.context(s,p,"art")
	var windup: float={1:.35,2:.5,0:.30,3:.45}.get(family,.35)
	if p.height>0:
		p.air_art=true
		if Build.core(p,10)>0: windup=maxf(.25,windup*(.95 if Build.core(p,10)==1 else .92))
	if Build.buff(p,"dodge_window",s.elapsed)>0: windup=maxf(.25,windup*(1-Build.r(p,79,[.1,.15])))
	var route: int=int(ctx.get("route",-1))
	if route==1 and family==2: move.kind="cone"; move.reach=240.0; move.radius=float(move.get("radius",170))*.8
	if route==2 and family==1: move.kind="thrust"; move.reach=200.0
	if route==3 and family==0 and p.height>35: windup=maxf(windup,.35)
	var split: bool=(family in [1,2,3] and route in [2,3]) or int(ctx.get("hero_route",-1))==0 and p.hero==2
	p["build_pending_art"]={"move":move,"ctx":ctx,"aim":p.aim.normalized(),"origin":p.p,"damage":s.weapon_damage(p)*float(move.damage),"remaining":windup,"split":split}
	p.cast_time=windup+(.35 if split else .12)
	p.attack=p.cast_time
	p.swing_time=p.cast_time
	p.swing_total=p.cast_time
	p.strike_aim=p.aim.normalized()
	p.pending_strike=false
	s.broadcast_combat({"kind":"windup","p":p.p,"aim":p.aim,"weapon":family,"weapon_index":p.weapon,"windup":windup,"id":p.id,"combo":2})
	for key in ["hammer_cost","rotation","relay"]: p.build_buffs.erase(key)
	return true

static func tick(s, p: Dictionary, dt: float) -> void:
	if not p.has("build_pending_art"): return
	var pending: Dictionary=p.build_pending_art
	if p.status!="active" or p.dodge_time>0 or p.cast_time<=0:
		p.erase("build_pending_art")
		return
	pending.remaining-=dt
	if pending.remaining>0: return
	if int(pending.ctx.get("route",-1))==3 and int(pending.ctx.family) in [0,1,2] and p.height>35: return
	p.erase("build_pending_art")
	var ratio := .7 if pending.split else 1.0
	resolve_art(s,p,pending,ratio)
	if not pending.split: p.swing_time=minf(p.swing_time,.12)
	if pending.split:
		p["build_pending_art_tail"]={"remaining":.24,"pending":pending}

static func tail(s, p: Dictionary, dt: float) -> void:
	if not p.has("build_pending_art_tail"): return
	var data: Dictionary=p.build_pending_art_tail
	if p.status!="active": p.erase("build_pending_art_tail"); return
	data.remaining-=dt
	if data.remaining>0 or p.height>0: return
	p.erase("build_pending_art_tail")
	resolve_art(s,p,data.pending,.3)

static func aim_point(s, p: Dictionary, aim: Vector2, reach: float) -> Vector2:
	var requested: Variant=s.inputs.get(p.id,{}).get("aim_point",null)
	if requested is Vector2: return s.ruins.move(p.p,(requested-p.p).limit_length(reach),8)
	var distance := reach
	for e in s.enemies:
		var delta: Vector2=e.p-p.p
		if e.hp>0 and delta.normalized().dot(aim)>.8 and delta.length()<distance: distance=delta.length()
	return s.ruins.move(p.p,aim*distance,8)

static func ordered_targets(s, origin: Vector2) -> Array:
	var targets: Array=s.enemies.duplicate()
	targets.sort_custom(func(a,b): return a.p.distance_squared_to(origin)<b.p.distance_squared_to(origin))
	return targets

static func projectile(s, p: Dictionary, aim: Vector2, damage: float, reach: float, spell: String, ctx: Dictionary, pierce: int = 1, attenuation: Array = [], pellets: Dictionary = {}) -> void:
	var speed := float(Catalog.weapon(int(p.weapon)).get("speed",850))
	var shot := {"p":p.p+aim*23,"v":aim*speed,"life":reach/speed,"damage":damage,"owner":p.id,"weapon":int(ctx.family),"weapon_index":int(p.weapon),"spell":spell,"knock":float(Catalog.weapon(int(p.weapon)).knock),"remaining":pierce,"hit_ids":[],"build_context":ctx,"build_attenuation":attenuation,"height":float(p.height),"height_velocity":(20-float(p.height))/maxf(.1,reach/speed)}
	if spell=="scatter": shot["pellet_hits"]=pellets
	shot["ground_origin"]=p.p
	s.bullets.append(shot)

static func resolve_art(s, p: Dictionary, pending: Dictionary, share: float) -> void:
	var move: Dictionary=pending.move
	var ctx: Dictionary=pending.ctx
	var family: int=int(ctx.family)
	var kind: String=move.kind
	var aim: Vector2=pending.aim
	var damage: float=float(pending.damage)*share
	var spell: String=move.get("spell","star")
	var reach: float=move.reach
	s.broadcast_combat({"kind":"strike","p":p.p,"aim":aim,"weapon":family,"weapon_index":p.weapon,"spell":spell,"pattern":"thrust" if kind=="thrust" else "spin" if kind=="circle" else "cleave","reach":reach,"id":p.id,"combo":2,"art":move.name,"height":p.height})
	if kind=="volley":
		var count: int=int(move.get("count",3))
		var pellets: Dictionary={}
		for i in count:
			var weight: float=[.5,.3,.2][i] if count==3 else 1.0/1.48 if spell=="scatter" else 1.0/count
			var pierce: int=int(move.get("pierce",1))
			var next: float=clampf(.65+(.05 if Build.core(p,8)==1 else .08 if Build.core(p,8)==2 else 0),0,.8)
			var decay: Array=[1.0,next,next] if pierce>1 else []
			projectile(s,p,aim.rotated((i-(count-1)*.5)*.12),damage*weight,reach,spell,ctx,pierce,decay,pellets)
		return
	var center: Vector2=aim_point(s,p,aim,reach) if kind=="burst" else p.p
	if kind=="burst": s.broadcast_combat({"kind":"spell_burst","p":center,"aim":aim,"spell":spell,"id":p.id,"weapon_index":p.weapon})
	elif kind=="beam": s.broadcast_combat({"kind":"spell_beam","p":p.p,"aim":aim,"reach":reach,"spell":spell,"id":p.id,"weapon_index":p.weapon})
	var index := 0
	for e in ordered_targets(s,p.p):
		if index>=(3 if family in [2,3] else 5): break
		if e.hp<=0 or not s.ruins.clear_line(p.p,e.p): continue
		var delta: Vector2=e.p-p.p
		var hit := false
		match kind:
			"thrust", "beam", "circle", "cone": hit=s.enemy_bodies.attack_hit(e,p.p,aim,reach,s.elapsed,true,kind,float(move.get("width",35)),.5,float(p.height))
			"burst": hit=s.enemy_bodies.attack_hit(e,center,aim,float(move.get("radius",100)),s.elapsed,true,"circle") and s.ruins.clear_line(center,e.p)
		if not hit: continue
		var falloff: float=1.0 if index==0 else .65
		s.damage_enemy(e,damage*falloff,p.id,delta.normalized(),25,family,p.weapon,ctx)
		if int(ctx.get("route",-1))==2 and family==1 and not e.get("rogue_guardian",false) and s.elapsed>=float(e.get("build_cc_until",0)):
			e["build_cc_until"]=s.elapsed+8
			e["height"]=18.0 if e.get("build_elite",false) else 35.0
			e["height_velocity"]=0.0
			e["build_air_time"]=.18 if e.get("build_elite",false) else .35
		index+=1

static func normal(s, p: Dictionary) -> void:
	var w := Catalog.weapon(int(p.weapon))
	var n := Build.weapon_id(p)
	var family := Catalog.weapon_family(int(p.weapon))
	var direction: Vector2=p.strike_aim
	var ctx: Dictionary=p.get("build_strike_context",{})
	if ctx.is_empty(): ctx=Build.context(s,p,"attack")
	var damage: float=s.weapon_damage(p)
	if family==1 and p.combo==2: damage*=1.2 if n==4 else 1.0 if n==12 else 1.4
	s.broadcast_combat({"kind":"strike","p":p.p,"aim":direction,"weapon":family,"weapon_index":p.weapon,"spell":w.get("spell","star"),"pattern":w.get("pattern",""),"reach":float(w.reach),"id":p.id,"combo":p.combo,"height":p.height})
	if family in [1,2]:
		var index := 0
		for e in ordered_targets(s,p.p):
			if index>=(3 if family==2 else 5): break
			var delta: Vector2=e.p-p.p
			if e.hp<=0 or not s.ruins.clear_line(p.p,e.p): continue
			var pattern: String=str(w.get("pattern",""))
			var cosine: float=(.342 if n==14 else .819 if n==22 else .5) if pattern=="cleave" else -.1
			var hits: bool=s.enemy_bodies.attack_hit(e,p.p,direction,float(w.reach),s.elapsed,true,pattern,26.0,cosine,float(p.height))
			if not hits: continue
			var decay: float=1.0 if index==0 else .65 if n==15 else .70
			s.damage_enemy(e,damage*decay,p.id,direction,float(w.knock),family,p.weapon,ctx)
			index+=1
		if n==2 and not ctx.get("counted",false): p.combo=0; p.combo_timeout=0.0
	else:
		if family==0: p.ammo-=1
		var spell: String=str(w.get("spell","star"))
		if spell=="prism":
			var index := 0
			for e in ordered_targets(s,p.p):
				if index>=4: break
				var delta: Vector2=e.p-p.p
				if e.hp>0 and s.enemy_bodies.attack_hit(e,p.p,direction,float(w.reach),s.elapsed,true,"beam",30.0,-.1,float(p.height)) and s.ruins.clear_line(p.p,e.p):
					s.damage_enemy(e,damage*[1.0,.65,.45,.30][index],p.id,direction,w.knock,3,p.weapon,ctx); index+=1
			s.broadcast_combat({"kind":"spell_beam","p":p.p,"aim":direction,"reach":w.reach,"spell":spell,"id":p.id,"weapon_index":p.weapon,"height":p.height})
		else:
			var count := 5 if spell=="scatter" else 1
			var pellets: Dictionary={}
			var decay: Array=[1.0,.60] if n==26 else [1.0,.65,.45] if n==41 else [1.0,.6,.4,.25] if n==45 else [1.0,.6] if spell=="arrow" else []
			if family==0:
				for at in range(1,decay.size()): decay[at]=Build.attenuation(p,float(decay[at]))
			for i in count: projectile(s,p,direction.rotated((i-2)*.15) if count==5 else direction,damage,float(w.reach),spell,ctx,maxi(1,decay.size()),decay,pellets)

static func clip(p: Dictionary) -> int:
	return 1 if Build.weapon_id(p)==31 else 16

static func hurt_source(s, source: Dictionary, damage: float) -> float:
	if source.is_empty(): return damage
	return damage*float(source.get("build_damage_scale",1))
