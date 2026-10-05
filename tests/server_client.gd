extends SceneTree

var session: TideSession
var role := "member"
var age := 0.0
var started_at := -1.0
var initial_leader := 0
var launched := false
var saw_snapshot := false
var got_skill := false
var got_art := false
var sent_art := false
var saw_attributes := false
var saw_mana := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var room = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	role=args[1]
	var game := Node.new()
	game.name="CrimsonTide"
	root.add_child(game)
	session=TideSession.new()
	session.name="Session"
	game.add_child(session)
	session.started.connect(func(): started_at=age)
	session.combat_event.connect(func(event: Dictionary):
		if event.kind=="skill": got_skill=true
		if event.kind=="strike" and event.has("art"): got_art=true)
	session.message.connect(func(message: String):
		if role=="invalid":
			print("SERVER INVALID TICKET: PASS ",message)
			quit()
		else:
			push_error("SERVER MESSAGE: "+message)
			quit(1))
	if session.join_server(room,{"name":role,"hero":1,"attributes":{"mind":20,"intelligence":20,"arcane":25}})!=OK: quit(1)

func _process(dt: float) -> bool:
	if session==null: return false
	age+=dt
	if age>25:
		push_error("SERVER CLIENT TIMEOUT "+role+" roster="+str(session.players)+" leader="+str(session.leader_id)+" started="+str(started_at))
		quit(1)
	if not session.running and started_at<0 and session.players.has(session.my_id()):
		initial_leader=session.leader_id
		if not session.is_leader() and not session.players[session.my_id()].ready:
			session.configure({"name":role,"hero":1,"ready":true,"attributes":{"mind":20,"intelligence":20,"arcane":25}})
		if role=="owner" and session.players.size()==4 and not launched:
			var ready := true
			for player in session.players.values(): ready=ready and player.ready
			if ready:
				launched=true
				session.request_launch()
	if started_at>=0:
		var elapsed := age-started_at
		var me: Dictionary=session.players.get(session.my_id(),{})
		if not me.is_empty():
			saw_attributes=int(me.attributes.intelligence)==20 and me.max_mana==120
			saw_mana=saw_mana or (sent_art and me.mana<me.max_mana and me.art_cd>0)
		if elapsed>0.2 and not sent_art:
			session.action("weapon_art")
			sent_art=true
		if session.elapsed>0.2 and session.players.size()==4 and not session.players.has(1): saw_snapshot=true
		if elapsed>0.5 and elapsed<0.7: session.action("skill")
		if role=="owner" and elapsed>2:
			print("SERVER OWNER: ","PASS" if saw_snapshot and got_skill and got_art and saw_attributes and saw_mana else "FAIL")
			session.disconnect_room()
			quit(0 if saw_snapshot and got_skill and got_art and saw_attributes and saw_mana else 1)
		elif role=="member" and elapsed>4:
			var passed := saw_snapshot and got_skill and got_art and saw_attributes and saw_mana and session.leader_id!=initial_leader and session.leader_id!=0
			print("SERVER MEMBER + LEADER TRANSFER: ","PASS" if passed else "FAIL")
			session.disconnect_room()
			quit(0 if passed else 1)
	return false
