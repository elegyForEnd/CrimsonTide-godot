extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_msec()
	var s := TideSession.new()
	root.add_child(s)
	s.solo({"hero": 0})
	s.mapgen_enabled = true
	check(s.launch(false, 20261019), "generated expedition launches")
	s.set_physics_process(false)
	var player: Dictionary = s.players.get(s.my_id(), {})
	check(s.ruins.generated, "session uses MapWorld")
	check(player.get("p", Vector2.ZERO) == s.ruins.spawn, "player starts at generated spawn")
	check(s.ruins.exits.size() == 5, "session sees five exits")
	check(s.raid.get("sealed_exits", []).size() == 2, "raid mirrors two sealed exits")
	check(str(s.raid.get("layout_hash", "")).length() == 64, "raid carries layout hash")
	check(int(s.raid.get("map_seed", 0)) == 20261019, "raid carries map seed")
	check(not s.ruins.blocked(s.ruins.spawn, 15.0), "generated spawn is walkable")
	check(s.safe_center() == s.raid.center, "safe centre follows raid")
	check(s.safe_radius() > 0.0, "safe radius is positive")
	check(s.portal_position() == s.ruins.city_gate, "city gate follows generated map")

	s.raid.day = 2
	var sealed: Array = s.raid.get("sealed_exits", [])
	var open_index := -1
	for i in s.ruins.exits.size():
		if i in sealed:
			check(not s.can_extract_at(i), "sealed exit cannot extract")
		else:
			open_index = i
			check(s.can_extract_at(i), "open exit can extract")
	check(open_index >= 0, "at least one open exit")
	check(s.ruins.exit_open(int(sealed[0])) == false, "world exit_open agrees with sealed list")

	# A client can rebuild the same map from the raid metadata.
	var client := TideSession.new()
	root.add_child(client)
	client.mapgen_enabled = true
	client.begin(20261019, 480.0, {}, "expedition", true)
	client.set_physics_process(false)
	check(client.ruins.generated, "client rebuilds generated map")
	check(client.ruins.layout_hash == s.ruins.layout_hash, "client layout hash matches host")
	check(client.ruins.exit_names.size() == 5, "client sees five exit names")

	s.queue_free()
	client.queue_free()
	print("MAPGEN INTEGRATION: ", checks, " failures: ", failures, " ms=", Time.get_ticks_msec() - started)
	quit(1 if failures else 0)
