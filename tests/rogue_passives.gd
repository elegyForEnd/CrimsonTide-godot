extends SceneTree
## Pins the *real* equipment/engraving passive implementations.
##
## 背景：被动长期被误认为"没实现"，因为唯一以 passive 命名的文件
## (scripts/rogue_equipment.gd) 只有遗留桩，而真正实现是按 1 基编号
## 散落在 rogue_build.gd 的 gear(p,N)/engraving(p,N) 判定里。
## 本用例做两件事：
##   1. 钉住编号约定（E00N 第 N 件 / I00N 第 N 个铭刻）——整套被动都依赖它；
##   2. 钉住几条代表性被动的真实行为（阈值、上限、ICD、不重复结算）。
const Build = preload("res://scripts/rogue_build.gd")
const Equipment = preload("res://scripts/rogue_equipment.gd")
const Content = preload("res://scripts/rogue_content.gd")
var checks := 0
var failures := 0
var s: TideSession
var p: Dictionary
var e: Dictionary

func _initialize() -> void: call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func bare_gear(slot_index: int, tier: int = 0) -> void:
	p.equipped={"weapon":p.equipped.get("weapon",{}),"gear":[{},{},{}]}
	p.rogue_stash=[]
	s.roguelike.equip(s,p,Equipment.make_gear(slot_index,tier))

func reset() -> void:
	s.solo({"hero":0,"mode":"roguelike"}); s.launch(false,431)
	p=s.players[1]; p.rogue_selection={}; p.build_reward_queue=[]
	s.raid.phase="rogue_exit"
	s.roguelike.equip(s,p,Content.make_weapon(0,0))
	p.build_forge_level=0
	s.enemies.clear(); s.spawn_enemy(s.ruins.move(p.p,Vector2(50,0)),0)
	e=s.enemies.back(); s.roguelike.combat.setup_minion(e,0,0,false,s.rng)
	e.hp=100000; e.max_hp=e.hp; e.stagger=9999
	s.raid.phase="rogue_combat"; p.attack=0; p.swing_time=0; p.pending_strike=false; p.cast_time=0
	p.build_cd={}; p.build_buffs={}; p.build_counts={}; p.build_inputs=[]

func attack_hit() -> void:
	s.elapsed+=.35
	Build.action_event(s,p,"A")
	Build.hit_event(s,p,e,10,false,Build.context(s,p,"attack"))

