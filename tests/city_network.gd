extends SceneTree
var session: TideSession
var server := false
var age := 0.0
var run_age := 0.0
var stage := 0
var seen_city := false
var seen_border := false
var seen_reward := false
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	session=TideSession.new()
	session.name="Session"
	root.add_child(session)
	server="--server" in OS.get_cmdline_user_args()
	var error := session.host({"hero":0}) if server else session.join("127.0.0.1",{"hero":1})
	assert(error==OK)
func _process(dt: float) -> bool:
	age+=dt
	if age>25: push_error("CITY NETWORK TIMEOUT"); quit(1); return false
	if session==null: return false
	if not session.running:
		if server and session.players.size()==2:
			for p in session.players.values(): p.ready=true
			session.launch(false,9127)
		return false
	run_age+=dt
	if server:
		if stage==0 and run_age>1:
			gather()
			assert(session.travel_city())
			stage=1
		elif stage==1 and run_age>4:
			for e in session.enemies: e.hp=0
			stage=2
		elif stage==2 and run_age>6:
			gather()
			assert(session.travel_city())
			stage=3
		elif stage==3 and run_age>8:
			gather()
			assert(session.travel_city())
			stage=4
		elif stage==4 and run_age>11:
			print("CITY NETWORK HOST PASS")
			quit()
	else:
		if session.map_id=="city":
			assert(session.ruins is RoyalCity)
			seen_city=true
			if session.ruins.chests.size()==1: seen_reward=true
			if seen_border and seen_reward:
				var alive_knight := false
				for e in session.enemies:
					if e.type==4: alive_knight=true
				assert(not alive_knight)
				print("CITY NETWORK CLIENT PASS: geometry, party travel, reward and persistence")
				quit()
		elif seen_city:
			seen_border=true
	return false
func gather() -> void:
	for p in session.players.values():
		p.p=session.portal_position()
		p.invuln=999
