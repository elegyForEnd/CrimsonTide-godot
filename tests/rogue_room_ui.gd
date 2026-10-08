extends SceneTree
## R7b · the three dedicated rooms' UI (游方锻炉 / 赌徒营帐 / 镜中挑战) and the profile
## channel that makes ash actually bank.
##
##   headless:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/rogue_room_ui.gd
##   visual:    tests/rogue_room_ui_visual.gd (real window, screenshots)
##
## Everything asserted here lives in the view-model (`scripts/rogue_room_ui.gd`) and in
## `main.gd`'s `attach_profile()` / `on_finished()`, so the whole surface is checkable
## without drawing a single widget — except for the few checks that go through the real
## `main.tscn` instance to prove the wiring, not just the model.

const RoomUi = preload("res://scripts/rogue_room_ui.gd")
const Growth = preload("res://scripts/rogue_growth.gd")

var checks := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(reason)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Node=load("res://scenes/main.tscn").instantiate()
	app.profile.path="user://test-rogue-room-ui.json"
	root.add_child(app)
	app.session.solo({"hero":0,"mode":"roguelike"})
	app.session.launch(false,424242)
	app.session.set_physics_process(false)
	await process_frame
	var p: Dictionary=app.session.players[app.session.my_id()]
	if not p.get("rogue_selection",{}).is_empty():
		app.session.perform(app.session.my_id(),"rogue_selection_take",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":0})
	p["status"]="active"

	# ------------------------------------------------------------ 1. frozen surface
	check(RoomUi.handled("forge") and RoomUi.handled("gamble") and RoomUi.handled("mirror"), "the three dedicated rooms are handled by this panel")
	check(not RoomUi.handled("shop") and not RoomUi.handled("combat") and not RoomUi.handled("boss"), "every other room keeps its existing UI")
	check(RoomUi.action_for("forge")=="rogue_forge" and RoomUi.action_for("gamble")=="rogue_gamble" and RoomUi.action_for("mirror")=="rogue_mirror", "the action names are the frozen ones")

	# ------------------------------------------------------------ 2. forge
	app.session.raid["room"]="forge"
	app.session.raid["floor"]=3
	app.session.raid["depth"]=3
	p["rogue_gold"]=0
	var poor := RoomUi.rows("forge",app.session.raid,RoomUi.context_of(app.session,p))
	check(poor.size()==4, "the forge quotes its four services")
	check(not bool(poor[0].enabled) and str(poor[0].reason).contains("魔晶不足"), "a broke player is told *why* the first service is locked")
	check(bool(poor[3].enabled) and int(poor[3].cost)==0, "转移锻造 stays free")
	p["rogue_gold"]=100000
	var rich := RoomUi.rows("forge",app.session.raid,RoomUi.context_of(app.session,p))
	check(bool(rich[0].enabled) and bool(rich[1].enabled), "a rich player may buy forge points")
	check(str(rich[0].action)=="rogue_forge", "the forge row ships the forge action")
	check(int(rich[0].payload.index)==0 and int(rich[0].payload.revision)==int(app.session.raid.revision), "the forge payload carries the index plus the raid revision")
	check(not bool(rich[2].enabled) or int(rich[2].cost)>0, "the direct smith quotes a price instead of firing for free")

	# ------------------------------------------------------------ 3. the raid's own quote wins
	app.session.roguelike.open_room(app.session)
	app.session.roguelike.refresh_dedicated(app.session,p)
	check(app.session.raid.pending_forge.has("offers"), "open_room() quotes the forge offers for the raid")
	var quoted := RoomUi.rows("forge",app.session.raid,RoomUi.context_of(app.session,p))
	check(quoted.size()==(app.session.raid.pending_forge.offers as Array).size(), "the panel draws the raid's own quote")
	check(int(quoted[0].payload.revision)==int(app.session.raid.pending_forge.revision), "the revision shown is the one the guard will compare")

	# ------------------------------------------------------------ 4. gamble
	app.session.raid["room"]="gamble"
	p["rogue_gold"]=500
	p["rogue_ash_run"]=0
	if not p.equipped.weapon.is_empty(): p.equipped.weapon["tier"]=1
	var wagers := RoomUi.rows("gamble",app.session.raid,RoomUi.context_of(app.session,p))
	check(wagers.size()==3, "the tent quotes three wagers")
	check(str(wagers[0].desc).contains("胜率") and str(wagers[0].desc).contains("期望"), "the win rate and the expectation are printed, not hidden")
	check(not bool(wagers[2].enabled) and str(wagers[2].reason).contains("灰烬不足"), "the ash wager is locked out while the run holds no ash")
	check(int(wagers[0].payload.index)==0 and int(wagers[1].payload.index)==1, "each wager ships its own index")
	check(str(wagers[0].action)=="rogue_gamble", "the wager row ships the gamble action")

	# ------------------------------------------------------------ 5. mirror: two clicks
	app.session.raid["room"]="mirror"
	p["rogue_mirror_used"]=false
	app.session.raid["mirror_state"]={}
	var fresh := RoomUi.rows("mirror",app.session.raid,RoomUi.context_of(app.session,p))
	check(fresh.size()==1 and bool(fresh[0].enabled), "a fresh run may accept the mirror duel")
	check(not fresh[0].payload.has("index"), "the mirror payload needs no index")
	check(int(fresh[0].payload.revision)==int(app.session.raid.revision), "the mirror payload carries the raid revision")
	app.session.raid["mirror_state"]={"active":true,"owner":int(p.id),"round":1,"settled":false}
	var armed := RoomUi.rows("mirror",app.session.raid,RoomUi.context_of(app.session,p))
	check(str(armed[0].name).contains("战斗"), "the mirror row describes the ongoing fight")
	check(not bool(armed[0].enabled), "buttons cannot settle an active fight")
	app.session.raid["mirror_state"]={"active":false,"owner":int(p.id),"round":2,"settled":true}
	p["rogue_mirror_used"]=true
	var spent := RoomUi.rows("mirror",app.session.raid,RoomUi.context_of(app.session,p))
	check(not bool(spent[0].enabled) and str(spent[0].reason).contains("已经挑战过"), "a used mirror says so instead of looking clickable")

	# ------------------------------------------------------------ 6. repaint key
	var sig_before := RoomUi.signature("forge",app.session.raid,RoomUi.context_of(app.session,p))
	p["rogue_gold"]=1
	var sig_after := RoomUi.signature("forge",app.session.raid,RoomUi.context_of(app.session,p))
	check(sig_before!=sig_after, "a change of purse repaints the room panel")
	check(str(RoomUi.footer("mirror",app.session.raid,"rogue_reward")).contains("镜像") or RoomUi.footer("mirror",app.session.raid,"rogue_reward")!="", "the mirror footer keeps telling the player what the next click does")

	# ------------------------------------------------------------ 7. profile channel
	app.attach_profile()
	var attached: Variant=app.session.profile_data()
	check(attached is Dictionary and attached==app.profile.data, "attach_profile() hands the local save to the session")
	app.session.raid["cleared"]=0
	app.session.raid["floor"]=2
	app.profile.data["growth"]={}
	var ash_before := int(app.profile.data.get("ashes",0))
	var granted := Growth.grant(app.session,p)
	check(granted>0, "a settled run produces ash")
	check(int(app.profile.data.get("ashes",0))==ash_before+granted, "the ash is banked through the profile channel, not only into p.rogue_ash_run")
	# Buy a real node through the real purchase path, then prove the run pays it in. Before
	# the profile channel existed this whole loop was a no-op: `reset()` scaled by an empty
	# growth table and the player never saw the coins they had bought.
	app.profile.data["growth"]={}
	app.profile.data["ashes"]=9999
	app.attach_profile()
	app.session.roguelike.reset(app.session)
	var gold_plain := int(app.session.players[app.session.my_id()].rogue_gold)
	check(Growth.buy(app.profile.data,"coin_purse"), "coin_purse is purchasable with enough ash")
	app.attach_profile()
	app.session.roguelike.reset(app.session)
	var gold_boost := int(app.session.players[app.session.my_id()].rogue_gold)
	var expected := int(Growth.power(app.profile.data).get("start_coins",0))
	check(expected>0, "the bought purse is worth something")
	check(gold_boost==gold_plain+expected, "the growth tree's starting gold actually applies now (it used to be a silent no-op)")

	print("ROGUE ROOM UI: %d checks, %d failures" % [checks,failures])
	app.session.disconnect_room()
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit(1 if failures>0 else 0)
