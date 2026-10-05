extends SceneTree

## W1c 验收：生态怪（ecology.gd）的弹幕也走「深渊变数」钩子。
## 之前只有 session.gd 的 type-1 普通远程敌人接了钩子，type>=5 的生态怪
## （散射 / 三连咒 / 晶脉环 / 回旋钟波 / 轰击）完全绕过它，导致 fog/surge
## 这类弹速·尺寸变数对生态怪无效。
##
## 覆盖五项：
## ① 中性 mods（搜打撤 / 战役）逐位恒等：不多写键、速度/生命/伤害/owner 不变；
## ② fog / surge 下弹速与表现层 bullet_visual 的数值正确；
## ③ kind-12 回旋弹的语义（return_after / age / reversed / enemy_type）未变；
## ④ 钩子不消耗 s.rng；
## ⑤ 源码结构断言：两处生成点都经过 s.rogue_enemy_bolt，且不留裸 append。

var checks := 0
var failures := 0

const Ecology = preload("res://scripts/ecology.gd")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a-b)<=eps

func _initialize() -> void: call_deferred("run")

func new_session(mode: String, seed_value: int) -> TideSession:
	var t := TideSession.new()
	root.add_child(t)
	t.set_physics_process(false)
	t.solo({"hero":0,"mode":mode})
	t.launch(false,seed_value)
	t.spawn_timer=9999
	return t

## A plain resident dictionary, only the fields Ecology.update() touches.
func foe(kind: int) -> Dictionary:
	return {"type":kind,"p":Vector2(300.0,300.0),"cd":0.0,"motion_phase":0.0,"flash":0.0,"stagger":0.0,"attack_aim":Vector2.RIGHT,"attack_released":false}

## Same, wound up so the release branch fires on the next update() tick.
func wound(kind: int) -> Dictionary:
	var e := foe(kind)
	e["attack_total"]=Ecology.WINDUP[kind]+0.6
	e["attack_time"]=0.4
	return e

