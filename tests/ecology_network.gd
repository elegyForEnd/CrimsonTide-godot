extends SceneTree
var s: TideSession
var server := false
var age := 0.0
var launched := false
var saw_species := false
var saw_attack := false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	server="--server" in OS.get_cmdline_user_args()
	s=TideSession.new()
	s.name="Session"
	root.add_child(s)
	var err: Error=s.host({"hero":0}) if server else s.join("127.0.0.1",{"hero":1,"ready":true})
	if err!=OK: quit(1)
func _process(dt: float) -> bool:
	age+=dt
	if age>14:
		push_error("Ecology network timeout")
		quit(1)
	if not s: return false
	if server:
		if not launched and s.players.size()==2:
			for p in s.players.values(): p.ready=true
			s.launch(false,1729)
			s.spawn_timer=100
			s.enemies.clear()
			for kind in range(5,17): s.spawn_enemy(Vector2.ZERO,kind)
			var e: Dictionary=s.enemies.back()
			for p in s.players.values():
				p.p=e.p+Vector2(100,0)
				p.invuln=100
			launched=true
		if launched and age>8:
			print("ECOLOGY NETWORK HOST PASS")
			quit()
	elif s.running:
		var kinds := {}
		for e in s.enemies:
			kinds[e.type]=true
			if e.type==16 and e.get("attack_time",0)>0 and e.has("attack_point") and e.has("habitat"):
				saw_attack=true
		saw_species=kinds.size()==12
		if saw_species and saw_attack:
			print("ECOLOGY NETWORK CLIENT PASS: twelve species, habitat and locked attack point")
			quit()
	return false
