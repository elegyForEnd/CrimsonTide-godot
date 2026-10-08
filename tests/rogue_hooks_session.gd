extends SceneTree

## W1a 验收：把「深渊变数」与「诅咒」真正接进 session.gd 的战斗数值路径。
## 覆盖六项：① 非魔境逐项恒等；② 魔境数值正确且 clamp 生效；
## ③ 判定几何零变化（hit_radius 仍是默认 18.0）；④ 钩子不消耗 s.rng；
## ⑤ 诅咒与既有减伤池**同池相减**；⑥ 变数中性时不写多余键。
## 另用源码结构断言把三处接线点钉死（避免以后被人悄悄拆掉）。

var checks := 0
var failures := 0

const Variants = preload("res://scripts/rogue_variants.gd")
const Curses = preload("res://scripts/rogue_curses.gd")
const RogueBuild = preload("res://scripts/rogue_build.gd")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a-b)<=eps

func bolt_dict() -> Dictionary:
	return {"p":Vector2(10.0,10.0),"v":Vector2(245.0,0.0),"life":2.0,"damage":12.0,"owner":0}

func _initialize() -> void: call_deferred("run")

func new_session(mode: String, seed_value: int) -> TideSession:
	var t := TideSession.new()
	root.add_child(t)
	t.set_physics_process(false)
	t.solo({"hero":0,"mode":mode})
	t.launch(false,seed_value)
	t.spawn_timer=9999
	return t

func last_enemy(s: TideSession) -> Dictionary:
	return s.enemies[s.enemies.size()-1] if not s.enemies.is_empty() else {}

