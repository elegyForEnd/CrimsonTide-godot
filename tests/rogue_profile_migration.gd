extends SceneTree

## R3 验收：存档迁移与服务端兼容（契约 §4.1 / §4.2）。
##
## 覆盖：
##  1) 老档（version 1、无 ashes/growth）读入后旧字段逐项不变、新键取默认值；
##  2) 老档 读 → 存 → 再读 回环；
##  3) version 缺失 / != 1 / 非整数：**不得静默丢档**，且落盘永远是 1；
##  4) 脏数据边界（ashes 字符串/负数/超大/数组，growth 数组/null/混合值）的**实测行为**；
##  5) save_profile() 会把手改过的 version 与 growth 拉回合法态。
##
## 说明：断言写的是**本实现实测到的行为**，不是"应该怎样"。其中 3) 与 5) 对应 R3 对
## scripts/profile.gd 做的最小改动（见 output/R3-SAVE-MIGRATION.md）。

var checks := 0
var failures := 0
var notes: Array = []

const ProfileScript = preload("res://scripts/profile.gd")
const PATH := "user://rogue_profile_migration.json"

# 老档（契约 §4.2 第 1 条）：version 1，没有 ashes / growth。
# attributes.vigor = 12 而 xp=990 → 预算 = 5 + 990/180 = 10 点，花 2 点，清洗后仍是 12。
const LEGACY_JSON := '{"version":1,"name":"守夜人","coins":321,"xp":990,"runs":7,"extracts":3,' \
	+ '"hero":1,"gear":2,"talents":[1,2,3],"volume":0.5,"voice_volume":0.9,"music_volume":0.7,' \
	+ '"fullscreen":false,"best":12,"pocket":{"key":"white","items":[],"gw":4,"gh":4,"next":1},' \
	+ '"bag_key":"white","bags":[{"key":"white","items":[],"next":1}],"unlocks":{"muyu":true},' \
	+ '"attributes":{"vigor":12},"home":{},"warehouse":[],"trade_history":[]}'

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func note(text: String) -> void:
	notes.append(text)

func fresh() -> Profile:
	var p := ProfileScript.new()
	p.path=PATH
	return p

func read_saved() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}

func cleanup() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH+".tmp")

