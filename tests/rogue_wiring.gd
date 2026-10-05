extends SceneTree

## R2 验收：契约 §2/§3/§4 的新键是否建齐、类型/默认值是否正确、
## 快照往返后是否逐字段不变、`s.rogue_graph` 是否**不**进快照、
## 唯一新增的 s.rng 消耗点（每层首区抽变数）是否恰好一次且同种子可复现、
## 老档（version 1、无 ashes/growth）读入后旧字段不丢且新键取默认值。

var checks := 0
var failures := 0

const Variants = preload("res://scripts/rogue_variants.gd")

const RAID_KEYS := {
	"variant":TYPE_STRING, "variant_serial":TYPE_INT, "curse_serial":TYPE_INT,
	"seed_shared":TYPE_STRING, "daily":TYPE_BOOL, "node":TYPE_STRING, "depth":TYPE_INT,
	"pending_event":TYPE_DICTIONARY, "pending_forge":TYPE_DICTIONARY,
	"pending_gamble":TYPE_DICTIONARY, "mirror_state":TYPE_DICTIONARY, "graph_floor":TYPE_INT,
	"variants_seen":TYPE_ARRAY,
}
const PLAYER_KEYS := {
	"rogue_curses":TYPE_ARRAY, "rogue_ash_run":TYPE_INT, "rogue_mirror_used":TYPE_BOOL,
}

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func new_session(seed_value: int) -> TideSession:
	var t := TideSession.new()
	root.add_child(t)
	t.set_physics_process(false)
	t.solo({"hero":0,"mode":"roguelike"})
	t.launch(false,seed_value)
	return t

func variant_for(seed_value: int) -> String:
	var t := new_session(seed_value)
	var id := str(t.raid["variant"])
	t.queue_free()
	return id

