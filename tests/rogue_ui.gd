extends SceneTree
## R7 · 魔境 UI/HUD 验收（**无窗口**：`--headless --path . --script tests/rogue_ui.gd`）
##
## Covers the whole R7 surface without opening a window:
##   1. the view-model in `scripts/rogue_ui_model.gd` (pure: HUD strings, event view,
##      growth rows, seed/每日挑战 helpers, frozen action payloads);
##   2. the real `main.tscn` — a seeded launch through 种子页 -> 出发, then the HUD
##      lines, the 幽暗异事 panel and the 灰烬成长树 modal, including the
##      `revision` replay guard on every dispatched action.
##
## The action names asserted here are frozen by the contract
## (`rogue_event` / `rogue_growth` / `rogue_seed` / `rogue_daily`). The in-raid
## handlers are wired by the W1 round; until then `roguelike.choose()` treats an
## unknown kind as a safe no-op, which this test pins down as well.

const Model = preload("res://scripts/rogue_ui_model.gd")
const Growth = preload("res://scripts/rogue_growth.gd")
const Events = preload("res://scripts/rogue_events.gd")
const Daily = preload("res://scripts/rogue_daily.gd")
const Curses = preload("res://scripts/rogue_curses.gd")

const FORBIDDEN := ["hit_radius", "hit_zone", "hitboxes", "collision_radius", "zone", "bolt"]

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	model_checks()
	await app_checks()
	print("ROGUE UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures>0 else 0)

# ------------------------------------------------------------------ 1. view-model

func model_checks() -> void:
	var raid := {"variant":"", "room":"curse", "floor":2, "depth":3, "revision":4, "pending_event":{}, "daily":false, "seed_shared":""}
	var names := {"curse":"诅咒回廊", "event":"幽暗异事", "forge":"熔炉工坊"}

	check(Model.variant_line(raid).contains("未显现"), "an unrolled variant renders a placeholder, not an empty string")
	raid["variant"]="fog"
	check(Model.variant_line(raid).contains("雾障"), "a rolled variant renders its table name")
	check(Model.variant_line(raid)==("深渊变数 · "+str(Model.describe_variant("fog").get("label",""))), "the variant line is exactly the shared label")
	raid["variant"]="no_such_variant"
	check(Model.variant_line(raid).contains("未知"), "an unknown variant id is reported instead of crashing")
	raid["variant"]=""

	check(Model.curses_text({"rogue_curses":[]})=="诅咒 · 无", "no curses reads as 无")
	var lines := Model.curses_lines({"rogue_curses":["CU01","CU02"]})
	check(lines.size()==3, "the curse summary is a header plus one line per curse")
	check(lines[0].contains("2 / 4"), "the curse header counts against the cap")
	check(lines[1].contains(str(Curses.find("CU01").get("name",""))), "each curse line names the curse")

	check(Model.ash_line({"rogue_ash_run":7},{"ashes":13})=="灰烬 · 本局 7 · 累计 13", "run ash and banked ash are shown separately")
	check(Model.ash_line({},{})==Model.ash_line({},{"ashes":0}), "a missing profile still renders the ash line")

	check(Model.node_line(raid,names).contains("第 2 层"), "the route line names the floor")
	check(Model.node_line(raid,names).contains("诅咒回廊"), "the route line names the new room kinds")
	check(Model.node_line({"room":"forge"},names).contains("熔炉工坊"), "every new room kind maps to a name")
	check(Model.node_line({"room":"mystery"},names).contains("mystery"), "an unmapped room degrades to its id")
	check(Model.floor_line({"floor":2,"area":8},9)=="第 2 / 5 层 · 第 8 / 9 区", "the floor line takes its denominator from the graph, not from a constant")

	check(Model.seed_line({"seed_shared":"","daily":false})=="", "no seed line for a plain random run")
	check(Model.seed_line({"seed_shared":"CT-1A2B3C4D-5","daily":false}).contains("分享种子"), "a shared seed is labelled")
	check(Model.seed_line({"seed_shared":"CT-1A2B3C4D-5","daily":true}).contains("每日挑战"), "a daily run is labelled")

	# 事件房视图
	check(not Model.event_active({}), "no pending event means the panel stays closed")
	var pending := {"room":"event","revision":9,"pending_event":{"id":"EV01","revision":9,"offer":[{"index":0,"name":"A","desc":"B"},{"index":1,"name":"C","desc":"D"}]}}
	check(Model.event_active(pending), "a pending event opens the panel")
	# 新语义（原文只判 "pending 非空"）：还必须"确实站在事件房"且报价 revision 与当前 revision 一致，
	# 否则上一个房间残留的报价会把整局后续所有房间的面板顶掉（main.gd 在 event_active 处直接 return）。
	var leftover := {"room":"forge","revision":9,"pending_event":{"id":"EV01","revision":9,"offer":[{"index":0,"name":"A","desc":"B"}]}}
	check(not Model.event_active(leftover), "an offer left over in another room must not hijack the panel")
	var stale := {"room":"event","revision":12,"pending_event":{"id":"EV01","revision":9,"offer":[{"index":0,"name":"A","desc":"B"}]}}
	check(not Model.event_active(stale), "an offer stamped with an older revision keeps the panel closed")
	check(Model.event_title(pending)=="EV01" or Model.event_title(pending)!="", "the panel has a title")
	var orphan := Model.event_options(null,{},{"pending_event":{"offer":[{"index":0,"name":"A","desc":"B"}]}})
	check(orphan.size()==1, "an offer without a table id still renders its options")
	check(not bool(orphan[0].get("enabled",true)), "an unverifiable option is not selectable")
	check(Model.event_options(null,{},{"pending_event":{}}).is_empty(), "no offer means no options")
	check(Model.require_text({"require":{"gold":120,"flask":30}}).contains("120"), "option requirements are spelled out")
	check(Model.require_text({})=="", "an option without a requirement adds no text")

	# 成长树视图
	var empty_rows := Model.growth_rows({})
	check(empty_rows.size()==Growth.ids().size(), "the growth view lists every node")
	check(empty_rows.size()>=12, "the growth tree still has at least twelve nodes")
	for row in empty_rows:
		check(row.has("id") and row.has("level") and row.has("cost") and row.has("reason") and row.has("can_buy"), "a growth row carries the frozen keys: "+str(row.get("id","?")))
		check(bool(row.can_buy)==(str(row.reason)==""), "can_buy is exactly the empty reason: "+str(row.get("id","?")))
	check(Model.growth_button_text({"can_buy":true,"cost":60})=="60 灰烬", "an affordable node shows its price")
	check(Model.growth_button_text({"can_buy":false,"reason":"maxed"})=="已满级", "a maxed node says so")
	check(Model.growth_button_text({"can_buy":false,"reason":"ashes"})=="灰烬不足", "an unaffordable node says why")
	check(Model.growth_button_text({"can_buy":false,"reason":"requires"})=="需要前置节点", "a gated node says why")
	check(Model.growth_summary({"ashes":12}).contains("满树"), "the growth header shows the tree total")

	# 种子与每日挑战
	check(Model.seed_error("")!="", "an empty seed is refused")
	check(Model.seed_error("0")!="", "seed 0 is refused instead of silently becoming random")
	check(Model.seed_error("-5")!="", "a negative seed is refused")
	check(Model.seed_error("not-a-seed")!="", "garbage is refused")
	check(Model.seed_error("2147483648")!="", "a seed above the daily range is refused")
	check(Model.seed_error("123456")=="", "a plain decimal seed is accepted")
	check(Model.seed_error(Daily.encode(7))=="", "a share string is accepted")
	check(Model.parse_seed(Daily.encode(424242))==424242, "encode/parse round-trips through the model")
	check(Model.share_of(0)=="", "seed 0 has no share string")
	check(Model.copy_text(0,false)=="", "there is nothing to copy before a seed is chosen")
	check(Model.pending_seed_text(0,false).contains("随机"), "the unset state explains that runs are random")
	check(Model.pending_seed_text(123456,false).contains("CT-"), "the armed state shows the share string")
	check(Model.pending_seed_text(0,true).contains("每日挑战"), "the daily state is labelled")
	check(Model.seed_button_text(0,false)=="种子 · 每日挑战", "the setup entry has a stable default label")
	check(Model.seed_button_text(123456,false).contains("CT-"), "the setup entry shows the armed seed")
	check(Model.daily_seed()>0, "the daily seed is non-zero")
	check(Model.daily_seed()==Daily.seed_for(Model.daily_date()), "the daily seed is derived from the UTC date")
	check(Model.daily_date()==Daily.utc_today(), "the daily page reports the UTC date")
	check(Model.seed_hint().contains("房主"), "the hint explains that the host owns the seed")

	# 动作 payload 冻结 + 判定几何红线
	var event_payload := Model.event_payload(raid,2)
	check(int(event_payload.get("index",-1))==2 and int(event_payload.get("revision",-1))==4, "the event payload carries index and revision")
	var growth_payload := Model.growth_payload(raid,"ash_vein")
	check(str(growth_payload.get("id",""))=="ash_vein" and int(growth_payload.get("revision",-1))==4, "the growth payload carries id and revision")
	check(bool(growth_payload.get("applied",false)), "the growth payload tells the host the client already applied it")
	for payload in [event_payload,growth_payload]:
		for key in payload:
			check(str(key) not in FORBIDDEN, "no UI payload carries hit geometry: "+str(key))
	check(Model.ACTION_EVENT=="rogue_event" and Model.ACTION_GROWTH=="rogue_growth", "the frozen action names are unchanged")
	check(Model.ACTION_SEED=="rogue_seed" and Model.ACTION_DAILY=="rogue_daily", "the frozen seed/daily action names are unchanged")

# ------------------------------------------------------------------ 2. real main scene

func app_checks() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-ui.json"
	root.add_child(app)
	await process_frame

	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.set_physics_process(false)

	# ---- 种子页 / 每日挑战 -> 出发 -------------------------------------------------
	app.show_rogue_setup()
	check(app.page_name=="rogue_setup", "the setup page opens")
	check(app.find_child("RogueSeedButton",true,false)!=null, "the setup page exposes the seed entry")
	check(app.find_child("RogueGrowthButton",true,false)!=null, "the setup page exposes the growth-tree entry")

	app.show_rogue_seed_page()
	check(app.page_name=="rogue_seed", "the seed page opens")
	check(is_instance_valid(app.rogue_seed_field), "the seed page builds an input field")
	check(app.find_child("RogueSeedInput",true,false)!=null, "the seed input is named for the visual test")
	check(app.find_child("RogueDailyPick",true,false)!=null, "the seed page exposes the daily entry")

	app.rogue_seed_field.text=""
	app.apply_custom_seed()
	check(app.rogue_seed_pending==0, "an empty seed never arms a launch")
	check(app.page_name=="rogue_seed", "a refused seed keeps the player on the seed page")
	app.rogue_seed_field.text="0"
	app.apply_custom_seed()
	check(app.rogue_seed_pending==0 and app.page_name=="rogue_seed", "seed 0 is refused rather than becoming a random run")
	app.rogue_seed_field.text="not-a-seed"
	app.apply_custom_seed()
	check(app.rogue_seed_pending==0, "garbage never arms a launch")

	var share := Daily.encode(987654)
	app.rogue_seed_field.text=share
	app.apply_custom_seed()
	check(app.rogue_seed_pending==987654, "a share string arms the exact seed")
	check(app.page_name=="rogue_setup", "accepting a seed returns to the setup page")
	var seed_entry := app.find_child("RogueSeedButton",true,false)
	check(seed_entry!=null and share in seed_entry.text, "the setup page shows the armed seed on its entry")

	app.start_rogue()
	check(app.session.running, "出发 starts the raid")
	check(app.session.seed_value==987654, "the armed seed reaches session.seed_value")
	check(app.rogue_seed_pending==0, "the armed seed is consumed by the launch")
	check(app.session.raid.get("mode","")=="roguelike", "the run is a roguelike run")
	await process_frame

	# ---- HUD lines -----------------------------------------------------------------
	for key in ["rogue_variant","rogue_curses","rogue_ash","rogue_node","rogue_seed"]:
		check(app.hud.has(key), "the HUD carries the %s line" % key)
	check(app.find_child("RogueVariant",true,false)!=null, "the variant line is named")
	check(app.find_child("RogueNode",true,false)!=null, "the route line is named")

	var p: Dictionary=app.session.players[app.session.my_id()]
	if not p.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})

	app.session.raid["variant"]=""
	app.update_hud()
	check(app.hud.rogue_variant.text.contains("未显现"), "the HUD renders an unrolled variant")
	app.session.raid["variant"]="fog"
	app.update_hud()
	check(app.hud.rogue_variant.text.contains("雾障"), "the HUD renders the rolled variant")
	check(app.hud.rogue_variant.text==("深渊变数 · "+str(Model.describe_variant("fog").get("label",""))), "the HUD variant line matches the shared model")

	p["rogue_curses"]=["CU01"]
	app.update_hud()
	check(app.hud.rogue_curses.text.contains("1 / 4"), "the HUD counts the carried curses")
	check(app.hud.rogue_curses.text.contains(str(Curses.find("CU01").get("name",""))), "the HUD names the carried curse")
	p["rogue_curses"]=[]
	app.update_hud()
	check(app.hud.rogue_curses.text.contains("无"), "the HUD states when there are no curses")

	p["rogue_ash_run"]=7
	app.profile.data["ashes"]=13
	app.update_hud()
	check(app.hud.rogue_ash.text=="灰烬 · 本局 7 · 累计 13", "the HUD splits run ash from banked ash")

	app.session.raid["room"]="curse"
	app.session.raid["floor"]=2
	app.session.raid["depth"]=3
	app.update_hud()
	check(app.hud.rogue_node.text.contains("第 2 层") and app.hud.rogue_node.text.contains("诅咒回廊"), "the HUD reports the node-graph position")
	check(app.rogue_total_nodes()>=35 and app.rogue_total_nodes()<=50, "the results denominator follows the node graph (7~10 nodes x 5 floors)")
	var room_total := int(app.session.roguelike.depth_count(app.session))
	check(room_total>=7 and room_total<=10, "the live floor reports its own room count")
	check(app.hud.time.text.contains("/ %d 区" % room_total), "the HUD floor line uses the graph's room count")

	app.session.raid["seed_shared"]=share
	app.session.raid["daily"]=false
	app.update_hud()
	check(app.hud.rogue_seed.text.contains("分享种子") and app.hud.rogue_seed.text.contains(share), "the HUD shows the shared seed")

	# ---- 幽暗异事 面板 --------------------------------------------------------------
	# 新语义：面板要求"确实站在事件房(room=='event')"且报价 revision 与 raid.revision 一致。
	# 上一段为 HUD 把 room 设成了 curse —— 先确认这种残留报价不会接管面板，再真正走进事件房。
	app.session.raid["room"]="curse"
	Events.roll_offer(app.session)
	app.update_rogue_hud(p)
	check(app.find_child("RogueEventOption0",true,false)==null, "an offer left over in another room must not open the event panel")
	app.session.raid["room"]="event"
	var offer: Dictionary=Events.roll_offer(app.session)
	check(not offer.is_empty(), "an event offer can be rolled")
	app.update_rogue_hud(p)
	var option_count: int=(offer.get("offer",[]) as Array).size()
	check(app.rogue_event_buttons.size()==option_count, "the event panel builds one button per option")
	check(option_count>0, "the rolled event has options")
	for i in app.rogue_event_buttons.size():
		check(app.rogue_event_buttons[i].name=="RogueEventOption%d" % i, "the event buttons are named: %d" % i)
	check(app.find_child("RogueEventOption0",true,false)!=null, "the event panel is reachable by name")
	var payload := Model.event_payload(app.session.raid,0)
	check(int(payload.get("revision",-1))==int(app.session.raid.revision), "the event payload carries the live revision")

	var before_revision := int(app.session.raid.revision)
	var before_gold := int(p.rogue_gold)
	var before_event: Dictionary=(app.session.raid.pending_event as Dictionary).duplicate(true)
	app.session.action(Model.ACTION_EVENT,{"index":0,"revision":before_revision-1})
	check(int(app.session.raid.revision)==before_revision, "a stale event click cannot advance the revision")
	check((app.session.raid.pending_event as Dictionary)==before_event, "a stale event click leaves the offer intact")
	check(int(p.rogue_gold)==before_gold, "a stale event click cannot move currency")

	app.session.action(Model.ACTION_EVENT,Model.event_payload(app.session.raid,0))
	check(int(p.hp)>=1, "resolving an event keeps the Watcher alive")
	check(int(p.rogue_gold)>=0, "resolving an event cannot drive currency negative")
	var consumed := (app.session.raid.pending_event as Dictionary).is_empty()
	if consumed:
		check(int(app.session.raid.revision)>before_revision, "a resolved event advances the revision")
	else:
		check(int(app.session.raid.revision)==before_revision, "an unwired handler is a safe no-op")
	check(int(app.session.raid.revision)<=before_revision+1, "an event resolves at most once")

	# A kind the W1 round has not implemented yet must not corrupt anything.
	var unknown_revision := int(app.session.raid.revision)
	app.session.action(Model.ACTION_SEED,{"text":share,"revision":unknown_revision})
	app.session.action(Model.ACTION_DAILY,{"daily":true,"revision":unknown_revision})
	check(int(app.session.raid.revision)<=unknown_revision+1, "unwired UI actions stay safe")
	check(int(session_gold(app,p))>=0, "unwired UI actions cannot corrupt the wallet")
	app.session.raid["pending_event"]={}

	# ---- 灰烬成长树 -----------------------------------------------------------------
	app.profile.data["ashes"]=5000
	app.profile.data["growth"]={}
	app.show_growth_tree()
	check(app.rogue_growth_buttons.size()==Growth.ids().size(), "every growth node gets a buy button")

	var rows: Array=Model.growth_rows(app.profile.data)
	var root_id := ""
	for row in rows:
		if (row.requires as Array).is_empty() and bool(row.can_buy):
			root_id=str(row.id)
			break
	check(root_id!="", "at least one root node is affordable with 5000 ash")
	var before_level := Growth.level_of(app.profile.data,root_id)
	var before_ash := int(app.profile.data["ashes"])
	var cost := Growth.cost_for(root_id,before_level)
	check(cost>0, "the root node has a positive price")
	app.buy_growth_node(root_id)
	check(Growth.level_of(app.profile.data,root_id)==before_level+1, "buying raises the node level")
	check(int(app.profile.data["ashes"])==before_ash-cost, "buying deducts exactly the price")
	check(int(app.profile.data.get("version",1))==1, "the profile keeps version 1")
	check(app.rogue_growth_buttons.has(root_id), "the panel is rebuilt after a purchase")

	app.profile.data["ashes"]=0
	var blocked := ""
	for row in Model.growth_rows(app.profile.data):
		if str(row.reason)=="ashes":
			blocked=str(row.id)
			break
	check(blocked!="", "a poor Watcher still has unaffordable nodes")
	app.show_growth_tree()
	check(app.rogue_growth_buttons[blocked].disabled, "an unaffordable node is disabled")
	check(app.rogue_growth_buttons[blocked].text=="灰烬不足", "an unaffordable node explains why")
	check(app.rogue_growth_buttons[blocked].tooltip_text=="灰烬不足", "the disabled node carries the reason as a tooltip")
	var growth_action := Model.growth_payload(app.session.raid,root_id)
	check(int(growth_action.get("revision",-1))==int(app.session.raid.revision), "an in-raid growth purchase ships the revision")
	check(bool(growth_action.get("applied",false)), "an in-raid growth purchase is marked as already applied")

	# ---- 每日挑战 -------------------------------------------------------------------
	app.profile.data["ashes"]=0
	app.choose_daily_seed(true)
	check(app.rogue_daily_pending, "choosing the daily challenge arms it")
	check(app.rogue_seed_pending==0, "the daily choice clears any custom seed")
	check(app.rogue_launch_seed()==Model.daily_seed(), "a daily run launches with the UTC seed")
	check(app.rogue_launch_seed()>0, "the daily seed is never zero")
	app.rogue_daily_pending=false
	app.rogue_seed_pending=0

	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.5).timeout

func session_gold(_session, p: Dictionary) -> int:
	return int(p.get("rogue_gold",0))