# 老档的每个字段是否都还在（数值按 int 比、归一化字段按语义比）
func check_legacy(prof: Profile, tag: String) -> void:
	var d: Dictionary = prof.data
	check(int(d["version"])==1,"%s version == 1" % tag)
	check(int(d["coins"])==321,"%s coins" % tag)
	check(int(d["xp"])==990,"%s xp" % tag)
	check(int(d["runs"])==7,"%s runs" % tag)
	check(int(d["extracts"])==3,"%s extracts" % tag)
	check(int(d["hero"])==1,"%s hero" % tag)
	check(int(d["gear"])==2,"%s gear" % tag)
	check(int(d["best"])==12,"%s best" % tag)
	var talents: Array = d["talents"]
	check(talents.size()==3 and int(talents[0])==1 and int(talents[1])==2 and int(talents[2])==3,
		"%s talents" % tag)
	check(str(d["name"])=="守夜人","%s name" % tag)
	check(absf(float(d["volume"])-0.5)<0.0001,"%s volume" % tag)
	check(absf(float(d["voice_volume"])-0.9)<0.0001,"%s voice_volume" % tag)
	check(absf(float(d["music_volume"])-0.7)<0.0001,"%s music_volume" % tag)
	check(d["fullscreen"]==false,"%s fullscreen" % tag)
	check(str(d["bag_key"])=="white","%s bag_key" % tag)
	var unlocks: Dictionary = d["unlocks"]
	check(bool(unlocks.get("muyu",false)),"%s unlocks.muyu" % tag)
	var attrs: Dictionary = d["attributes"]
	check(int(attrs.get("vigor",0))==12,"%s attributes.vigor == 12" % tag)
	var home: Dictionary = d["home"]
	check(int(home.get("beds",0))==6 and str(home.get("prepared",""))=="","%s home defaults" % tag)
	var pocket: Dictionary = d["pocket"]
	check(str(pocket.get("key",""))=="white","%s pocket.key" % tag)
	var pocket_items: Array = pocket.get("items",[])
	check(pocket_items.is_empty(),"%s pocket is empty" % tag)
	var bags: Array = d["bags"]
	check(bags.size()==1,"%s keeps exactly one bag" % tag)
	if bags.size()==1:
		var bag: Dictionary = bags[0]
		var bag_items: Array = bag.get("items",[])
		check(bag_items.is_empty(),"%s bag is empty" % tag)
	var warehouse: Array = d["warehouse"]
	check(warehouse.is_empty(),"%s warehouse is empty" % tag)
	var history: Array = d["trade_history"]
	check(history.is_empty(),"%s trade_history is empty" % tag)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	cleanup()

	# === 1) 老档读入：旧字段不丢、新键默认 ==============================
	var p := fresh()
	p.apply_data(JSON.parse_string(LEGACY_JSON))
	check_legacy(p,"1")
	check(typeof(p.data["ashes"])==TYPE_INT,"1 ashes default is an int")
	check(int(p.data["ashes"])==0,"1 ashes defaults to 0")
	check(typeof(p.data["growth"])==TYPE_DICTIONARY,"1 growth default is a Dictionary")
	check((p.data["growth"] as Dictionary).is_empty(),"1 growth defaults to {}")

	# === 2) 老档 读 → 存 → 再读 回环 ====================================
	p.data["ashes"]=17
	p.data["growth"]={"ash_vein":2}
	p.save_profile()
	var on_disk := read_saved()
	check(int(on_disk.get("version",-1))==1,"2 the file on disk says version 1")
	check(on_disk.has("ashes") and on_disk.has("growth"),"2 the file on disk carries ashes and growth")
	var p2 := fresh()
	p2.load_profile()
	check_legacy(p2,"2")
	check(int(p2.data["ashes"])==17,"2 reload keeps ashes == 17")
	check(typeof(p2.data["ashes"])==TYPE_INT,"2 reload keeps ashes an int (not 17.0)")
	check(int((p2.data["growth"] as Dictionary).get("ash_vein",-1))==2,"2 reload keeps growth.ash_vein == 2")

	# === 3) version 缺失 / != 1 / 非整数：不得静默丢档 ====================
	var v2: Dictionary = JSON.parse_string(LEGACY_JSON)
	v2["version"]=2
	v2["coins"]=777
	v2["xp"]=1234
	v2["runs"]=9
	var p3 := fresh()
	p3.apply_data(v2)
	check(int(p3.data["version"])==1,"3 a version-2 file is normalised to version 1")
	check(int(p3.data["coins"])==777,"3 a version-2 file does NOT wipe coins (default is 160)")
	check(int(p3.data["xp"])==1234,"3 a version-2 file does NOT wipe xp")
	check(int(p3.data["runs"])==9,"3 a version-2 file does NOT wipe runs")
	check(str(p3.data["name"])=="守夜人","3 a version-2 file does NOT wipe the name")
	p3.save_profile()
	var p3b := fresh()
	p3b.load_profile()
	check(int(p3b.data["coins"])==777,"3 load+save+reload keeps the version-2 coins")
	check(int(p3b.data["version"])==1,"3 load+save+reload writes version 1")

	var no_version: Dictionary = JSON.parse_string(LEGACY_JSON)
	no_version.erase("version")
	no_version["coins"]=444
	var p4 := fresh()
	p4.apply_data(no_version)
	check(int(p4.data["version"])==1,"3 a version-less file is normalised to version 1")
	check(int(p4.data["coins"])==444,"3 a version-less file keeps its coins")

	var str_version: Dictionary = JSON.parse_string(LEGACY_JSON)
	str_version["version"]="1"
	str_version["coins"]=555
	var p5 := fresh()
	p5.apply_data(str_version)
	check(int(p5.data["version"])==1,"3 a string version cannot leak into the profile")
	check(typeof(p5.data["version"])==TYPE_INT,"3 version stays an int after a string version")
	check(int(p5.data["coins"])==555,"3 a string version does not block the rest of the import")

	# === 4) 垃圾输入与脏字段的实测行为 ==================================
	for junk in [null,"junk",[],42,true]:
		var pj := fresh()
		pj.apply_data(junk)
		check(int(pj.data["version"])==1,"4 junk input %s leaves version 1" % [junk])
		check(int(pj.data["coins"])==160,"4 junk input %s leaves the coins default" % [junk])
		check(int(pj.data["ashes"])==0,"4 junk input %s leaves ashes at 0" % [junk])
		check((pj.data["growth"] as Dictionary).is_empty(),"4 junk input %s leaves growth empty" % [junk])

	# JSON 里的 50 是 float -> 必须落成 int 50（契约 §4.1 的 float→int 纠正列表）
	var ashes_float: Dictionary = JSON.parse_string('{"version":1,"ashes":50.0}')
	var pf := fresh()
	pf.apply_data(ashes_float)
	check(typeof(pf.data["ashes"])==TYPE_INT,"4 ashes 50.0 becomes an int")
	check(int(pf.data["ashes"])==50,"4 ashes 50.0 becomes 50")

	var ashes_string: Dictionary = JSON.parse_string('{"version":1,"ashes":"50"}')
	var ps := fresh()
	ps.apply_data(ashes_string)
	note("ashes 为字符串 \"50\"：实测 %s (%s)" % [str(ps.data["ashes"]),type_string(typeof(ps.data["ashes"]))])
	check(int(ps.data["ashes"])==0,"4 a string ashes is dropped, not coerced (measured behaviour)")

	var ashes_negative: Dictionary = JSON.parse_string('{"version":1,"ashes":-5}')
	var pn := fresh()
	pn.apply_data(ashes_negative)
	check(int(pn.data["ashes"])==0,"4 a negative ashes clamps to 0")

	var ashes_huge: Dictionary = JSON.parse_string('{"version":1,"ashes":1000000000000.0}')
	var ph := fresh()
	ph.apply_data(ashes_huge)
	note("ashes 为 1e12：实测 %d（无上限钳制，服务端也不校验该键）" % int(ph.data["ashes"]))
	check(int(ph.data["ashes"])==1000000000000,"4 a huge ashes survives as an int (no clamp)")

	var ashes_array: Dictionary = JSON.parse_string('{"version":1,"ashes":[1,2]}')
	var pa := fresh()
	pa.apply_data(ashes_array)
	check(typeof(pa.data["ashes"])==TYPE_INT and int(pa.data["ashes"])==0,"4 an array ashes falls back to 0")

	var growth_shapes := {
		"array": JSON.parse_string('{"version":1,"growth":["a"]}'),
		"null": JSON.parse_string('{"version":1,"growth":null}'),
		"string": JSON.parse_string('{"version":1,"growth":"nope"}'),
		"number": JSON.parse_string('{"version":1,"growth":7}'),
	}
	for shape in growth_shapes:
		var pg := fresh()
		pg.apply_data(growth_shapes[shape])
		check((pg.data["growth"] as Dictionary).is_empty(),
			"4 a %s growth is sanitised to {}" % shape)

	var growth_mixed: Dictionary = JSON.parse_string('{"version":1,"growth":{"a":2,"b":-3,"c":"x","d":1.9,"e":0}}')
	var pgm := fresh()
	pgm.apply_data(growth_mixed)
	var gm: Dictionary = pgm.data["growth"]
	note("growth 混合值 {a:2,b:-3,c:'x',d:1.9,e:0}：实测 %s" % [str(gm)])
	check(int(gm.get("a",-1))==2,"4 a valid growth level survives")
	check(int(gm.get("d",-1))==1,"4 a float growth level is truncated to an int")
	check(not gm.has("b"),"4 a negative growth level is dropped")
	check(not gm.has("c"),"4 a non-numeric growth level is dropped")
	check(not gm.has("e"),"4 a zero growth level is dropped")

	var coins_string: Dictionary = JSON.parse_string('{"version":1,"coins":"999"}')
	var pc := fresh()
	pc.apply_data(coins_string)
	note("coins 为字符串 \"999\"：实测 %d（新档默认 160，脏值不导入）" % int(pc.data["coins"]))
	check(int(pc.data["coins"])==160,"4 a string coins falls back to the default (measured behaviour)")

	# === 5) save_profile() 把手改过的脏值拉回合法态 ======================
	var p6 := fresh()
	p6.data["version"]=3
	p6.data["growth"]={"ash_vein":2,"broken":-4,"junk":"x"}
	p6.data["ashes"]="17"
	p6.save_profile()
	var saved := read_saved()
	check(int(saved.get("version",-1))==1,"5 save_profile() forces version 1 onto disk")
	var saved_growth = saved.get("growth",null)
	check(saved_growth is Dictionary,"5 save_profile() writes growth as a Dictionary")
	if saved_growth is Dictionary:
		check(int(saved_growth.get("ash_vein",-1))==2,"5 save_profile() keeps a valid growth level")
		check(not saved_growth.has("broken"),"5 save_profile() drops a negative growth level")
		check(not saved_growth.has("junk"),"5 save_profile() drops a non-numeric growth level")
	check(int(saved.get("ashes",-1))==0,
		"5 save_profile() normalises a hand-edited ashes string to 0")
	var p6b := fresh()
	p6b.load_profile()
	check(int(p6b.data["version"])==1,"5 the tampered profile reads back as version 1")
	check(typeof(p6b.data["ashes"])==TYPE_INT,"5 the reloaded ashes is an int again")

	cleanup()
	for line in notes: print("MEASURED ",line)
	print("ROGUE PROFILE MIGRATION ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