func run() -> void:
	var s := new_session(4242)
	check(s.running,"Run starts")
	check(s.roguelike.active(s),"Roguelike mode is active")

	# --- §2 s.raid 的 12 个冻结键 -------------------------------------------
	for key in RAID_KEYS:
		check(s.raid.has(key),"raid has frozen key %s" % key)
		if s.raid.has(key):
			check(typeof(s.raid[key])==RAID_KEYS[key],"raid key type %s" % key)
	check(int(s.raid["variant_serial"])==1,"First floor rolled exactly one variant")
	check(int(s.raid["curse_serial"])==0,"curse_serial starts at 0")
	check(str(s.raid["seed_shared"])=="","seed_shared starts empty")
	check(s.raid["daily"]==false,"daily starts false")
	check(str(s.raid["node"])!="","R5 wires raid.node to the floor's entry node")
	check(str(s.raid["node"])==str(s.rogue_graph.get("entry","")),"raid.node tracks the authoritative graph")
	check(int(s.raid["depth"])==1,"depth starts at 1")
	check(int(s.raid["graph_floor"])==1,"graph_floor tracks the initialised floor")
	var pending: Dictionary=s.raid["pending_event"]
	check(pending.is_empty(),"pending_event starts empty")
	var forge: Dictionary=s.raid["pending_forge"]
	check(forge.is_empty(),"pending_forge starts empty")
	var gamble: Dictionary=s.raid["pending_gamble"]
	check(gamble.is_empty(),"pending_gamble starts empty")
	var mirror: Dictionary=s.raid["mirror_state"]
	check(mirror.is_empty(),"mirror_state starts empty")
	var rolled := Variants.active(s)
	check(not rolled.is_empty(),"raid.variant resolves to a table definition")
	check(str(s.raid["variant"])==str(rolled.get("id","")),"active() agrees with raid.variant")

	# --- §3 players[*] 的 3 个冻结键 ---------------------------------------
	var p: Dictionary=s.players[1]
	for key in PLAYER_KEYS:
		check(p.has(key),"player has frozen key %s" % key)
		if p.has(key):
			check(typeof(p[key])==PLAYER_KEYS[key],"player key type %s" % key)
	var curses: Array=p["rogue_curses"]
	check(curses.is_empty(),"rogue_curses starts empty")
	check(int(p["rogue_ash_run"])==0,"rogue_ash_run starts at 0")
	check(p["rogue_mirror_used"]==false,"rogue_mirror_used starts false")

	# --- 唯一 rng 消耗点：同层不重抽，换层重抽 ------------------------------
	var serial_before := int(s.raid["variant_serial"])
	var variant_before := str(s.raid["variant"])
	s.roguelike.enter(s)
	check(int(s.raid["variant_serial"])==serial_before,"Variant is not re-rolled inside one floor")
	check(str(s.raid["variant"])==variant_before,"Variant id is stable inside one floor")
	s.raid.floor=2
	s.raid.area=1
	s.roguelike.enter(s)
	check(int(s.raid["variant_serial"])==serial_before+1,"A new floor rolls a new variant")
	check(int(s.raid["graph_floor"])==2,"graph_floor follows the new floor")

	# --- 同种子可复现 + 不同种子能抽到不同变数 -----------------------------
	check(variant_for(4242)==variant_for(4242),"Same seed rolls the same variant")
	var table_ids := {}
	for def in Variants.table(): table_ids[str(def.id)]=true
	check(table_ids.size()>=3,"Variant table is populated")
	var seen := {}
	for i in 12:
		seen[variant_for(9000+i)]=true
	check(seen.size()>=2,"Different seeds can roll different variants")
	for id in seen:
		check(table_ids.has(id),"Rolled variant comes from the table: %s" % id)

	# --- 快照往返（走 snapshot() 的真实接收路径） ---------------------------
	var s2 := new_session(4242)
	var packet := var_to_bytes([s2.players,s2.enemies,s2.bullets,s2.world_drops,s2.ruins.chests,s2.ruins.shrines,s2.elapsed,s2.objectives,s2.threat,s2.results,s2.map_id,s2.raid,s2.ruins.sites])
	var c := TideSession.new()
	root.add_child(c)
	c.set_physics_process(false)
	c.running=true
	c.seed_value=s2.seed_value
	var compressed := packet.compress(FileAccess.COMPRESSION_GZIP)
	c.snapshot(compressed)
	# 契约 C1 的硬证明：整张节点图不在快照里，白名单长度仍是 13。
	var decoded = bytes_to_var(compressed.decompress_dynamic(2097152,FileAccess.COMPRESSION_GZIP))
	check(decoded is Array and (decoded as Array).size()==13,"Snapshot keeps its 13 whitelisted elements")
	if decoded is Array:
		var decoded_raid: Dictionary=(decoded as Array)[11]
		check(not decoded_raid.has("rogue_graph"),"Decoded raid has no rogue_graph key")
		check(not decoded_raid.has("graph"),"Decoded raid has no graph key")
		check(typeof(decoded_raid.get("node",""))==TYPE_STRING and str(decoded_raid.get("node",""))!="","Only node/depth ride inside raid")
		check(decoded_raid.has("variants_seen"),"The abyss-variant history rides inside raid")
	for key in RAID_KEYS:
		check(c.raid.has(key),"snapshot raid keeps %s" % key)
		if c.raid.has(key) and s2.raid.has(key):
			check(typeof(c.raid[key])==RAID_KEYS[key],"snapshot raid key type %s" % key)
	check(str(c.raid["variant"])==str(s2.raid["variant"]),"variant survives the snapshot")
	check(int(c.raid["variant_serial"])==int(s2.raid["variant_serial"]),"variant_serial survives the snapshot")
	check(int(c.raid["graph_floor"])==int(s2.raid["graph_floor"]),"graph_floor survives the snapshot")
	check(not c.raid.has("graph"),"No node graph is smuggled inside the raid packet")
	check(c.rogue_graph.is_empty(),"rogue_graph stays out of the snapshot on the client")
	check(c.players.has(1),"Snapshot restores the roster")
	var cp: Dictionary=c.players.get(1,{})
	for key in PLAYER_KEYS:
		check(cp.has(key),"snapshot player keeps %s" % key)
	c.queue_free()
	s2.queue_free()
	check(str(cp.get("rogue_curses",[]))==str(s2.players[1]["rogue_curses"]),"rogue_curses survives the snapshot")

	# --- §4 存档迁移：老档读入不丢字段、新键取默认值 ------------------------
	var prof := Profile.new()
	prof.path="user://rogue_wiring_profile.json"
	var legacy := '{"version":1,"name":"守夜人","coins":321,"xp":990,"runs":7,"extracts":3,"hero":1,"gear":2,"talents":[1,2,3],"volume":0.5,"voice_volume":0.9,"music_volume":0.7,"fullscreen":false,"best":12,"pocket":{"key":"white","items":[],"gw":4,"gh":4,"next":1},"bag_key":"white","bags":[{"key":"white","items":[],"next":1}],"unlocks":{"muyu":true},"attributes":{"vigor":2},"home":{},"warehouse":[],"trade_history":[]}'
	prof.apply_data(JSON.parse_string(legacy))
	check(int(prof.data["version"])==1,"Profile version stays 1")
	check(int(prof.data["coins"])==321,"Legacy coins survive")
	check(int(prof.data["xp"])==990,"Legacy xp survives")
	check(int(prof.data["runs"])==7 and int(prof.data["best"])==12,"Legacy counters survive")
	check(int(prof.data["hero"])==1 and int(prof.data["gear"])==2,"Legacy hero/gear survive")
	check(str(prof.data["name"])=="守夜人","Legacy name survives")
	check(bool(prof.data["unlocks"].get("muyu",false)),"Legacy unlocks survive")
	check(int(prof.data["talents"][1])==2,"Legacy talents survive")
	check(typeof(prof.data["ashes"])==TYPE_INT,"ashes default is an int")
	check(int(prof.data["ashes"])==0,"ashes defaults to 0")
	var growth: Dictionary=prof.data["growth"]
	check(growth.is_empty(),"growth defaults to {}")

	# 老档 → 存 → 再读回环
	prof.save_profile()
	var prof2 := Profile.new()
	prof2.path=prof.path
	prof2.load_profile()
	check(int(prof2.data["coins"])==321,"Reload keeps coins")
	check(int(prof2.data["ashes"])==0,"Reload keeps the ashes default as an int")
	var growth2: Dictionary=prof2.data["growth"]
	check(growth2.is_empty(),"Reload keeps growth empty")

	# 有灰烬/成长进度时也要能落盘读回
	prof.data["ashes"]=17
	prof.data["growth"]={"ash_vein":2}
	prof.save_profile()
	var prof3 := Profile.new()
	prof3.path=prof.path
	prof3.load_profile()
	check(int(prof3.data["ashes"])==17,"ashes round-trips through the save file")
	check(int(prof3.data["growth"].get("ash_vein",-1))==2,"growth round-trips through the save file")
	check(typeof(prof3.data["ashes"])==TYPE_INT,"ashes stays an int after a JSON reload")
	DirAccess.remove_absolute(prof.path)
	DirAccess.remove_absolute(prof.path+".tmp")

	s.queue_free()
	await process_frame
	print("ROGUE WIRING ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
