extends SceneTree

# The item bar's two mouse verbs, without a mouse: `double_click_slot()` (spend a
# supply / trade a worn piece / put a thing with no verb away) and `take_item_slot()`
# (the tidy verb behind Ctrl+left and the panel's "收回"). Real clicks are covered by
# `tests/item_bar.gd`; this file pins the priority rule so it cannot drift.

var app: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ITEM BAR GESTURE FAIL: " + text)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://test-item-bar-gestures.json"
	app.profile.data.pocket = Catalog.clean_container({"key": "white", "items": []}, Catalog.POCKET_GRID)
	app.profile.data.bag_key = "white"
	app.profile.data.bags = [Catalog.clean_container({"key": "white", "items": []}, Catalog.tier("white").grid)]
	app.profile.data.hero = 0
	await create_timer(0.3).timeout
	app.session.solo({"hero": 0})
	app.session.launch(false, 5150)
	app.session.enemies.clear()
	app.session.spawn_timer = 99999
	app.page_name = "game"
	await create_timer(0.2).timeout
	var p: Dictionary = app.session.players[1]
	p.backpack.items.clear()
	for i in app.session.ITEM_SLOT_COUNT:
		app.session.set_item_slot(p, i, {})

	check(not app.double_click_slot(0), "a double tap on an empty socket does nothing")

	# 1) A supply is spent straight from the bar, never parked back in the bag.
	p.hp = 40.0
	Catalog.place_item(p.backpack, {"kind": "medicine", "count": 1})
	app.session.action("slot_put", {"slot": 0, "from": "backpack", "index": 0})
	await process_frame
	check(str(app.session.item_slot(p, 0).get("kind", "")) == "medicine", "the medkit is parked in a socket")
	var bag_after_park: int = p.backpack.items.size()
	check(app.double_click_slot(0), "double tapping a medkit is accepted")
	check(p.hp > 40.0, "double tapping a medkit heals on the spot")
	check(app.session.item_slot(p, 0).is_empty(), "the spent medkit leaves the bar")
	check(p.backpack.items.size() == bag_after_park, "using from the bar adds nothing to the bag")

	# 2) A weapon trades places with what is worn; nothing detours through the bag.
	# Wear a looted blade first, otherwise the hero's issue weapon has no item form
	# and there would be nothing to trade back into the socket.
	p.backpack.items.clear()
	Catalog.place_item(p.backpack, Catalog.make_equipment("weapon", 12, 4))
	app.session.action("equip", {"slot": "backpack", "index": 0})
	await process_frame
	var worn_before := int(app.session.kit_weapon(p).get("weapon", -1))
	check(worn_before == 12, "a looted blade can be worn for the swap test")
	p.backpack.items.clear()
	Catalog.place_item(p.backpack, Catalog.make_equipment("weapon", 13, 4))
	app.session.action("slot_put", {"slot": 1, "from": "backpack", "index": 0})
	await process_frame
	check(str(app.session.item_slot(p, 1).get("kind", "")) == "weapon", "the looted weapon waits in a socket")
	var bag_before_swap: int = p.backpack.items.size()
	check(app.double_click_slot(1), "double tapping a weapon is accepted")
	check(int(app.session.kit_weapon(p).get("weapon", -1)) != worn_before, "the looted weapon is now worn")
	check(str(app.session.item_slot(p, 1).get("kind", "")) == "weapon", "the piece that was worn comes back into the bar")
	check(int(app.session.item_slot(p, 1).get("weapon", -1)) == worn_before, "the traded piece is the one that was worn")
	check(p.backpack.items.size() == bag_before_swap, "the weapon swap never goes through the bag")

	# 3) Anything with no verb is put away with the tidy rule: bag first.
	p.backpack.items.clear()
	Catalog.place_item(p.backpack, {"kind": "stone", "count": 1})
	app.session.action("slot_put", {"slot": 2, "from": "backpack", "index": 0})
	await process_frame
	check(str(app.session.item_slot(p, 2).get("kind", "")) == "stone", "a plain treasure can still sit in a socket")
	check(app.double_click_slot(2), "double tapping a verbless item is accepted")
	check(app.session.item_slot(p, 2).is_empty(), "the verbless item leaves the bar")
	var stone_back := false
	for entry in p.backpack.items:
		if str(entry.kind) == "stone":
			stone_back = true
	check(stone_back, "the verbless item is tidied back into the backpack")

	# 4) Ctrl+left / "收回" is the same tidy verb, and it is not "use".
	p.hp = 30.0
	p.backpack.items.clear()
	Catalog.place_item(p.backpack, {"kind": "medicine", "count": 1})
	app.session.action("slot_put", {"slot": 0, "from": "backpack", "index": 0})
	await process_frame
	var hp_before_tidy: float = p.hp
	app.take_item_slot(0)
	await process_frame
	check(app.session.item_slot(p, 0).is_empty(), "the tidy verb empties the socket")
	check(p.hp == hp_before_tidy, "the tidy verb does not consume the item")
	check(p.backpack.items.size() == 1, "the tidy verb returns the item to the bag")

	print("ITEM BAR GESTURES: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