func run() -> void:
	# =====================================================================
	# A. 非魔境（搜打撤）：钩子一律恒等
	# =====================================================================
	var f := new_session("expedition",1729)
	check(not f.roguelike.active(f),"Field session is not in roguelike mode")
	var fp: Dictionary=f.players[1]
	check(f.rogue_mods(fp).is_empty(),"Field mode yields an empty mod table")
	var field_expected := maxf(0.0,100.0)*(1.0-f.stat_defense(fp))*(1.0-minf(0.4,float(fp.get("rogue_defense",0))))
	check(near(f.incoming_damage(fp,100.0),field_expected),"Field incoming_damage keeps its exact formula")
	var field_bolt: Dictionary=f.rogue_enemy_bolt(bolt_dict())
	check(field_bolt.size()==5,"Field mode adds no key to the enemy bolt")
	check(not field_bolt.has("bullet_visual"),"Field mode writes no bullet_visual")
	var fb_speed: Vector2=field_bolt["v"]
	check(near(fb_speed.x,245.0),"Field mode leaves enemy bolt speed untouched")
	check(not field_bolt.has("hit_radius") or near(float(field_bolt["hit_radius"]),18.0),"Field bolt carries no non-default hit radius")

	# =====================================================================
	# B. 魔境：变数 + 诅咒的数值正确
	# =====================================================================
	var s := new_session("roguelike",4242)
	check(s.roguelike.active(s),"Roguelike session is active")
	var p: Dictionary=s.players[1]
	p["rogue_curses"]=["CU01","CU02"]	# 受伤 +15%，移速 -18
	s.raid["variant"]="fog"			# 弹幕尺寸 +25%，弹速 -20%

	var mods := s.rogue_mods(p)
	check(near(float(mods.get("bullet_size",0.0)),0.25),"fog raises bullet size by 25%")
	check(near(float(mods.get("bullet_speed",0.0)),-0.20),"fog lowers bullet speed by 20%")
	check(near(float(mods.get("move_speed",0.0)),-18.0),"CU02 subtracts 18 speed in the same additive pool")
	check(near(float(mods.get("defense_penalty",0.0)),1.0-1.0/1.15),"CU01 becomes a pool penalty of 1-1/1.15")
	check(near(float(mods.get("curse_count",0.0)),2.0),"Two curses are counted")
	check(float(mods.get("defense_penalty",0.0))<=Curses.MAX_POOL+0.0001,"The pool penalty stays inside MAX_POOL")

	# 诅咒与既有减伤池同池相减（不是新开乘数）：先造一个确定性的池 = 0.10
	p["build_buffs"]["defense"]={"value":0.10,"until":s.elapsed+99.0}
	var pool: float=RogueBuild.conditional_defense(s,p)
	check(near(pool,0.10),"The fixture produces a deterministic 0.10 reduction pool")
	var base_before := maxf(0.0,100.0)*(1.0-s.stat_defense(p))
	p["rogue_curses"]=[]
	var without: float=s.incoming_damage(p,100.0)
	check(near(without,base_before*(1.0-pool)),"With no curse the existing pool is used untouched")
	p["rogue_curses"]=["CU01"]
	var with_one: float=s.incoming_damage(p,100.0)
	check(with_one>without,"A damage-taken curse makes hits land harder")
	check(near(with_one,base_before*(1.0-clampf(pool-.15,-.6,Curses.MAX_POOL))),"The curse subtracts its advertised contribution from the same pool")
	check(not near(with_one,without*1.15),"The curse is not a second multiplier")
	p["rogue_curses"]=["CU01","CU01","CU01","CU01"]
	var floored: float=s.incoming_damage(p,100.0)
	check(floored>=base_before-0.0001,"The negative contribution increases damage")
	check(near(floored,base_before*1.5),"The curse cap contributes .60 against the existing .10 defense")

	# 变数的受伤加成（austerity：受到伤害 +10%）叠在同池结果之上
	p["rogue_curses"]=["CU01"]
	s.raid["variant"]="austerity"
	var taken_mods := s.rogue_mods(p)
	check(near(float(taken_mods.get("player_damage_taken",0.0)),0.10),"austerity raises damage taken by 10%")
	check(near(s.incoming_damage(p,100.0),with_one*1.10),"Variant damage-taken multiplies the pooled result")

	# 中性：无诅咒无变数 → 与接线前的公式逐位一致
	p["rogue_curses"]=[]
	s.raid["variant"]=""
	var plain := maxf(0.0,100.0)*(1.0-s.stat_defense(p))*(1.0-RogueBuild.conditional_defense(s,p))
	check(near(s.incoming_damage(p,100.0),plain),"With no curse and no variant the roguelike formula is unchanged")
	check(not s.rogue_mods(p).has("defense_penalty") or near(float(s.rogue_mods(p)["defense_penalty"]),0.0),"No curses means no pool penalty")

	# 敌人普通弹幕：只改弹速与表现层尺寸
	s.raid["variant"]="fog"
	var out: Dictionary=s.rogue_enemy_bolt(bolt_dict())
	var out_speed: Vector2=out["v"]
	check(near(out_speed.x,245.0*0.8),"fog scales the enemy bolt speed by 0.8")
	check(near(float(out.get("bullet_visual",1.0)),1.25),"fog writes a presentation-only bullet_visual of 1.25")
	check(not out.has("hit_radius") and near(float(out.get("hit_radius",18.0)),18.0),"The bolt keeps the default hit radius of 18.0")
	check(near(float(out.get("life",0.0)),2.0),"Bolt lifetime is untouched")
	check(near(float(out.get("damage",0.0)),12.0),"Bolt damage is untouched")
	var kept_owner := int(out.get("owner",-1))
	check(kept_owner==0,"Bolt ownership is untouched")

	# ⑥ 中性 mods 不写多余键
	s.raid["variant"]=""
	var neutral: Dictionary=s.rogue_enemy_bolt(bolt_dict())
	check(neutral.size()==5 and not neutral.has("bullet_visual"),"Neutral mods add no new bolt key")

	# ③ 判定几何键永不出现
	s.raid["variant"]="fog"
	var geometry_ok := true
	for key in s.rogue_mods(p).keys():
		if Variants.FORBIDDEN_KEYS.has(str(key)): geometry_ok=false
	check(geometry_ok,"The mod table never exposes a hit-geometry key")
	check(not out.has("hit_radius") and not out.has("hit_scale") and not out.has("collision_radius"),"The bolt dict never gains a hit-geometry key")

	# ④ 钩子不消耗 s.rng（damage_enemy 里的构筑 proc 本就允许消耗，故不在此断言）
	var state_before: int=s.rng.state
	s.rogue_mods(p)
	s.rogue_mods()
	s.rogue_enemy_bolt(bolt_dict())
	s.incoming_damage(p,50.0)
	check(s.rng.state==state_before,"The rogue hooks never consume s.rng")

	# =====================================================================
	# C. 端到端：变数 player_damage 真的放大输出（同种子两局对照）
	# =====================================================================
	var plain_s := new_session("roguelike",909)
	var buff_s := new_session("roguelike",909)
	plain_s.raid["variant"]=""
	buff_s.raid["variant"]="apocalypse"	# 普攻 +15%
	check(near(float(buff_s.rogue_mods(buff_s.players[1]).get("player_damage",0.0)),0.15),"apocalypse raises player damage by 15%")
	plain_s.spawn_enemy(Vector2(420.0,0.0))
	buff_s.spawn_enemy(Vector2(420.0,0.0))
	var e1 := last_enemy(plain_s)
	var e2 := last_enemy(buff_s)
	check(not e1.is_empty() and not e2.is_empty(),"Both comparison sessions spawned a target")
	if not e1.is_empty() and not e2.is_empty():
		var hp1: float=float(e1.hp)
		var hp2: float=float(e2.hp)
		plain_s.damage_enemy(e1,50.0,1,Vector2.RIGHT,0.0,-1,-1,{"kind":"attack","depth":0,"crit_targets":{e1.id:false}})
		buff_s.damage_enemy(e2,50.0,1,Vector2.RIGHT,0.0,-1,-1,{"kind":"attack","depth":0,"crit_targets":{e2.id:false}})
		var dealt_plain := hp1-float(e1.hp)
		var dealt_buff := hp2-float(e2.hp)
		check(dealt_plain>0.0,"The baseline hit lands damage")
		check(near(dealt_buff/dealt_plain,1.15,0.01),"player_damage multiplies outgoing damage end to end")

	# =====================================================================
	# D. 源码结构断言：三处接线点存在且判定默认值是 18.0
	# =====================================================================
	var source := FileAccess.get_file_as_string("res://scripts/session.gd")
	check(source.contains("bullets.append(rogue_enemy_bolt("),"Ordinary enemy bolts pass through the variant hook")
	check(source.contains("speed+RogueBuild.stat(self,p,\"speed\")+move_bonus"),"Move speed joins the same additive pool before the cap")
	p.build_buffs={}; p.rogue_curses=[]; s.raid.variant=""
	var unarmored := s.incoming_damage(p,100.0)
	p.rogue_curses=["CU01"]
	check(near(s.incoming_damage(p,100.0),unarmored*1.15),"Blood curse also increases damage without a defense buff")
	check(source.contains("float(b.get(\"hit_radius\",18.0))"),"The bullet hit test still defaults to 18.0")
	check(not source.contains("bolt[\"hit_radius\"]"),"The bolt hook never writes a hit radius")

	s.queue_free()
	f.queue_free()
	plain_s.queue_free()
	buff_s.queue_free()
	await process_frame
	print("ROGUE HOOKS ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
