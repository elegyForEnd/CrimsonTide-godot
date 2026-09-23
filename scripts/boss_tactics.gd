extends RefCounted
const Presentation = preload("res://scripts/boss_presentation.gd")

# React to visible, already-started actions, never to raw input packets.
const REACTION_DELAY := 0.28
const REACTION_COOLDOWN := 5.5
const GUARD_WINDUP := 0.32
const GUARD_DURATION := 1.12
const GUARD_ARC := 1.22
const KNIGHT_MOVES := {
	"combo":{"label":"誓约三连 · 两快一慢","marks":[0.65,1.10,2.05],"damage":[18,21,30],"reach":155.0,"arc":1.35,"total":2.45},
	"thrust":{"label":"逐风突刺 · 横向闪避","marks":[0.85],"damage":[32],"reach":110.0,"arc":1.35,"total":1.65},
	"storm":{"label":"失乡风暴 · 远离剑圈","marks":[1.15],"damage":[36],"reach":225.0,"arc":PI,"total":1.75},
	"quick":{"label":"截步快斩 · 快刀","marks":[0.50],"damage":[21],"reach":170.0,"arc":1.20,"total":1.05},
	"delayed":{"label":"举剑虚晃 · 慢刀，别急滚","marks":[1.45],"damage":[42],"reach":195.0,"arc":1.30,"total":2.05},
	"counter":{"label":"架剑反击 · 快斩接慢刀","marks":[0.55,1.35],"damage":[22,30],"reach":180.0,"arc":1.25,"total":1.85}
}

static func can_guard(e: Dictionary) -> bool:
	return int(e.get("boss_kind",-1))==1 if e.get("raid_boss",false) else int(e.type)==4

static func tick(s, e: Dictionary, dt: float) -> void:
	for key in ["reaction_cd","guard_cd","guard_flash"]:
		e[key]=maxf(0,float(e.get(key,0))-dt)
	var pending: Dictionary=e.get("reaction",{})
	if not pending.is_empty():
		pending.wait-=dt
		pending.expires-=dt
		var actor: Dictionary=s.players.get(pending.target,{})
		if pending.expires<=0 or actor.get("status","")!="active" or not s.ruins.clear_line(e.p,actor.p): e.reaction={}
	# Observation is edge-triggered and bounded to visible targets.
	var target: Dictionary={}
	var distance := 600.0
	for p in s.players.values():
		if p.status=="active" and e.p.distance_to(p.p)<distance and s.ruins.clear_line(e.p,p.p):
			target=p
			distance=e.p.distance_to(p.p)
	var action := ""
	if not target.is_empty():
		if float(target.get("dodge_time",0))>0: action="dodge"
		elif float(target.get("reload",0))>0: action="reload"
		elif float(target.get("swing_time",0))>0 and target.get("strike_aim",Vector2.RIGHT).dot((e.p-target.p).normalized())>0.5: action="attack"
	var signature := str(target.get("id",0))+action if not action.is_empty() else ""
	var fresh: bool=signature!=str(e.get("observed_action",""))
	e.observed_action=signature
	if not fresh or action.is_empty() or e.reaction_cd>0 or not e.get("reaction",{}).is_empty(): return
	if e.attack_time>0 or float(e.get("guard_time",0))>0 or float(e.get("stagger",0))>0: return
	if action=="attack" and (not can_guard(e) or e.guard_cd>0 or distance>300): return
	var at: Vector2=target.p
	if action=="dodge":
		at=s.ruins.move(at,target.get("dodge_dir",Vector2.ZERO)*s.DODGE_DISTANCE*float(target.dodge_time)/s.DODGE_DURATION)
	e.reaction={"kind":action,"target":target.id,"point":at,"wait":REACTION_DELAY,"expires":1.0}

static func response(s, e: Dictionary) -> Dictionary:
	if e.attack_time>0 or float(e.get("stagger",0))>0 or float(e.get("guard_time",0))>0: return {}
	if e.get("counter_ready",false):
		e.counter_ready=false
		return {"kind":"counter","point":e.p+e.guard_aim*180,"aim":e.guard_aim}
	var pending: Dictionary=e.get("reaction",{})
	if pending.is_empty() or pending.wait>0 or e.cd>0.45: return {}
	var target: Dictionary=s.players.get(pending.target,{})
	if target.get("status","")!="active" or not s.ruins.clear_line(e.p,target.p):
		e.reaction={}
		return {}
	e.reaction={}
	e.reaction_cd=REACTION_COOLDOWN
	return {"kind":pending.kind,"point":pending.point,"aim":(pending.point-e.p).normalized()}

static func start_guard(e: Dictionary, aim: Vector2, s = null) -> bool:
	if not can_guard(e) or float(e.get("guard_cd",0))>0: return false
	e.merge({"guard_time":GUARD_DURATION,"guard_aim":aim,"guard_load":0.0,"guard_cd":7.0,"counter_ready":false,"reaction":{},"attack_time":0.0,"move_name":"架势防御 · 绕背 / 重击破防"},true)
	e.cd=GUARD_DURATION+0.4
	if s!=null: Presentation.send(s,e,"guard",{"aim":aim})
	return true

static func update_guard(e: Dictionary, dt: float) -> bool:
	if float(e.get("guard_time",0))<=0: return false
	e.guard_time=maxf(0,e.guard_time-dt)
	if absf(e.guard_aim.x)>0.05: e.facing=signf(e.guard_aim.x)
	return true

static func blocks(e: Dictionary, direction: Vector2, weapon: int) -> bool:
	var remaining := float(e.get("guard_time",0))
	return can_guard(e) and remaining>0 and remaining<=GUARD_DURATION-GUARD_WINDUP and weapon in [0,1,2,3] and direction.length_squared()>0.01 and e.guard_aim.dot(-direction.normalized())>=cos(GUARD_ARC)

static func absorb(s, e: Dictionary, damage: float, weapon: int) -> float:
	e.guard_load=float(e.get("guard_load",0))+damage*(2.2 if weapon==2 else 1.0)
	e.guard_flash=0.18
	e.counter_ready=true
	var broken: bool=e.guard_load>=(120.0 if e.get("raid_boss",false) else 150.0)
	if broken:
		e.guard_time=0.0
		e.counter_ready=false
		e.stagger=1.25
		e.cd=1.65
		e.reaction={}
		e.move_name="架势崩解 · 趁机进攻"
	Presentation.send(s,e,"break" if broken else "guard",{"aim":e.guard_aim})
	return damage*(0.65 if broken else 0.15)
