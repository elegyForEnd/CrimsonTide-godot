extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var text: Node2D = preload("res://scripts/combat_text.gd").new()
	root.add_child(text)
	text.reset()

	text.push("damage", Vector2(100, 100), 37.4)
	check(text.entries.size() == 1, "one damage entry")
	var entry: Dictionary = text.entries.back()
	check(str(entry["value"]) == "37", "damage rounds to integer")
	check(int(entry["size"]) == 20, "ordinary damage is 20px")
	check(not bool(entry["flash"]), "ordinary damage does not flash")
	check(entry["color"] == Color("f2e3c6"), "ordinary damage keeps the ivory colour")

	text.push("damage", Vector2(100, 100), 246.0, {"heavy": true})
	entry = text.entries.back()
	check(str(entry["value"]) == "246", "heavy damage value")
	check(int(entry["size"]) == 30, "heavy damage is 30px")
	check(bool(entry["flash"]), "heavy damage flashes")
	check(entry["color"] == Color("ffc65c"), "heavy damage is gold")

	text.push("hurt", Vector2.ZERO, 12.5)
	entry = text.entries.back()
	check(str(entry["value"]) == "-13", "hurt carries a minus and rounds")
	check(entry["color"] == Color("ff4d5f"), "hurt is red")
	check(not bool(entry["flash"]), "hurt does not flash")

	text.push("heal", Vector2.ZERO, 45.2)
	entry = text.entries.back()
	check(str(entry["value"]) == "+45", "heal carries a plus")
	check(entry["color"] == Color("86e8b0"), "heal is mint")
	check(bool(entry["flash"]), "heal flashes")

	text.push("dot", Vector2.ZERO, 6.0)
	entry = text.entries.back()
	check(str(entry["value"]) == "6", "dot has no sign")
	check(entry["color"] == Color("ff9a4d"), "dot is ember")
	check(is_equal_approx(float(entry["life"]), 0.55), "dot life is shorter")

	var before: int = text.entries.size()
	text.push("damage", Vector2.ZERO, 0.0)
	check(text.entries.size() == before, "zero damage is ignored")
	text.push("heal", Vector2.ZERO, -3.0)
	check(text.entries.size() == before, "negative heal is ignored")

	text.reset()
	text.on_event({"kind": "impact", "p": Vector2(10, 20), "damage": 21.0, "heavy": false})
	check(text.entries.size() == 1 and str(text.entries.back()["value"]) == "21", "impact event -> damage")
	text.reset()
	text.on_event({"kind": "hit", "p": Vector2(10, 20), "damage": 22.0})
	check(text.entries.size() == 1 and str(text.entries.back()["value"]) == "22", "story hit event -> damage")
	text.reset()
	text.on_event({"kind": "hurt", "p": Vector2(10, 20), "damage": 9.0})
	check(text.entries.size() == 1 and str(text.entries.back()["value"]) == "-9", "hurt event -> hurt")
	text.reset()
	text.on_event({"kind": "heal", "p": Vector2(10, 20), "amount": 14.0})
	check(text.entries.size() == 1 and str(text.entries.back()["value"]) == "+14", "heal event -> heal")
	text.reset()
	text.on_event({"kind": "burn", "p": Vector2(10, 20), "damage": 6.0})
	check(text.entries.size() == 1 and str(text.entries.back()["kind"]) == "dot", "burn event -> dot")
	text.reset()
	text.on_event({"kind": "heal", "p": Vector2.ZERO})
	check(text.entries.is_empty(), "heal event without amount is ignored")

	text.push("damage", Vector2.ZERO, 5.0)
	text.advance(0.5)
	check(text.entries.size() == 1, "entry survives mid-life")
	text.advance(0.3)
	check(text.entries.is_empty(), "entry expires after life")

	text.reset()
	text.push("damage", Vector2(10, 10), 7.0)
	text.push("damage", Vector2(10, 10), 8.0)
	check(text.entries.size() == 2, "two simultaneous hits are kept")
	check(absf(float(text.entries[0]["drift"])) < 3.0, "first simultaneous hit stays centred")
	check(float(text.entries[1]["drift"]) > 40.0, "second simultaneous hit is fanned out")
	check(float(text.entries[1]["lift"]) > 0.0, "second simultaneous hit is staggered vertically")

	var graphics: Node = root.get_node_or_null("GraphicsQuality")
	if graphics != null:
		var old_ghost: bool = graphics.damage_ghost
		var old_flash: bool = graphics.damage_flash
		graphics.damage_ghost = false
		graphics.damage_flash = false
		check(text._option("damage_ghost", true) == false, "graphics toggle reaches ghost option")
		check(text._option("damage_flash", true) == false, "graphics toggle reaches flash option")
		graphics.damage_ghost = old_ghost
		graphics.damage_flash = old_flash
	else:
		check(text._option("damage_ghost", true), "missing graphics node falls back to on")

	text.queue_free()
	print("COMBAT_TEXT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
