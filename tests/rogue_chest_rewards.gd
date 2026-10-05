extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func selection_payload(p: Dictionary, index: int = 0) -> Dictionary:
	return {"id":p.rogue_selection.id,"version":p.rogue_selection.version,"index":index}
func run() -> void:
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero":0,"mode":"roguelike","rogue_rerolls":2})
	s.launch(false,1729)
	s.set_physics_process(false)
	var p: Dictionary=s.players[1]
	var ally: Dictionary=s.make_player(2,{"hero":1,"name":"Ally"})
	s.players[2]=ally
	# Reset initializes all party members' run fields.
	s.roguelike.reset(s)
	p=s.players[1]
	ally=s.players[2]
	s.enemies.clear()
	s.roguelike.clear_room(s)
	check(s.raid.offers.is_empty() and not s.raid.reward_chest.opened,"Clear spawns chest without opening choices")
	var chest: Dictionary=s.raid.reward_chest
	p.p=Vector2(180,400)
	s.perform(1,"rogue_loot")
	check(not chest.opened,"Distant opening rejected")
	p.p=chest.p
	s.perform(1,"rogue_loot")
	var count: int=s.raid.reward_drops.size()
	check(chest.opened and count==3,"Chest drops at most one packet per category, three total")
	var categories := {}
	for packet in s.raid.reward_drops: categories[packet.category]=true
	check(categories.size()==3 and categories.has("gear") and categories.has("weapon") and categories.has("boon"),"One equipment, weapon and talent packet")
	s.perform(1,"rogue_loot")
	check(s.raid.reward_drops.size()==count,"Chest cannot reroll or duplicate on reopening")
	check(p.rogue_selection.is_empty(),"Packets cannot be picked before landing")
	s.elapsed+=2
	var first: Dictionary=s.raid.reward_drops[0]
	p.p=first.p
	ally.p=first.p
	s.perform(1,"rogue_loot")
	check(p.rogue_selection.offers.size()==3 and s.raid.reward_drops.size()==count-1,"Pickup atomically reserves one packet with three choices")
	var types := {}
	for offer in p.rogue_selection.offers:
		types["boon" if offer.has("boon") else offer.item.kind]=true
		check(offer.tier==first.tier,"All choices retain packet quality")
	check(types.size()==1 and types.has(first.category),"Packet offers only its own category")
	var distinct := {}
	for offer in p.rogue_selection.offers: distinct[offer.name]=true
	check(distinct.size()==3,"Three distinct same-category choices")
	var stale: Dictionary=selection_payload(p)
	s.perform(1,"rogue_selection_reroll",stale)
	check(p.rogue_rerolls==1 and p.rogue_selection.version==1,"Personal reroll consumes one card")
	s.perform(1,"rogue_selection_take",stale)
	check(not p.rogue_selection.is_empty(),"Stale click rejected after reroll")
	var preserved: Array=p.rogue_selection.offers.duplicate(true)
	s.perform(1,"rogue_selection_return",selection_payload(p))
	check(p.rogue_selection.is_empty() and 1 not in s.raid.reward_claims,"Putting packet back keeps room claim pending")
	var returned: Dictionary=s.raid.reward_drops.back()
	s.elapsed+=2
	p.p=returned.p
	# Force the returned packet to be the only one in range.
	for packet in s.raid.reward_drops:
		if packet.id!=returned.id: packet.p=Vector2(2000,580)
	s.perform(1,"rogue_loot")
	check(p.rogue_selection.offers==preserved,"Returning and repicking cannot freely reroll")
	var take: Dictionary=selection_payload(p)
	var expected: Dictionary=p.rogue_selection.offers[0].duplicate(true)
	s.perform(1,"rogue_selection_drop",take)
	check(p.rogue_selection.is_empty() and 1 in s.raid.reward_claims,"Choosing and sharing satisfies sender reward")
	check(s.raid.phase=="rogue_reward","Room waits for other party members")
	var shared: Dictionary=s.raid.reward_drops.back()
	check(shared.offer==expected,"Shared reward retains exact rolled item or talent")
	var remaining: int=s.raid.reward_drops.size()
	s.perform(1,"rogue_selection_drop",take)
	check(s.raid.reward_drops.size()==remaining,"Repeated share cannot duplicate reward")
	ally.p=shared.p
	var before: int=ally.rogue_inventory_revision
	s.perform(2,"rogue_loot")
	check(ally.rogue_inventory_revision>before and ally.rogue_selection.is_empty(),"Teammate picks selected reward directly")
	check(s.raid.reward_drops.size()==remaining-1,"Shared item consumed exactly once")
	var packet: Dictionary=s.raid.reward_drops[0]
	ally.p=packet.p
	s.perform(2,"rogue_loot")
	check(not ally.rogue_selection.is_empty(),"Ally can claim their own independent selection")
	s.perform(2,"rogue_selection_take",selection_payload(ally))
	check(s.raid.phase=="rogue_reward","Remaining category packet still blocks the exit")
	preload("res://tests/rogue_reward_flow.gd").claim(s,p)
	check(s.raid.phase=="rogue_exit" and s.raid.reward_claims.size()==2,"Both choices unlock exits")
	var equipment=preload("res://scripts/rogue_equipment.gd")
	var gear: Dictionary=equipment.make_gear(2,4)
	s.roguelike.equip(s,p,gear)
	s.perform(1,"rogue_inventory",{"source":"equipped","index":1,"verb":"discard","version":p.rogue_inventory_revision})
	check(p.equipped.gear[0].is_empty() and s.raid.reward_drops.back().offer.item==gear,"Inventory discard creates recoverable exact equipment")
	ally.p=s.raid.reward_drops.back().p
	s.perform(2,"rogue_loot")
	check(ally.equipped.gear[0]==gear,"Ally equips discarded gear with quality and passive preserved")
	# Serialization uses the existing snapshot dictionaries, including choices.
	var copied: Dictionary=bytes_to_var(var_to_bytes(s.raid))
	check(copied.reward_chest==s.raid.reward_chest and copied.reward_drops==s.raid.reward_drops,"Chest and drops serialize exactly for network snapshots")
	for category in ["gear","weapon","boon"]:
		for i in 10:
			var offers: Array=s.roguelike.reward_offers(s,3,category)
			var identities := {}
			for offer in offers:
				check(offer.has("boon") if category=="boon" else offer.item.kind==category,"All three choices retain their category")
				identities[offer.boon.stat if category=="boon" else offer.item.weapon if category=="weapon" else offer.item.rogue_id]=true
			check(identities.size()==3,"No duplicate choices in a category")
	s.queue_free()
	await process_frame
	print("ROGUE CHEST: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
