extends SceneTree
## Full-reserve reward trap (headless, no window).
##
## Before this fix a claim that `equip()` refused returned silently: the choice stayed open
## (so the reward was never lost) but nothing told the player why, the panel could not advance,
## and `loot_interact()`'s "no pending choice" guard left the offer sitting under their feet.
## Three things must hold now:
##   1. a refused claim keeps the choice AND publishes an actionable reason;
##   2. the anti-replay guard still ignores stale id/version clicks completely;
##   3. `rogue_selection_abandon` advances the room with no card selected, while "丢给队友"
##      remains the way to keep the item in the world.
var failures := 0
var checks := 0

const Equipment = preload("res://scripts/rogue_equipment.gd")

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)

func _initialize() -> void: call_deferred("run")

func make_session(seed_value: int):
	var s = TideSession.new()
	root.add_child(s)
	s.set_physics_process(false)
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2,"rogue_weapon":1})
	s.launch(false,seed_value)
	return s

## Mirrors exactly what `next_personal()` stores for a personal reward choice.
func open_offer(s, p: Dictionary, item: Dictionary, tier: int = 3) -> void:
	s.roguelike.loot_serial+=1
	p.rogue_selection={"id":s.roguelike.loot_serial,"version":0,"tier":tier,"category":"gear","personal":true,
		"offers":[{"name":Catalog.item_name(item),"desc":"","tier":tier,"item":item}]}

func payload_of(p: Dictionary) -> Dictionary:
	var selection: Dictionary=p.rogue_selection
	return {"id":selection.id,"version":selection.version,"index":0}

func snapshot(p: Dictionary, s) -> String:
	return var_to_str(p.rogue_selection)+"|"+str(s.raid.revision)+"|"+var_to_str(p.equipped.gear[0])+"|"+var_to_str(p.rogue_stash)

func run() -> void:
	var s = make_session(90210)
	var p: Dictionary=s.players[1]

	# Slot 0 is worn, so a new chest piece is exactly what needs a free reserve slot.
	check(s.roguelike.equip(s,p,Equipment.make_gear(0,3)), "the baseline armour equips into an empty slot")
	while p.rogue_stash.size()<12: p.rogue_stash.append(Equipment.make_gear(1,2))
	check(p.rogue_stash.size()==12, "the reserve is exactly full (12)")

	# ---------------------------------------------------------------- 1. refused claim
	open_offer(s,p,Equipment.make_gear(0,5))
	p.rogue_selection["error"]="stale"
	s.perform(1,"rogue_selection_take",payload_of(p))
	check(not p.rogue_selection.is_empty(), "a refused claim keeps the choice open (the reward is not lost)")
	var reason := str(p.rogue_selection.get("error",""))
	check(reason!="stale", "a fresh intent clears the previous refusal")
	check(reason!="" and ("行囊" in reason or "放弃" in reason), "the refusal names an actionable way out (got '%s')" % reason)
	check(p.rogue_stash.size()==12, "a refused claim does not disturb the reserve")
	check(int(p.equipped.gear[0].tier)==3, "a refused claim does not replace the worn item")
	check(int(s.raid.revision)>=0 and str(s.raid.phase)!="rogue_exit", "a refused claim does not advance the room by itself")

	# ---------------------------------------------------------------- 2. stale clicks
	open_offer(s,p,Equipment.make_gear(0,5))
	var before := snapshot(p,s)
	var revision := int(s.raid.revision)
	var stale := {"id":p.rogue_selection.id,"version":int(p.rogue_selection.version)+1,"index":0}
	s.perform(1,"rogue_selection_take",stale)
	s.perform(1,"rogue_selection_abandon",stale)
	check(snapshot(p,s)==before, "stale id/version clicks leave selection, revision, equipment and reserve untouched")
	check(int(s.raid.revision)==revision, "a stale click does not bump the raid revision")

	# ---------------------------------------------------------------- 3. abandon always advances
	s.raid.phase="rogue_reward"
	s.raid["reward_chest"]={}
	s.raid["reward_drops"]=[]
	var drops_before: int=s.raid.reward_drops.size()
	s.perform(1,"rogue_selection_abandon",{"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":-1})
	check(p.rogue_selection.is_empty(), "abandon closes the choice even with no card selected")
	check(int(s.raid.revision)>revision, "abandon bumps the raid revision so the panel rebuilds")
	check(s.raid.reward_drops.size()==drops_before, "abandon leaves no offer-carrying drop behind (one would block finish_rewards)")
	check(str(s.raid.phase)=="rogue_exit", "abandon lets the room advance (phase=%s)" % str(s.raid.phase))
	check(p.id in s.raid.reward_claims, "abandon is recorded like any other claim, so the exit is not blocked twice")

	# ---------------------------------------------------------------- 4. keeping it is still possible
	open_offer(s,p,Equipment.make_gear(0,5))
	s.perform(1,"rogue_selection_drop",payload_of(p))
	check(p.rogue_selection.is_empty(), "handing the card to the team closes the choice")
	var dropped: int=s.raid.reward_drops.size()
	check(dropped==drops_before+1, "the card is now a ground drop instead of being swallowed")
	var drop: Dictionary=s.raid.reward_drops.back()
	check(drop.offer.has("item") and drop.get("personal",false)==false, "the ground drop is non-personal, so any teammate can take it")
	# Freeing one reserve slot lets the very same item be taken after all.
	p.rogue_stash.pop_back()
	s.elapsed+=2.0
	s.perform(1,"rogue_loot",{})
	check(p.rogue_selection.is_empty(), "picking the drop back up resolves without opening another choice")
	check(s.raid.reward_drops.size()==dropped-1, "the pickup consumes the drop")
	check(int(p.equipped.gear[0].tier)==5, "the freed slot lets the new armour through (tier=%d)" % int(p.equipped.gear[0].tier))
	check(p.rogue_stash.size()==12, "the replaced item moves into the reserve as usual")

	print("FULL BAG: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