func run() -> void:
	# =====================================================================
	# A. 中性 mods（搜打撤）：bolt() 与改动前逐位一致
	# =====================================================================
	var f := new_session("expedition",1729)
	check(not f.roguelike.active(f),"Field session is not in roguelike mode")
	check(f.rogue_mods().is_empty(),"Field mode yields an empty mod table, so the hook is a pure pass-through")
	f.bullets.clear()
	Ecology.bolt(f,foe(5),Vector2.RIGHT,260.0,12.0)
	check(f.bullets.size()==1,"Field resident bolt still spawns exactly one bullet")
	var fb: Dictionary=f.bullets[0]
	check(fb.size()==5,"Field bolt keeps exactly the original five keys")
	check(not fb.has("bullet_visual"),"Field bolt carries no presentation key")
	check(not fb.has("hit_radius"),"Field bolt writes no hit radius")
	check(near(float(fb.get("hit_radius",18.0)),18.0),"Field bolt hit radius is still the 18.0 default")
	check(near((fb.v as Vector2).x,260.0),"Field bolt speed is untouched")
	check(near(float(fb.get("life",0.0)),2.4),"Field bolt lifetime is untouched")
	check(near(float(fb.get("damage",0.0)),12.0),"Field bolt damage is untouched")
	check(int(fb.get("owner",-1))==0,"Field bolt ownership is untouched")

	# kind-12 ring in the field: five bolts, untouched
	f.bullets.clear()
	var fe12 := wound(12)
	Ecology.update(f,fe12,0.016)
	check(f.bullets.size()==5,"Field kind-12 resident still fires a five-bolt ring")
	var field_ring_clean := true
	for b in f.bullets:
		if b.has("bullet_visual"): field_ring_clean=false
		if not near((b.v as Vector2).length(),260.0,0.01): field_ring_clean=false
	check(field_ring_clean,"Field kind-12 bolts keep their speed and gain no presentation key")

	# kind-14 ring in the field: the twelve-bolt count is a shipped assertion
	f.bullets.clear()
	var fe14 := wound(14)
	Ecology.update(f,fe14,0.016)
	check(f.bullets.size()==12,"Field kind-14 crystal ring still fires twelve bolts")

	# =====================================================================
	# B. 魔境 + fog（弹速 -20% / 尺寸 +25%）
	# =====================================================================
	var s := new_session("roguelike",4242)
	check(s.roguelike.active(s),"Roguelike session is active")
	s.raid["variant"]="fog"
	var mods := s.rogue_mods()
	check(near(float(mods.get("bullet_speed",0.0)),-0.20),"fog lowers the shared bullet speed by 20%")
	check(near(float(mods.get("bullet_size",0.0)),0.25),"fog raises the shared bullet size by 25%")

	s.bullets.clear()
	Ecology.bolt(s,foe(9),Vector2.RIGHT,170.0,21.0)
	var rb: Dictionary=s.bullets[0]
	check(near((rb.v as Vector2).x,170.0*0.8,0.01),"fog scales the resident bolt speed by 0.8")
	check(near(float(rb.get("bullet_visual",1.0)),1.25),"fog writes a presentation-only bullet_visual of 1.25")
	check(near(float(rb.get("life",0.0)),2.4),"fog leaves the resident bolt lifetime alone")
	check(near(float(rb.get("damage",0.0)),21.0),"fog leaves the resident bolt damage alone")
	check(int(rb.get("owner",-1))==0,"fog leaves ownership alone")
	check(not rb.has("hit_radius"),"fog never writes a hit radius")
	check(not rb.has("hit_scale") and not rb.has("collision_radius"),"fog adds no hit-geometry key")

	# 回旋钟波（kind 12）也吃到 fog，且轨迹语义不变
	s.bullets.clear()
	var se12 := wound(12)
	Ecology.update(s,se12,0.016)
	check(s.bullets.size()==5,"Roguelike kind-12 resident still fires a five-bolt ring")
	var ring_ok := true
	for b in s.bullets:
		if not near((b.v as Vector2).length(),260.0*0.8,0.01): ring_ok=false
		if not near(float(b.get("bullet_visual",1.0)),1.25): ring_ok=false
		if not near(float(b.get("return_after",-1.0)),0.75): ring_ok=false
		if not near(float(b.get("age",-1.0)),0.0): ring_ok=false
		if bool(b.get("reversed",true)): ring_ok=false
		if int(b.get("enemy_type",-1))!=12: ring_ok=false
		if b.has("hit_radius"): ring_ok=false
	check(ring_ok,"kind-12 bolts keep return_after/age/reversed/enemy_type and only gain speed + bullet_visual")

	# 晶脉环（kind 14）在魔境下同样全部接钩子
	s.bullets.clear()
	var se14 := wound(14)
	Ecology.update(s,se14,0.016)
	check(s.bullets.size()==12,"Roguelike kind-14 crystal ring still fires twelve bolts")
	var ring14_ok := true
	for b in s.bullets:
		if not near((b.v as Vector2).length(),185.0*0.8,0.01): ring14_ok=false
		if not near(float(b.get("bullet_visual",1.0)),1.25): ring14_ok=false
	check(ring14_ok,"Every kind-14 bolt passes through the variant hook")

	# =====================================================================
	# C. 魔境 + surge（弹速 +15% / 尺寸 +10%）：另一条方向相反的变数
	# =====================================================================
	s.raid["variant"]="surge"
	var surge_mods := s.rogue_mods()
	check(near(float(surge_mods.get("bullet_speed",0.0)),0.15),"surge raises the shared bullet speed by 15%")
	check(near(float(surge_mods.get("bullet_size",0.0)),0.10),"surge raises the shared bullet size by 10%")
	s.bullets.clear()
	Ecology.bolt(s,foe(15),Vector2.RIGHT,155.0,18.0)
	var sb: Dictionary=s.bullets[0]
	check(near((sb.v as Vector2).x,155.0*1.15,0.01),"surge scales the resident bolt speed by 1.15")
	check(near(float(sb.get("bullet_visual",1.0)),1.10),"surge writes a bullet_visual of 1.10")

	# =====================================================================
	# D. 中性 mods（魔境但未抽到变数）也不写多余键
	# =====================================================================
	s.raid["variant"]=""
	s.bullets.clear()
	Ecology.bolt(s,foe(6),Vector2.RIGHT,300.0,13.0)
	var nb: Dictionary=s.bullets[0]
	check(nb.size()==5,"Neutral roguelike bolt adds no new key")
	check(not nb.has("bullet_visual"),"Neutral roguelike bolt writes no bullet_visual")
	check(near((nb.v as Vector2).x,300.0),"Neutral roguelike bolt keeps its authored speed")

	# =====================================================================
	# E. 钩子不消耗 s.rng
	# =====================================================================
	var state_before: int=s.rng.state
	Ecology.bolt(s,foe(5),Vector2.RIGHT,200.0,10.0)
	var rng12 := wound(12)
	Ecology.update(s,rng12,0.016)
	check(s.rng.state==state_before,"The ecology variant hook never consumes s.rng")

	# =====================================================================
	# F. 源码结构：两处生成点都接上了，且不留裸 append
	# =====================================================================
	var src := FileAccess.get_file_as_string("res://scripts/ecology.gd")
	check(src.count("s.rogue_enemy_bolt(")==2,"Both ecology bolt spawn points route through rogue_enemy_bolt")
	check(not src.contains("s.bullets.append({\"p\""),"No bare enemy-bolt append is left in ecology.gd")
	var session_src := FileAccess.get_file_as_string("res://scripts/session.gd")
	check(session_src.contains("float(b.get(\"hit_radius\",18.0))"),"The bullet hit test still defaults to 18.0")
	check(not src.contains("hit_radius"),"ecology.gd never mentions hit_radius at all")

	s.queue_free()
	f.queue_free()
	await process_frame
	print("ROGUE HOOKS ECOLOGY ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
