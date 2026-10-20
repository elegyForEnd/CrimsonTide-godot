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
	var session := TideSession.new()
	root.add_child(session)
	session.solo({"hero": 0})
	session.launch(false, 1729)
	session.set_physics_process(false)
	var field := Battlefield.new()
	field.session = session
	root.add_child(field)
	await process_frame
	await process_frame

	var text: Node2D = field.combat_text
	check(text != null, "battlefield owns a combat text layer")
	text.reset()

	# The authoritative impact event must reach the floating layer.
	session.broadcast_combat({"kind": "impact", "p": Vector2(500, 500), "damage": 12.4, "heavy": false, "id": 1})
	check(text.entries.size() == 1, "impact event reaches battlefield text")
	check(str(text.entries.back()["value"]) == "12", "impact rounds")
	text.reset()

	session.broadcast_combat({"kind": "impact", "p": Vector2(500, 500), "damage": 88.0, "heavy": true, "id": 1})
	check(text.entries.size() == 1, "heavy impact reaches battlefield text")
	check(int(text.entries.back()["size"]) == 30, "heavy impact uses 30px")
	text.reset()

	# Player hurt goes through hurt() so the number and the existing red vignette
	# share one authoritative amount.
	var player: Dictionary = session.players[1]
	player.invuln = 0.0
	player.hp = player.max_hp
	session.hurt(player, 13.0)
	check(text.entries.size() == 1, "player hurt reaches battlefield text")
	check(str(text.entries.back()["value"]) == "-13", "player hurt is signed and red")
	check(text.entries.back()["color"] == Color("ff4d5f"), "player hurt uses the hurt colour")
	text.reset()

	# A medkit reports the HP actually restored, not the raw 45.
	player.invuln = 0.0
	player.hp = player.max_hp - 10.0
	session.apply_medkit(player)
	check(text.entries.size() == 1, "medkit reaches battlefield text")
	check(str(text.entries.back()["value"]) == "+10", "medkit reports the healed amount")
	text.reset()

	# Burn is a DoT event and keeps its own shorter, ember entry.
	var enemy := {"id": 77, "p": player.p + Vector2(80, 0), "hp": 100.0, "max_hp": 100.0, "type": 0}
	session.enemies.append(enemy)
	session.burn_enemy(enemy, 1, 6.0)
	check(text.entries.size() == 1, "burn reaches battlefield text")
	check(str(text.entries.back()["kind"]) == "dot", "burn is tagged as dot")
	check(text.entries.back()["color"] == Color("ff9a4d"), "burn is ember")
	text.reset()

	# Reset is wired to the session lifecycle, so a new run cannot inherit old text.
	session.broadcast_combat({"kind": "impact", "p": Vector2.ZERO, "damage": 5.0, "id": 1})
	check(text.entries.size() == 1, "entry exists before reset")
	text.reset()
	check(text.entries.is_empty(), "reset clears entries")

	print("COMBAT_TEXT INTEGRATION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