func run() -> void:
	s=TideSession.new(); root.add_child(s); s.set_physics_process(false)
	# ---- 1. 编号约定：整套被动判定的地基 --------------------------------
	var ids_ok := true
	for i in Equipment.GEAR.size():
		if Equipment.make_gear(i,0).get("build_id","")!="E%03d" % (i+1): ids_ok=false
	check(ids_ok,"Gear index i builds E%03d (1-based ids drive gear(p,N))")
	# 每个铭刻槽位只允许命中一个 N，且 N 必须等于槽位号（无别名/无越界命中）。
	reset()
	var eng_ok := true
	for n in range(1,Equipment.ENGRAVINGS.size()+1):
		p.rogue_stash=[] # 换装会把旧武器压进备用行囊，行囊只有 12 格；这里只测编号映射。
		s.roguelike.equip(s,p,Equipment.engrave(Content.make_weapon(0,0),n-1))
		var matched := 0
		for k in range(1,Equipment.ENGRAVINGS.size()+1):
			if Build.engraving(p,k):
				matched+=1
				if k!=n: eng_ok=false
		if matched!=1: eng_ok=false
	check(eng_ok,"engraving(p,N) matches rogue_id N-1 exactly, one N per rune")

	# 备用行囊 12 格：连换装到满之后必须拒绝，且不能悄悄改掉身上的武器。
	reset()
	while s.roguelike.equip(s,p,Equipment.engrave(Content.make_weapon(0,0),5)) and p.rogue_stash.size()<12:
		pass
	check(p.rogue_stash.size()==12,"reserve fills to exactly 12 swapped items")
	var weapon_before: int=int(p.equipped.weapon.get("rogue_id",-1))
	check(not s.roguelike.equip(s,p,Equipment.engrave(Content.make_weapon(0,0),7)),"a full reserve refuses further swaps")
	check(int(p.equipped.weapon.get("rogue_id",-1))==weapon_before,"a refused swap leaves the equipped weapon untouched")

	# ---- 2. E002 余烬壁垒：HP<35% 条件减伤 +15% --------------------------
	reset()
	p.hp=p.max_hp*.34
	var defense_without := Build.conditional_defense(s,p)
	bare_gear(1)
	var defense_with := Build.conditional_defense(s,p)
	check(is_equal_approx(defense_with-defense_without,.15),"E002 grants +15% conditional defense below 35% HP")
	check(Equipment.has(p,"last_stand"),"has(p,\"last_stand\") resolves to E002")
	p.hp=p.max_hp*.60
	check(is_equal_approx(Build.conditional_defense(s,p),defense_without),"E002 stops the instant HP leaves the threshold")

	# ---- 3. E003 星纱法袍：20% 法力吸收，且**只结算一次** ----------------
	reset()
	bare_gear(2)
	p.hp=p.max_hp; p.mana=p.max_mana; p.invuln=0; p.build_shield=0; p.build_shields={}
	check(Equipment.has(p,"mana_guard"),"has(p,\"mana_guard\") resolves to E003")
	var incoming := s.incoming_damage(p,20)
	var mana_before: float=p.mana
	var hp_before: float=p.hp
	s.hurt(p,20)
	var mana_lost: float=mana_before-float(p.mana)
	var expected := minf(incoming,incoming*.20)
	check(is_equal_approx(mana_lost,expected),"E003 absorbs exactly 20% of incoming damage through mana")
	check(is_equal_approx(hp_before-p.hp,incoming-expected),"E003 removes exactly the absorbed part from the hit")
	var double_dip := incoming-expected
	check(mana_lost<double_dip*.30,"the retired mana_guard block cannot absorb a second time")

	# ---- 4. E004 晨露护衣：HP>=80% 时回蓝 +25% ---------------------------
	reset()
	bare_gear(3)
	p.hp=p.max_hp*.5
	var regen_low := Build.stat(s,p,"regen")
	p.hp=p.max_hp*.95
	var regen_high := Build.stat(s,p,"regen")
	check(is_equal_approx(regen_high-regen_low,.25),"E004 adds +25% regen only at or above 80% HP")

	# ---- 5. E001 血棘战衣：吸血 4%，单次封顶 2% HP，ICD 2 秒 -------------
	reset()
	bare_gear(0)
	p.hp=p.max_hp*.5
	var before: float=p.hp
	Build.hit_event(s,p,e,999999,false,Build.context(s,p,"attack"))
	check(is_equal_approx(p.hp-before,p.max_hp*.02),"E001 lifesteal is capped at 2% HP per hit")
	var healed: float=p.hp
	Build.hit_event(s,p,e,999999,false,Build.context(s,p,"attack"))
	check(is_equal_approx(p.hp,healed),"E001 lifesteal respects its 2s internal cooldown")

	# ---- 6. 铭刻 I005/I006：每第 4/3 次普攻根命中加 1 层，ICD 2 秒 ------
	for probe in [[5,4,"bleed"],[6,3,"burn"]]:
		reset()
		s.roguelike.equip(s,p,Equipment.engrave(Content.make_weapon(0,0),int(probe[0])-1))
		var applied := 0
		for i in int(probe[1]):
			attack_hit()
			if Build.status(e,p.id,str(probe[2]))>0: applied=int(i)+1
		check(applied==int(probe[1]),"I%03d applies %s on hit %d only" % [probe[0],probe[2],probe[1]])
		check(Build.status(e,p.id,str(probe[2]))==1,"I%03d grants exactly 1 stack" % probe[0])
		# 走完一整轮计数但 ICD 未过：不应再叠。
		var stacks := Build.status(e,p.id,str(probe[2]))
		for i in int(probe[1]): attack_hit()
		check(Build.status(e,p.id,str(probe[2]))==stacks,"I%03d cannot fire again inside its 2s cooldown" % probe[0])

	s.queue_free()
	await process_frame
	print("ROGUE PASSIVES %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
