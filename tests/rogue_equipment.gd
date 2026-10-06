extends SceneTree
## rogue_equipment.gd 的**真实职责面**：定义查询 / 品质缩放 / 装备物品构造 / 描述文本。
##
## 这个文件曾被当成"装备被动的实现处"：它的四个遗留钩子（damage_multiplier / tick / spent /
## hit）签名齐全但全是惰性桩，而老一辈用例正拿它们断言 1.18 / 1.20 之类的被动倍率 —— 那些数字
## 从未反映真实行为（真实现按 1 基编号在 scripts/rogue_build.gd 的 gear(p,N)/engraving(p,N)，
## 外围接线散落在 session.gd / roguelike.gd / rogue_combat.gd）。于是"被动等于没实现"的误判
## 从这条用例扩散出去，还被写进了分诊结论。
##
## 重写后本用例只钉三件事：
##   1. 编号与构造约定（gear(p,N)/engraving(p,N) 整套被动判断的地基）；
##   2. 品质缩放、属性文本、描述文本、items()/total() 的真实数学与 session 口径；
##   3. 四个遗留钩子必须**保持惰性、且 scripts/ 下零调用者**（防止被接回管线造成双重结算）。
## 被动行为本身由 tests/rogue_passives.gd 负责，不在这里重复断言。
const Equipment = preload("res://scripts/rogue_equipment.gd")
const Build = preload("res://scripts/rogue_build.gd")
const Content = preload("res://scripts/rogue_content.gd")
const Catalog = preload("res://scripts/catalog.gd")

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func wear(s, p: Dictionary, index: int, tier: int = 0) -> Dictionary:
	var item: Dictionary=Equipment.make_gear(index,tier)
	p.equipped={"weapon":p.equipped.get("weapon",{}),"gear":[{},{},{}]}
	p.rogue_stash=[]
	s.roguelike.equip(s,p,item)
	return item

