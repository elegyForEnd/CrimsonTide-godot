extends SceneTree

var checks := 0
var failures := 0
var floated: Array = []

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func on_float(kind: String, anchor: String, amount: float, heavy: bool) -> void:
	floated.append({"kind": kind, "anchor": anchor, "amount": amount, "heavy": heavy})

func run() -> void:
	var profile := Profile.new()
	profile.path = "user://test-hunt-combat-text.json"
	var run = preload("res://scripts/hunt/hunt_run.gd").new()
	run.setup(0, 0, int(profile.data.get("gear", -1)), profile.data.get("talents", [0, 0, 0]))
	run.floated.connect(on_float)
	run.debug_spawn_enemy("scavenger")
	var uid := str(run.active_enemies()[0].uid)
	check(run.start_combat(uid), "combat starts")
	run.combat.hp = 999.0
	run.attack_cd = 0.0
	run.attack()
	check(floated.size() >= 1, "player attack emits a floating number")
	check(str(floated[0]["kind"]) == "damage" and str(floated[0]["anchor"]) == "enemy", "attack floats on the enemy card")
	check(not bool(floated[0]["heavy"]), "ordinary attack is not heavy")

	floated.clear()
	run.heavy_cd = 0.0
	run.stamina = 100.0
	run.attack_cd = 0.0
	run.heavy_attack()
	check(floated.size() >= 1, "heavy attack emits a floating number")
	check(bool(floated[0]["heavy"]), "heavy attack is marked heavy")

	floated.clear()
	run.hp = run.total_max_hp() - 20.0
	run.add_item("bandage", 1)
	var index := -1
	for i in run.bag.size():
		if str(run.bag[i].kind) == "bandage":
			index = i
			break
	check(index >= 0, "bandage exists")
	run.use_item(index)
	var healed := floated.filter(func(f): return str(f["kind"]) == "heal")
	check(healed.size() == 1, "bandage emits one heal number")
	check(str(healed[0]["anchor"]) == "player", "heal floats on the player portrait")

	print("HUNT COMBAT TEXT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
