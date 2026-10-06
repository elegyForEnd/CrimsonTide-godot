extends SceneTree
## The right-button stack hand, headless.
##
## The gesture is: **hold** the right button to lift a whole pile into the hand, click the
## left button to set **one** unit down on the cell under the cursor, and let the right
## button up to hand whatever is left over to the aimed container, then back where it came
## from, then the floor. The left button keeps its older meaning (a drag moves the whole
## pile as one piece), so the two gestures deliberately do not share a button.
##
## Covered here: the per-kind ceilings, the aimed-cell landing rule that backs the "locked"
## cell, the split that keeps a lowered ceiling from destroying a save, the two paths that
## used to swallow units, and the gesture end to end inside the camp panel.
var checks := 0
var failures := 0

const CampStorage := preload("res://scripts/camp_storage.gd")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

## Units in a container, counting a pile's own count rather than one per entry.
func units_in(container: Dictionary) -> int:
	var total := 0
	for item in Catalog.container_items(container):
		total += int(item.get("count",1)) if Catalog.stacks(str(item.get("kind",""))) else 1
	return total

func pile_of(container: Dictionary, kind: String) -> int:
	for item in Catalog.container_items(container):
		if str(item.get("kind",""))==kind:
			return int(item.get("count",1))
	return 0

## Every unit of one kind in a container, across however many piles it takes. The carried
## containers start with the Watcher's own kit, so totals have to be per kind.
func units_of_kind(container: Dictionary, kind: String) -> int:
	var total := 0
	for item in Catalog.container_items(container):
		if str(item.get("kind",""))==kind:
			total += int(item.get("count",1)) if Catalog.stacks(kind) else 1
	return total

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# --- ceilings -------------------------------------------------------------
	check(Catalog.max_stack("medicine")==3,"field medicine is a three-unit pile")
	check(Catalog.max_stack("ammo")==3,"ammo boxes are a three-unit pile")
	for kind in ["crystal","scrap","charm","bait","wheat","carrot","herb","silver","moon","gold","wheat_seed","carrot_seed","herb_seed"]:
		check(Catalog.max_stack(kind)==5,"%s is a five-unit pile" % kind)
	check(Catalog.max_stack("weapon")==1 and not Catalog.stacks("weapon"),"a weapon is a pile of one and shows no badge")
	check(Catalog.stacks("medicine") and Catalog.stacks("wheat"),"and the stacking kinds still stack")

	# --- the aimed cell, answered strictly ------------------------------------
	var box := Catalog.make_container([],Vector2i(4,4))
	var blank := {"kind":"crystal","rot":false}
	check(Catalog.add_unit_at(box,"crystal",Vector2i(0,0),blank)==Vector2i(0,0),"an empty aimed cell starts a pile there")
	check(Catalog.add_unit_at(box,"crystal",Vector2i(0,0),blank)==Vector2i(0,0),"and the next unit aimed at it grows that same pile")
	check(pile_of(box,"crystal")==2,"so the pile reads two")
	check(Catalog.add_unit_at(box,"crystal",Vector2i(3,3),blank)==Vector2i(3,3),"aiming at another empty cell starts a second pile")
	check(Catalog.container_items(box).size()==2,"the container really holds two piles")
	check(Catalog.add_unit_at(box,"scrap",Vector2i(0,0),{"kind":"scrap"})==Vector2i(-1,-1),"aiming a different kind at a taken cell is refused")
	check(Catalog.container_items(box).size()==2,"and a refusal adds nothing")

	# A pile at its ceiling refuses the unit on that cell, which is what sends the hand to
	# the nearest hole instead of overfilling. Medicine is a 1x2 piece, so the smallest
	# container that holds one pile is one cell wide and two tall.
	var full := Catalog.make_container([],Vector2i(1,2))
	for i in 3:
		Catalog.add_unit_at(full,"medicine",Vector2i(0,0),{"kind":"medicine"})
	check(pile_of(full,"medicine")==3,"three units fill the medicine ceiling")
	check(Catalog.add_unit_at(full,"medicine",Vector2i(0,0),{"kind":"medicine"})==Vector2i(-1,-1),"a fourth unit is refused on that cell")
	check(units_in(full)==3,"and the refusal cost nothing")

	# --- the landing rule: aim first, then the nearest hole -------------------
	var ring := Catalog.make_container([],Vector2i(2,2))
	Catalog.add_unit_at(ring,"medicine",Vector2i(0,0),{"kind":"medicine"})
	var aimed := Catalog.place_units_in(ring,"medicine",1,Vector2i(0,0),{"kind":"medicine"})
	check(int(aimed.placed)==1 and Vector2i(aimed.cell)==Vector2i(0,0),"a single unit lands on the aimed pile")
	check(pile_of(ring,"medicine")==2,"growing it to two")
	# Every cell is taken by something that is not this kind, so the aimed unit goes to the
	# nearest same-kind pile with room instead of the cell it was refused by.
	var others := Catalog.make_container([],Vector2i(3,3))
	others["items"]=[{"kind":"medicine","x":0,"y":0,"rot":false,"count":1},{"kind":"ammo","x":1,"y":1,"rot":false,"count":1}]
	var moved := Catalog.place_units_in(others,"medicine",1,Vector2i(1,1),{"kind":"medicine"})
	check(int(moved.placed)==1,"a unit aimed at the wrong kind still lands somewhere")
	check(Vector2i(moved.cell)!=Vector2i(1,1),"but not on the cell it was refused by")
	check(pile_of(others,"medicine")==2,"and it merged into the medicine pile rather than a new one")
	# Nothing fits at all: no unit may be consumed. Crystal is 1x1, so four of them fill a
	# two-by-two, and a 2x1 scrap then has no pair of adjacent free cells left.
	var walled := Catalog.make_container([],Vector2i(2,2))
	for i in 4:
		Catalog.add_unit_at(walled,"crystal",Vector2i(i%2,i/2),{"kind":"crystal"})
	check(units_in(walled)==4,"a two-by-two grid holds four one-unit crystal piles")
	var refused := Catalog.place_units_in(walled,"scrap",1,Vector2i(0,0),{"kind":"scrap"})
	check(int(refused.placed)==0,"a two-by-one scrap has nowhere to go in it")
	check(units_in(walled)==4,"and nothing was consumed by the attempt")

	# --- lowering a ceiling must never destroy a save -------------------------
	var legacy := Catalog.make_container([],Vector2i(3,3))
	legacy["items"]=[{"kind":"crystal","x":0,"y":0,"rot":false,"count":6}]
	var spill: Array=[]
	Catalog.split_over_limit(legacy,spill)
	var spilled := 0
	for entry in spill:
		spilled += int(entry.get("count",1))
	check(units_in(legacy)+spilled==6,"a six-unit crystal pile survives a ceiling of five")
	check(pile_of(legacy,"crystal")<=5,"no pile is left above its ceiling")
	check(spill.is_empty(),"and a grid with room parks nothing")
	# Now a container with no room at all for the surplus: one medicine pile exactly fills it.
	var snug := Catalog.make_container([],Vector2i(1,2))
	snug["items"]=[{"kind":"medicine","x":0,"y":0,"rot":false,"count":5}]
	var snug_spill: Array=[]
	Catalog.split_over_limit(snug,snug_spill)
	check(units_in(snug)==3,"the pile is trimmed to the medicine ceiling")
	check(snug_spill.size()==1 and int(snug_spill[0].get("count",0))==2,"and the two units that did not fit are handed back, not dropped")
	check(units_in(snug)+int(snug_spill[0].get("count",0))==5,"so the count is conserved either way")

	# --- the two paths that used to swallow units -----------------------------
	var account := Profile.new()
	account.sanitize_storage()
	var paid := account.warehouse_deposit({"kind":"crystal","count":6})
	check(paid==0,"depositing an over-limit pile reports nothing unparked")
	var held := 0
	for item in account.warehouse_items():
		if str(item.get("kind",""))=="crystal":
			held += int(item.get("count",1))
	check(held==6,"and all six crystal units really reached the vault, not five")
	var before := held
	check(not CampStorage.vault_units_in(account,null,{},CampStorage.VAULT,0,2,false),"banking a vault pile back into the vault is refused")
	var after := 0
	for item in account.warehouse_items():
		if str(item.get("kind",""))=="crystal":
			after += int(item.get("count",1))
	check(after==before,"so the pile is untouched instead of merged into itself and overwritten")

	# --- the gesture, end to end, in the camp panel ---------------------------
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path="user://test-stack-hand.json"
	app.profile.data=Profile.new().data.duplicate(true)
	app.profile.sanitize_storage()
	app.session.solo(app.config())
	app.session.launch(false,1729)
	app.session.set_physics_process(false)
	app.session.running=false
	app.go_camp()
	await process_frame
	app.show_camp_pack(false)
	await process_frame
	check(app.camp_pack_open and app.grids.has("warehouse"),"the camp panel is up with its vault grid")

	var vault: Dictionary=app.profile.vault()
	vault["items"].clear()
	for i in 5:
		Catalog.place_loot(vault,"wheat")
	check(pile_of(vault,"wheat")==5,"a five-unit wheat pile is banked")
	var pile: Dictionary=Catalog.container_items(vault)[0]
	var vault_pt := Vector2(app.grids["warehouse"].origin)+Vector2(int(pile.x),int(pile.y))*float(int(app.grids["warehouse"].cell)+int(app.grids["warehouse"].gap))+Vector2(9,9)
	var bag: Dictionary=app.grids["backpack"]
	var step := float(int(bag.cell)+int(bag.gap))
	var bag_pt := Vector2(bag.origin)+Vector2(0,bag.grid.y-1)*step+Vector2(9,9)

	# The right button goes down: the whole pile is in the hand and the vault is untouched.
	app.start_whole_carry(vault_pt)
	check(app.drag.active and int(app.drag.carry)==5,"holding the right button lifts all five")
	check(pile_of(vault,"wheat")==5,"and nothing has left the vault yet")
	check(int(app.held_item().get("count",1))==5,"the hand shows the whole pile")

	# Three left clicks: one unit each, on the cell under the cursor.
	app.carry_place_one(bag_pt)
	check(pile_of(vault,"wheat")==4 and int(app.drag.carry)==4,"the first click takes exactly one unit out")
	app.carry_place_one(bag_pt)
	app.carry_place_one(bag_pt)
	var carried: Dictionary=app.session.players[app.session.my_id()].backpack
	check(pile_of(carried,"wheat")==3,"three clicks stack exactly three units in the bag")
	check(pile_of(vault,"wheat")==2 and int(app.drag.carry)==2,"and the vault is down to the two that are still there")
	check(units_of_kind(carried,"wheat")+pile_of(vault,"wheat")==5,"nothing was created or lost by the clicks")
	var bag_cell := Vector2i(-1,-1)
	for item in Catalog.container_items(carried):
		if str(item.get("kind",""))=="wheat":
			bag_cell=Vector2i(int(item.x),int(item.y))
	check(bag_cell==Vector2i(0,bag.grid.y-1),"the pile sits on the cell the cursor was on, not somewhere the packer preferred")

	# Letting the right button up over the vault hands the remaining two back to it, which
	# is the honest result of releasing where they already are.
	app.carry_finish(vault_pt)
	check(not app.drag.active and int(app.drag.get("carry",0))==0,"releasing the right button ends the gesture")
	check(pile_of(carried,"wheat")==3 and pile_of(vault,"wheat")==2,"and releasing over the source leaves three in the bag, two in the vault")
	check(units_of_kind(carried,"wheat")+pile_of(vault,"wheat")==5,"still five units in total")

	# Releasing over the bag instead is how the whole pile gets moved.
	app.start_whole_carry(vault_pt)
	check(int(app.drag.carry)==2,"the vault pile can be lifted again")
	app.carry_finish(bag_pt)
	check(pile_of(carried,"wheat")==5,"releasing over the bag lands the rest of the pile there")
	check(pile_of(vault,"wheat")==0,"and empties the vault pile")
	check(units_of_kind(carried,"wheat")==5,"with the same five units")

	# A refused click is free: aim a new kind at a full pile of a different kind and check
	# that neither side changed.
	vault["items"].clear()
	for i in 5:
		Catalog.place_loot(vault,"wheat")
	app.show_camp_pack(false)
	await process_frame
	var wheat: Dictionary=Catalog.container_items(vault)[0]
	var wheat_pt := Vector2(app.grids["warehouse"].origin)+Vector2(int(wheat.x),int(wheat.y))*float(int(app.grids["warehouse"].cell)+int(app.grids["warehouse"].gap))+Vector2(9,9)
	app.start_whole_carry(wheat_pt)
	var wheat_before := pile_of(vault,"wheat")
	check(app.carry_would_place("warehouse",Vector2i(int(wheat.x),int(wheat.y))),"the aimed cell answers the dry run")
	app.carry_finish(wheat_pt)
	check(pile_of(vault,"wheat")==wheat_before,"a handed-back pile leaves the vault exactly as it was")

	app.close_bag()
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-stack-hand.json"))
	print("STACK HAND: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