func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike"})
	s.launch(false,1729)
	var p: Dictionary=s.players[1]

	# ---- 1. 构造与编号约定（1 基编号是 gear(p,N)/engraving(p,N) 的地基） -----
	var ids_ok := true
	var slots_ok := true
	var defs_ok := true
	var scale_ok := true
	var flat_ok := true
	for i in Equipment.GEAR.size():
		var item: Dictionary=Equipment.make_gear(i,0)
		if item.get("build_id","")!="E%03d" % (i+1) or int(item.get("rogue_id",-1))!=i: ids_ok=false
		if Catalog.gear_slot(item)!=int(Equipment.GEAR[i].slot): slots_ok=false
		if str(Equipment.definition(item).get("id",""))!="E%03d" % (i+1): defs_ok=false
		var top: Dictionary=Equipment.make_gear(i,5)
		for stat in ["hp","mana","speed"]:
			if Equipment.value(top,stat)<Equipment.value(item,stat): scale_ok=false
		for stat in ["damage","defense","crit"]:
			if not is_equal_approx(Equipment.value(top,stat),Equipment.value(item,stat)): flat_ok=false
	check(ids_ok,"make_gear(i) builds the 1-based E%03d id that gear(p,N) depends on")
	check(slots_ok,"make_gear keeps the authored slot")
	check(defs_ok,"definition() resolves every authored gear id")
	check(scale_ok,"quality scales hp/mana/speed monotonically")
	check(flat_ok,"quality leaves damage/defense/crit flat (template constants)")

	# 边界：越界、缺字段、铭刻池按 kind 分流、engrave() 不就地改原物品
	check(Equipment.definition({}).is_empty(),"definition() of an item without rogue_id is empty")
	check(Equipment.definition(Content.make_weapon(3,0)).is_empty(),"an un-engraved weapon has no run definition")
	check(str(Equipment.definition(Equipment.make_gear(999,0)).get("id",""))=="E072","make_gear clamps an out-of-range index")
	check(int(Equipment.make_gear(0,9).tier)==5,"make_gear clamps the tier into 0..5")
	var plain: Dictionary=Content.make_weapon(3,0)
	var tuned: Dictionary=Equipment.engrave(plain,4)
	check(not plain.has("rogue_id"),"engrave() does not mutate the source item")
	check(int(tuned.get("rogue_id",-1))==4,"engrave() stores the rune index")
	check(str(Equipment.definition(tuned).get("id",""))=="I005","definition() routes weapons to the engraving pool")
	check(int(Equipment.engrave(plain,99).get("rogue_id",-1))==Equipment.ENGRAVINGS.size()-1,"engrave() clamps the rune index")

	# ---- 2. items()/total() 的数学与 session 口径 --------------------------
	p.equipped={"weapon":p.equipped.get("weapon",{}),"gear":[{},{},{}]}
	p.rogue_stash=[]
	check(is_equal_approx(Equipment.total(p,"mana"),0.0),"an empty loadout contributes nothing")
	check(Equipment.items(p).is_empty(),"items() ignores gear slots that hold no run item")
	var worn: Dictionary=wear(s,p,4)
	var expected := 0.0
	for it: Dictionary in Equipment.items(p): expected+=Equipment.value(it,"mana")
	check(is_equal_approx(Equipment.total(p,"mana"),expected),"total() equals the sum over items()")
	check(is_equal_approx(Equipment.total(p,"mana"),Equipment.value(worn,"mana")),"the worn piece is the only contributor")
	check(Equipment.items(p).size()==1,"items() lists exactly the worn run gear")
	check(is_equal_approx(s.rogue_equipment_stat(p,"mana"),Equipment.total(p,"mana")),"the session reads this file's total()")
	s.raid.mode="expedition"
	check(is_equal_approx(s.rogue_equipment_stat(p,"mana"),0.0),"run equipment is inert outside the roguelike")
	check(is_equal_approx(Equipment.total(p,"mana"),expected),"total() itself is mode-agnostic; the session gates it")
	s.raid.mode="roguelike"

	# 文本：属性行 + 独特被动 + 目录名称
	var text: String=Equipment.attributes_text(worn)
	check(text.contains("生命") and text.contains("法力"),"attributes_text() prints the run stats")
	check(Catalog.item_desc(worn).contains("独特被动"),"item_desc() appends the unique passive line")
	check(Catalog.item_name(worn).contains(str(Equipment.definition(worn).get("name",""))),"item_name() uses the authored name")
	var engraved: Dictionary=Equipment.engrave(Content.make_weapon(3,0),7)
	check(Catalog.item_desc(engraved).contains("独特被动"),"engraved weapons also carry a passive line")

	# ---- 3. has() 指向真实现；四个遗留钩子必须保持惰性且零调用者 -----------
	wear(s,p,1)
	check(Equipment.has(p,"last_stand")==Build.gear(p,2),"has(last_stand) maps to E002")
	check(Equipment.has(p,"nope_not_a_passive")==false,"has() does not invent unknown passives")
	wear(s,p,2)
	check(Equipment.has(p,"mana_guard")==Build.gear(p,3),"has(mana_guard) maps to E003")
	check(Equipment.has(p,"last_stand")==false,"swapping the piece drops the previous mapping")
	wear(s,p,3)
	check(Equipment.has(p,"clear_mind")==Build.gear(p,4),"has(clear_mind) maps to E004")

	var e: Dictionary={} if s.enemies.is_empty() else s.enemies[0]
	p.hp=p.max_hp*.1
	p.mana=p.max_mana
	check(is_equal_approx(Equipment.damage_multiplier(p,e),1.0),"legacy damage_multiplier stays inert at full mana")
	p.mana=0.0
	check(is_equal_approx(Equipment.damage_multiplier(p,e),1.0),"legacy damage_multiplier stays inert at empty mana")
	var before_hp: float=p.hp
	var before_state := var_to_str(p)
	Equipment.tick(p,1.0)
	Equipment.spent(p,50.0)
	Equipment.hit(p,999.0,true)
	check(is_equal_approx(p.hp,before_hp) and var_to_str(p)==before_state,"legacy tick/spent/hit are no-ops")
	check(is_equal_approx(Equipment.damage_multiplier(p,e),1.0),"legacy damage_multiplier stays inert after the no-op hooks")

	# 结构断言：scripts/ 下不得存在这四个钩子的调用点（否则会与 rogue_build 的既有结算双重计数）。
	var callers := PackedStringArray()
	for hook in ["damage_multiplier","tick","spent","hit"]:
		for path in script_files("res://scripts"):
			if path.get_file()=="rogue_equipment.gd": continue
			var source := FileAccess.get_file_as_string(path)
			for owner in ["Equipment","RogueEquipment"]:
				var needle := "%s.%s(" % [owner,hook]
				if source.contains(needle): callers.append("%s -> %s" % [path,needle])
	check(callers.is_empty(),"no script calls the retired hooks: %s" % ", ".join(callers))

	s.queue_free()
	await process_frame
	print("ROGUE EQUIPMENT %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

func script_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir==null: return out
	for file in dir.get_files():
		if file.ends_with(".gd"): out.append(root.path_join(file))
	return out
